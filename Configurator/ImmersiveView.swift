// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import CloudXRKit
import SwiftUI
import RealityKit

struct ImmersiveView: View {
    enum CurrentGesture: String {
        case none
        case rotating
        case scaling
    }

    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) var appModel
    @Environment(ViewModel.self) var viewModel
    
    @State private var sceneEntity = Entity()
    @State private var sessionEntity = Entity()
    @State private var spinnerEntity = Entity()

    // Gesture states.
    @State private var cameraAnchor = Entity()
    @State private var rotationSpeed = Float(0.25)
    @State private var lastLocation = vector_float3.zero
    @State private var lastScale = Float(1)
    @State private var lastRotation = Float.zero
    @State private var currentGesture = CurrentGesture.none
    @State private var modelRotationRadians: Float = 0.0
    @State private var placementManager = PlacementManager()

    @GestureState private var magnifyBy = 1.0

    let minimumRotation = Angle(degrees: 2)
    let minimumScale: CGFloat = 0.075
    
    var body: some View {
        RealityView { content, attachments in
            placementManager.placeable = viewModel

            sceneEntity.name = "Scene"
            sessionEntity.name = "Session"
            spinnerEntity.name = "Spinner"

            sessionEntity.components[CloudXRSessionComponent.self] = .init(session: appModel.session)
            viewModel.sessionEntity = sessionEntity
            spinnerEntity = Entity()
            spinnerEntity.opacity = 1.0
            content.add(spinnerEntity)

            sceneEntity.components[ViewingModeComponent.self] = .init(stateManager: appModel.stateManager, cloudXrEntity: sessionEntity, spinnerEntity: spinnerEntity)
            sceneEntity.components[OpacityComponent.self] = .init(opacity: 0.0)

            content.add(sceneEntity)
            cameraAnchor = Entity()
            content.add(cameraAnchor)
            cameraAnchor.addChild(makeInvisibleGestureWall())
            _ = content.subscribe(to:SceneEvents.Update.self,on: nil, componentType: nil) { frameData in
                if viewModel.viewIsLoading != appModel.stateManager.isAwaitingCompletion("viewingMode") {
                    viewModel.viewIsLoading = appModel.stateManager.isAwaitingCompletion("viewingMode")
                }
                
                let purseVisibility = (appModel.stateManager["purseVisibility"] as? PurseVisibility == PurseVisibility.visible)
                if viewModel.purseVisible != purseVisibility {
                    viewModel.purseVisible = purseVisibility
                }
            
                if let currentViewingMode = appModel.stateManager["viewingMode"] as? ViewingMode,
                   currentViewingMode != viewModel.currentViewingMode {
                     viewModel.currentViewingMode = currentViewingMode
                }
                if let headPose = appModel.session.latestHeadPose {
                    cameraAnchor.transform = headPose
                }
            }
        } update: { content, attachments in
            placementManager.update(session: appModel.session, content: content, attachments: attachments)
        } attachments: {
            if viewModel.isPlacing {
                placementManager.attachments()
            }
        }
        .placing(with: placementManager, sceneEntity: sceneEntity, placeable: viewModel)
        .gesture(
            DragGesture()
                // Translations need an entity to get the coordinate system correct
                .targetedToAnyEntity()
                .onChanged { drag in
                    dragOnChanged(by: drag)
                }
                .onEnded { drag in
                    dragOnEnded(by: drag)
                }
        )
        .gesture(
            SimultaneousGesture(
                RotateGesture3D(constrainedToAxis: .z, minimumAngleDelta: minimumRotation)
                    .onChanged { value in
                        guard currentGesture != .scaling, viewModel.currentViewingMode == .tabletop
                        else {
                            return
                        }
                        currentGesture = .rotating
                        // Rotation direction is indicated by the Z axis direction (+/-)
                        let radians = value.rotation.angle.radians * -sign(value.rotation.axis.z)
                        rotate(to: Float(radians))
                    }
                    .onEnded { value in
                        guard currentGesture != .scaling, viewModel.currentViewingMode == .tabletop
                        else {
                            return
                        }
                        // Rotation direction is indicated by the Z axis direction (+/-)
                        let radians = value.rotation.angle.radians * -sign(value.rotation.axis.z)
                        rotate(to: Float(radians))
                        lastRotation = 0
                        // Turn off currentGesture after a short delay;
                        // otherwise we might get a spurious scale gesture
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            currentGesture = .none
                        }
                    },
                MagnifyGesture(minimumScaleDelta: minimumScale)
                    .onChanged { value in
                        guard currentGesture != .rotating, viewModel.currentViewingMode == .tabletop
                        else {
                            return
                        }
                        currentGesture = .scaling
                        scale(by: Float(value.magnification))
                    }
                    .onEnded() { value in
                        guard
                            currentGesture != .rotating,
                            viewModel.currentViewingMode == .tabletop
                        else {
                            return
                        }
                        scale(by: Float(value.magnification))
                        lastScale = sessionEntity.scale.x
                        // Turn off currentGesture after a short delay;
                        // otherwise we might get a spurious rotation gesture
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            currentGesture = .none
                        }
                    }
            )
        )
        .onChange(of: appModel.session.state) { oldState, newState in
            if newState == .connected {
                appModel.stateManager.resync()
            }
        }
    }

    func rotate(to radians: Float) {
        // RotateGesture3D seems to not have a large range of rotation, so magnify it
        // by a scalar value to allow for more range - arrived at through trial and error
        let rotationFactor: Float = 3

        // Rotations start at minimumRotation, so remove that first, appropriately signed +/-
        let rotation = radians * rotationFactor

        // The only session rotation method available is rotating by a delta
        let delta = rotation - lastRotation

        // Remember the previous value for the next delta
        lastRotation = rotation

        // Rotate the model
        rotateModelBy(radians: delta)
    }

    public func rotateModelBy(radians: Float) {
        modelRotationRadians += radians
        sessionEntity.setOrientation(simd_quatf(angle: modelRotationRadians, axis: simd_float3(0, 1, 0)), relativeTo: nil)
    }

    func scale(by factor: Float) {
        if viewModel.currentViewingMode == .tabletop {
            let newScale = Float(factor) * lastScale

            if newScale > 5 {
                sessionEntity.scale = .one * 5;
            }
            else if newScale < 0.2 {
                sessionEntity.scale = .one * 0.2
            }
            else if newScale < 1.1 && newScale > 0.9 {
                sessionEntity.scale = .one * 1.0
            }
            else {
                sessionEntity.scale = .one * newScale
            }
        }
    }

    func dragOnChanged(by drag: EntityTargetValue<DragGesture.Value>) {
        if viewModel.currentViewingMode == .tabletop {
            dragTableTop(by: drag)
        }
        else {
            dragPortal(by: drag)
        }
    }

    func dragOnEnded(by drag: EntityTargetValue<DragGesture.Value>) {
        if viewModel.currentViewingMode == .tabletop {
            dragTableTop(by: drag)
        }
        else {
            dragPortal(by: drag)
        }

        finishedGesture()
    }

    func dragPortal(by drag: EntityTargetValue<DragGesture.Value>) {
        guard drag.entity.name == ViewingModeSystem.portalBarName,
              // the parent of the portal and the portalBar should be dragged around
              let bloomPreventionParent = drag.entity.parent,
              appModel.session.state == .connected
        else { return }
        let locationScene = drag.convert(drag.location3D, from: .local, to: .scene)
        guard lastLocation != .zero else {
            lastLocation = locationScene
            return
        }
        move(bloomPreventionParent, to: locationScene)
    }

    func move(_ entity: Entity, to location: simd_float3) {
        guard appModel.session.state == .connected else { return }
        entity.position = simd_float3(
            location.x,
            // Portal movement only in X and Z
            entity.position.y,
            location.z - ViewingModeSystem.portalContainerPosition.z)
        guard let parent = entity.parent else {return}
        if let latestHeadPose = appModel.session.latestHeadPose {
            var headPosition = latestHeadPose.translation
            // Convert head pose to portal local space
            headPosition = parent.convert(position: headPosition, from: nil)
            headPosition.y = entity.position.y
            entity.look(at: headPosition, from: entity.position, relativeTo: parent, forward: .positiveZ)
        }
    }

    /// move the current tabletop/portal entity to the given location
    func move(to position: simd_float3, rotation: simd_quatf) {
        let entity: Entity
        if viewModel.currentViewingMode == .portal {
            guard let portalMovingEntity = sceneEntity.findEntity(named: "bloomPreventionParent" ) else { return }
            entity = portalMovingEntity
        } else {
            entity = sessionEntity
        }
        move(entity, to: position)
    }

    func dragTableTop(by drag: EntityTargetValue<DragGesture.Value>) {
        // drag.location3D can sometimes be NaN, so be careful in general..
        let location = drag.location3D
        guard !location.isNaN, location.isFinite else {
            return
        }

        let locationScene = drag.convert(location, from: .local, to: .scene)
        // Even if drag.location3D isn't NaN, convert can return a NaN
        guard !locationScene.isNaN, locationScene.isFinite else {
            return
        }

        if lastLocation != .zero {
            let lastDelta = locationScene - lastLocation
            // Need to transform the lastDelta displacement into camera space
            if let latestHeadPose = appModel.session.latestHeadPose {
                let lastDeltaCamera = latestHeadPose.matrix.inverse * vector_float4(lastDelta.x, lastDelta.y, lastDelta.z, 0)
                rotateModelBy(radians: rotationSpeed * lastDeltaCamera.x)
            }
        }

        lastLocation = locationScene
    }

    func finishedGesture() {
        lastLocation = .zero
    }

    // TODO: Change this to the bounding box of the object sent from OV
    func makeInvisibleGestureWall() -> Entity {
        // Add an invisible plane that covers the viewport, attached to the headset that can accept gestures
        // so as to not get in the way of gestures on UI objects, the plane is 20 meters away.
        let plane = Entity()
        plane.components.set(InputTargetComponent())
        var collision = CollisionComponent(shapes: [.generateBox(width: 40, height: 40, depth: 0.01)])
        collision.mode = .trigger
        plane.components.set(collision)
        plane.position.z = -20
        return plane
    }
}
