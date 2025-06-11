// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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

extension GestureHelper {

    static private let rotationSpeed = Float(0.25)

    var magnifyEnabled: Bool {
        configuratorViewModel.currentGesture != .rotating
        && configuratorViewModel.currentViewing.mode == .tabletop
    }

    private var rotateEnabled: Bool {
        configuratorViewModel.currentGesture != .scaling
        && configuratorViewModel.currentViewing.mode == .tabletop
    }

    @MainActor
    private func rotateRemoteWorldOrigin(by radians: Float) {
        guard let sessionEntity = configuratorViewModel.sessionEntity else { return }
        configuratorViewModel.modelRotationRadians += radians
        sessionEntity.setOrientation(simd_quatf(angle: configuratorViewModel.modelRotationRadians, axis: simd_float3(0, 1, 0)), relativeTo: nil)
    }

    @MainActor
    func scaleRemoteWorldOrigin(by factor: Float) {
        guard let sessionEntity = configuratorViewModel.sessionEntity else { return }
        let correctedScale = snapScale(by: factor)
        sessionEntity.scale = .one * correctedScale
    }

    @MainActor
    var magnifyGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: minimumScale)
            .onChanged { [self] value in
                guard magnifyEnabled else { return }
                configuratorViewModel.currentGesture = .scaling
                scaleRemoteWorldOrigin(by: Float(value.magnification))
            }
            .onEnded { [self] value in
                guard magnifyEnabled else { return }
                scaleRemoteWorldOrigin(by: Float(value.magnification))
                cleanUpOnScaleGestureEnd()
            }
    }

    @MainActor
    var rotationGesture: some Gesture {
        RotateGesture3D(constrainedToAxis: .z, minimumAngleDelta: minimumRotation)
            .onChanged { [self] value in
                guard rotateEnabled else { return }
                configuratorViewModel.currentGesture = .rotating
                // Rotation direction is indicated by the Z axis direction (+/-)
                let radians = value.rotation.angle.radians * -sign(value.rotation.axis.z)
                rotateRemoteWorldOrigin(by: rotateGestureCorrection(to: Float(radians)))
            }
            .onEnded { [self] value in
                guard rotateEnabled else { return }
                // Rotation direction is indicated by the Z axis direction (+/-)
                let radians = value.rotation.angle.radians * -sign(value.rotation.axis.z)
                rotateRemoteWorldOrigin(by: rotateGestureCorrection(to: Float(radians)))
                cleanUpOnRotationGestureEnd()
            }
    }

    @MainActor
    var dragGesture: some Gesture {
        DragGesture()
            // Translations need an entity to get the coordinate system correct
            .targetedToAnyEntity()
            .onChanged { [self] drag in
                dragOnChanged(by: drag)
            }
            .onEnded { [self] drag in
                dragOnEnded(by: drag)
            }
    }

    @MainActor
    private func dragOnChanged(by drag: EntityTargetValue<DragGesture.Value>) {
        if configuratorViewModel.currentViewing.mode == .tabletop {
            dragTableTop(by: drag)
        }
        else {
            dragPortal(by: drag)
        }
    }

    @MainActor
    private func dragOnEnded(by drag: EntityTargetValue<DragGesture.Value>) {
        if configuratorViewModel.currentViewing.mode == .tabletop {
            dragTableTop(by: drag)
        }
        else {
            dragPortal(by: drag)
        }

        cleanUpOnDragGestureEnd()
    }

    private func dragPortal(by drag: EntityTargetValue<DragGesture.Value>) {
        guard drag.entity.name == ViewingModeSystem.portalBarName,
              // the parent of the portal and the portalBar should be dragged around
              let bloomPreventionParent = drag.entity.parent,
              configuratorAppModel.session?.state == .connected
        else { return }
        let locationScene = drag.convert(drag.location3D, from: .local, to: .scene)
        guard configuratorViewModel.lastLocation != .zero else {
            configuratorViewModel.lastLocation = locationScene
            return
        }
        move(bloomPreventionParent, to: locationScene)
    }

    private func move(_ entity: Entity, to location: simd_float3) {
        guard configuratorAppModel.session?.state == .connected else { return }
        entity.position = simd_float3(
            location.x,
            // Portal movement only in X and Z
            entity.position.y,
            location.z - ViewingModeSystem.portalContainerPosition.z)
        guard let parent = entity.parent else {return}
        if let latestHeadPose = configuratorAppModel.session?.latestHeadPose {
            var headPosition = latestHeadPose.translation
            // Convert head pose to portal local space
            headPosition = parent.convert(position: headPosition, from: nil)
            headPosition.y = entity.position.y
            entity.look(at: headPosition, from: entity.position, relativeTo: parent, forward: .positiveZ)
        }
    }

    /// move the current tabletop/portal entity to the given location
    private func move(to position: simd_float3, rotation: simd_quatf) {
        let entity: Entity
        if configuratorViewModel.currentViewing.mode == .portal {
            guard let portalMovingEntity = configuratorViewModel.sceneEntity?.findEntity(named: "bloomPreventionParent" ) else { return }
            entity = portalMovingEntity
        } else {
            guard let sessionEnity = configuratorViewModel.sessionEntity else { return }
            entity = sessionEnity
        }
        move(entity, to: position)
    }

    @MainActor
    private func dragTableTop(by drag: EntityTargetValue<DragGesture.Value>) {
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

        if configuratorViewModel.lastLocation != .zero {
            let lastDelta = locationScene - configuratorViewModel.lastLocation
            // Need to transform the lastDelta displacement into camera space
            if let latestHeadPose = configuratorAppModel.session?.latestHeadPose {
                let lastDeltaCamera = latestHeadPose.matrix.inverse * vector_float4(lastDelta.x, lastDelta.y, lastDelta.z, 0)
                rotateRemoteWorldOrigin(by: Self.rotationSpeed * lastDeltaCamera.x)
            }
        }

        configuratorViewModel.lastLocation = locationScene
    }
}
