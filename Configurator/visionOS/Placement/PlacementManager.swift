// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import Foundation
import ARKit
import RealityKit
import QuartzCore
import SwiftUI
import CloudXRKit

/// The main class interface for placing a model on a surface
@Observable
final class PlacementManager {
    public enum State {
        case none
        case started
        case starting
        case placing
    }

    // Placement data
    private enum Attachments {
        case placementHelp
        case dragHelp
    }

    private var planeDetection: PlaneDetectionProvider!

    private var planeAnchorHandler: PlaneAnchorHandler
    var placeable: Placeable?
    private var movingObject: PlacedEntity?

    var placementModel: PlacementModel

    private var currentDrag: DragState? {
        didSet {
            placementState.dragInProgress = currentDrag != nil
        }
    }

    var placementState = PlacementState()

    var rootEntity: Entity
    var placingEntity: PlacedEntity?

    private let deviceLocationEntity: Entity
    private let raycastOriginEntity: Entity
    private let locationEntity: Entity
    private weak var helpEntity: Entity?
    weak var dragHelpEntity: Entity?

    public var position: simd_float3 { locationEntity.position }
    public var orientation: simd_quatf { locationEntity.orientation }

    // Place objects on planes with a small gap.
    static private let placedEntityOffset: Float = 0.01

    // Snap dragged objects to a nearby horizontal plane within +/- 4 centimeters.
    static private let snapToPlaneDistance: Float = 0.04

    init() {
        dprint("\(Self.self).\(#function)")
        // allows using root entity before self is finished being initialized
        let root = Entity()

        rootEntity = root
        root.name = "rootEntity"
        locationEntity = Entity()
        locationEntity.name = "locationEntity"
        deviceLocationEntity = Entity()
        deviceLocationEntity.name = "deviceLocationEntity"
        raycastOriginEntity = Entity()
        raycastOriginEntity.name = "raycastOriginEntity"

        planeAnchorHandler = PlaneAnchorHandler(rootEntity: root)
        deviceLocationEntity.addChild(raycastOriginEntity)

        // Angle raycasts 15 degrees down.
        let raycastDownwardAngle = 15.0 * (Float.pi / 180)
        raycastOriginEntity.orientation = simd_quatf(angle: -raycastDownwardAngle, axis: [1.0, 0.0, 0.0])
        placementModel = PlacementModel()
        placementModel.set(manager: self)
    }

    var deviceAnchorUpdatesTask: Task<(), Never>?
    var planeDetectionUpdatesTask: Task<(), Never>?

    @MainActor
    func start(session: Session, content: RealityViewContent, attachments: RealityViewAttachments) async -> Bool {
#if targetEnvironment(simulator)
        // Placement isn't supported in the simulator
        return false
#else
        dprint("\(Self.self).\(#function)")
        guard await placementModel.requestWorldSensingAuthorization(session: session) == .allowed else {
            return false
        }

        guard let placeable, placeable.placementState == .started else {
            return false
        }

        placeable.placementState = .starting

        placementState.userPlacedAnObject = false

        content.add(rootEntity)

        rootEntity.addChild(locationEntity)

        if let placementHelpAttachment = attachments.entity(for: Attachments.placementHelp) {
            addPlacementHelp(placementHelpAttachment)
        }

        if let dragHelpAttachment = attachments.entity(for: Attachments.dragHelp) {
            dragHelpEntity = dragHelpAttachment
        }

        let plane = makeMarker()
        let entity = Entity()
        let placeableObject = PlaceableObject("marker", renderContent: plane, previewEntity: entity)

        placeable.placementState = .placing
        dprint("\(Self.self).\(#function) now placing")
        // Run the ARKit session after the user opens the immersive space.
        // TODO: should this be moved to after placement model is set up?
        await runARKitSession(session: session)

        assert(deviceAnchorUpdatesTask == nil)
        deviceAnchorUpdatesTask = Task {
            dprint("\(Self.self).\(#function) - PlacementModifier task 1: manager = \(self)")
            await processDeviceAnchorUpdates()
        }

        assert(planeDetectionUpdatesTask == nil)
        planeDetectionUpdatesTask = Task {
            dprint("\(Self.self).\(#function) - PlacementModifier task 2: manager = \(self)")
            await processPlaneDetectionUpdates()
        }

        await Self.buildCollisions(for: entity, using: plane)
        select(placeableObject)
        return true
#endif
    }

    @MainActor
    func update(session: Session, content: RealityViewContent, attachments: RealityViewAttachments) {
#if targetEnvironment(simulator)
        // Placement isn't supported in the simulator
        return
#else
        dprint("\(Self.self).\(#function)")
        guard let placeable, placeable.isPlacing else { return }
        // start placement if it wasn't running before
        if placeable.placementState == .started {
            content.printHierarchy()

            Task {
                let started = await start(session: session, content: content, attachments: attachments)
                if !started {
                    placeable.placementState = .none
                }
            }
        }
        guard placeable.placementState == .placing else { return }
        if let placementHelp = attachments.entity(for: Attachments.placementHelp) {
            placementHelp.isEnabled = (placementState.selectedObject != nil && placementState.shouldShowPreview)
        }

        if let dragHelp = attachments.entity(for: Attachments.dragHelp) {
            // Dismiss the drag tooltip after the user demonstrates it.
            dragHelp.isEnabled = !placementState.userDraggedAnObject
        }

        if let selectedObject = placementState.selectedObject {
            dprint("\(Self.self).\(#function) \"\(selectedObject.descriptor.displayName)\" is selected")
            selectedObject.isPreviewActive = placementState.isPlacementPossible
        }
#endif
    }

    @MainActor
    func addPlacementHelp(_ help: Entity) {
        dprint("\(Self.self).\(#function)")
        helpEntity = help

        // Add a help 10 centimeters in front of the placement location to give
        // users feedback about why they can’t currently place an object.
        locationEntity.addChild(help)
        help.position = [0.0, 0.05, 0.1]
    }

    @MainActor
    func runARKitSession(session: Session) async {
        dprint("\(Self.self).\(#function)")
        // Run a new set of providers every time when entering the immersive space.
        if PlaneDetectionProvider.isSupported {
            assert(planeDetection == nil)
            planeDetection = PlaneDetectionProvider()
            CloudXRSession.addDataProvidersToArKitSession([planeDetection])
        }
    }

    @MainActor
    func makeMarker() -> ModelEntity {
        dprint("\(Self.self).\(#function)")
        let marker = ModelEntity()
        let size: Float = 0.2
        let height = size / 10.0
        let corner = height / 2.0
        marker.components[ModelComponent.self] = .init(
            mesh: .generateBox(width: size, height: height, depth: size, cornerRadius: corner),
            materials: [SimpleMaterial(color: .white, roughness: 0.2, isMetallic: false)]
        )
        marker.name = "Placement Marker"
        return marker
    }

    @MainActor
    func select(_ object: PlaceableObject?) {
        dprint("\(Self.self).\(#function)")
        if let object {
            dprint("\(Self.self).\(#function) \(object.descriptor.displayName)")
        } else {
            dprint("\(Self.self).\(#function) nil")
        }
        if let oldSelection = placementState.selectedObject, oldSelection !== object {
            // Remove the current preview entity.
            locationEntity.removeChild(oldSelection.previewEntity)
        }

        // Update state.
        placementState.selectedObject = object

        if let object {
            object.previewEntity.debugLightingDiffuse()
            // Add new preview entity.
            locationEntity.addChild(object.previewEntity)
            locationEntity.addChild(makeMarker())
        }
    }

    @MainActor
    func addMarker() -> Entity {
        dprint("\(Self.self).\(#function)")
        let plane = makeMarker()
        locationEntity.addChild(plane)
        return plane
    }

    func processDeviceAnchorUpdates() async {
        dprint("\(Self.self).\(#function)")
        await run(function: queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }

    @MainActor
    private func queryAndProcessLatestDeviceAnchor() async {
        // Device anchors are only available when the provider is running.
        guard let placeable,
              CloudXRSession.worldTrackingState == .running,
              placeable.placementState == .placing else { return }

        dprint("\(Self.self).\(#function)")
        let deviceAnchor = CloudXRSession.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())

        placementState.deviceAnchorPresent = deviceAnchor != nil
        placementState.planeAnchorsPresent = !planeAnchorHandler.planeAnchors.isEmpty
        placementState.selectedObject?.previewEntity.isEnabled = placementState.shouldShowPreview

        guard let deviceAnchor, deviceAnchor.isTracked else {
            dprint("\(Self.self).\(#function) - device anchor is not tracked??")
            return
        }

        await updateUserFacingUIOrientations(deviceAnchor)
        await updatePlacementLocation(deviceAnchor)
    }

    @MainActor
    private func updateUserFacingUIOrientations(_ deviceAnchor: DeviceAnchor) async {
        dprint("\(Self.self).\(#function)")
        // 1. Orient the front side of the highlighted object’s UI to face the user.
        if let uiOrigin = placementState.highlightedObject?.uiOrigin {
            // Set the UI to face the user (on the y-axis only).
            uiOrigin.look(at: deviceAnchor.originFromAnchorTransform.translation)
            let uiRotationOnYAxis = uiOrigin.transformMatrix(relativeTo: nil).gravityAligned.rotation
            uiOrigin.setOrientation(uiRotationOnYAxis, relativeTo: nil)
        }

        // 2. Orient each UI element to face the user.
        for entity in [helpEntity, dragHelpEntity] {
            if let entity {
                entity.look(at: deviceAnchor.originFromAnchorTransform.translation)
            }
        }
    }

    @MainActor
    private func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
        dprint("\(Self.self).\(#function) device anchor: \(deviceAnchor.originFromAnchorTransform)")
        deviceLocationEntity.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
        let originFromUprightDeviceAnchorTransform = deviceAnchor.originFromAnchorTransform.gravityAligned

        // Determine a placement location on planes in front of the device by casting a ray.

        // Cast the ray from the device origin.
        let origin: simd_float3 = raycastOriginEntity.transformMatrix(relativeTo: nil).translation

        // Cast the ray along the negative z-axis of the device anchor, but with a slight downward angle.
        // (The downward angle is configurable using the `raycastOrigin` orientation.)
        let direction: simd_float3 = -raycastOriginEntity.transformMatrix(relativeTo: nil).zAxis

        // Only consider raycast results that are within 0.2 to 3 meters from the device.
        let minDistance: Float = 0.2
        let maxDistance: Float = 3

        // Only raycast against horizontal planes.
        let collisionMask = PlaneAnchor.allPlanesCollisionGroup

        var originFromPointOnPlaneTransform: float4x4? = nil
        if let result = rootEntity.scene?.raycast(
            origin: origin,
            direction: direction,
            length: maxDistance,
            query: .nearest,
            mask: collisionMask
        ).first, result.distance > minDistance {
            if result.entity.components[CollisionComponent.self]?.filter.group != PlaneAnchor.verticalCollisionGroup {
                // If the raycast hit a horizontal plane, use that result with a small, fixed offset.
                originFromPointOnPlaneTransform = originFromUprightDeviceAnchorTransform
                originFromPointOnPlaneTransform?.translation = result.position + [0.0, PlacementManager.placedEntityOffset, 0.0]
            }
        }

        if let originFromPointOnPlaneTransform {
            locationEntity.transform = Transform(matrix: originFromPointOnPlaneTransform)
            placementState.planeToProjectOnFound = true
        } else {
            // If no placement location can be determined, position the preview 50 centimeters in front of the device.
            let distanceFromDeviceAnchor: Float = 0.5
            let downwardsOffset: Float = 0.3
            var uprightDeviceAnchorFromOffsetTransform = matrix_identity_float4x4
            uprightDeviceAnchorFromOffsetTransform.translation = [0, -downwardsOffset, -distanceFromDeviceAnchor]
            let originFromOffsetTransform = originFromUprightDeviceAnchorTransform * uprightDeviceAnchorFromOffsetTransform

            locationEntity.transform = Transform(matrix: originFromOffsetTransform)
            placementState.planeToProjectOnFound = false
        }
    }

    func processPlaneDetectionUpdates() async {
        dprint("\(Self.self).\(#function)")
        for await anchorUpdate in planeDetection.anchorUpdates {
            if let placeable, placeable.placementState == .placing {
                await planeAnchorHandler.process(anchorUpdate)
            }
        }
    }

    @MainActor
    @AttachmentContentBuilder
    func attachments() -> some AttachmentContent {
        Attachment(id: Attachments.placementHelp) {
            PlacementHelp(placementState: self.placementState)
        }
        Attachment(id: Attachments.dragHelp) {
            HelpView(text: "Drag to reposition.")
        }
    }

    @MainActor
    func removeSelectedObject() {
        currentDrag = nil
        rootEntity.removeChild(locationEntity)
     }

    @MainActor
    func placeSelectedObject() {
        dprint("\(Self.self).\(#function)")
        // Ensure there’s a placeable object.
        guard let objectToPlace = placementState.objectToPlace else { return }

        let object = objectToPlace.materialize()
        object.position = locationEntity.position
        object.orientation = locationEntity.orientation

        placementState.userPlacedAnObject = true
    }

    @MainActor
    func tap(
        event: EntityTargetValue<SpatialTapGesture.Value>,
        rootEntity: Entity
    ) {
        guard let placeable,
              placeable.placementState == .placing else { return }

        dprint("\(Self.self).\(#function) at \(position)")
        // final placement
        placeSelectedObject()

        // save the resulting position and orientation to the view model
        placeable.tapped(at: position, with: orientation)

        // clear it away
        removeSelectedObject()

        // Reset the session ARKitSession back to its default state
        CloudXRSession.resetArKitSession()

        // Delete planeDetection and cancel tasks related to placement
        if let deviceAnchorUpdatesTask {
            deviceAnchorUpdatesTask.cancel()
            self.deviceAnchorUpdatesTask = nil
        }
        if let planeDetectionUpdatesTask {
            planeDetectionUpdatesTask.cancel()
            self.planeDetectionUpdatesTask = nil
        }
        planeDetection = nil
    }
}

extension PlacementManager {
    /// Run a given function at an approximate frequency.
    ///
    /// > Note: This method doesn’t take into account the time it takes to run the given function itself.
    func run(function: () async -> Void, withFrequency hz: UInt64) async {
        dprint("\(Self.self).\(#function)")
        while true {
            if Task.isCancelled {
                return
            }

            // Sleep for 1 s / hz before calling the function.
            let nanoSecondsToSleep: UInt64 = NSEC_PER_SEC / hz
            do {
                try await Task.sleep(nanoseconds: nanoSecondsToSleep)
            } catch {
                // Sleep fails when the Task is cancelled. Exit the loop.
                return
            }

            await function()
        }
    }

    @MainActor
    static func buildCollisions(for previewEntity: Entity, using modelEntity: ModelEntity) async {
        dprint("\(Self.self).\(#function)")
        // Set a collision component for the model so the app can detect whether the preview overlaps
        // with existing placed entities.
        do {
            let shape = try await ShapeResource.generateConvex(from: modelEntity.model!.mesh)
            previewEntity.components.set(
                CollisionComponent(
                    shapes: [shape],
                    isStatic: false,
                    filter: CollisionFilter(group: PlaceableObject.previewCollisionGroup, mask: .all)
                )
            )

            // Ensure the preview only accepts indirect input (for tap gestures).
            let previewInput = InputTargetComponent(allowedInputTypes: [.indirect])
            previewEntity.components[InputTargetComponent.self] = previewInput
        } catch {
            fatalError("Failed to generate shape resource for model \(modelEntity.name)")
        }
    }
}

extension PlacementManager {
    struct DragState {
        var draggedObject: PlacedEntity
        var initialPosition: simd_float3

        @MainActor
        init(objectToDrag: PlacedEntity) {
            draggedObject = objectToDrag
            initialPosition = objectToDrag.position
        }
    }
}
