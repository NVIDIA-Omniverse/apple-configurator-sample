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

    private func rotateEnabled(_ value: RotateGesture.Value) -> Bool {
        !value.rotation.radians.isNaN
    }

    private func magnifyEnabled(_ value: MagnifyGesture.Value) -> Bool {
        !value.magnification.isNaN
    }

    @MainActor
    var magnifyGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: minimumScale)
            .onChanged { [self] value in
                guard magnifyEnabled(value) else {
                    Self.logger.info("Gesture: scaling is not allowed")
                    return
                }
                configuratorViewModel.currentGesture = .scaling
                scaleRemoteWorldOrigin(by: Float(value.magnification))
            }
            .onEnded { [self] value in
                guard magnifyEnabled(value) else {
                    Self.logger.info("Gesture: scaling is not allowed")
                    return
                }
                scaleRemoteWorldOrigin(by: Float(value.magnification))
                cleanUpOnScaleGestureEnd()
            }
    }

    @MainActor
    var rotationGesture: some Gesture {
        RotateGesture(minimumAngleDelta: minimumRotation)
            .onChanged { [self] value in
                guard rotateEnabled(value) else {
                    Self.logger.info("Gesture: rotation is not allowed")
                    return
                }
                configuratorViewModel.currentGesture = .rotating
                let correctedRadians = rotateGestureCorrection(to: Float(-value.rotation.radians))
                rotateRemoteWorldOrigin(by: correctedRadians)
            }
            .onEnded { [self] value in
                guard rotateEnabled(value) else {
                    Self.logger.info("Gesture: rotation is not allowed")
                    return
                }
                let correctedRadians = rotateGestureCorrection(to: Float(-value.rotation.radians))
                rotateRemoteWorldOrigin(by: correctedRadians)
                cleanUpOnRotationGestureEnd()
            }
    }

    @MainActor
    func rotateRemoteWorldOriginWithSlider() {
        precondition(configuratorViewModel.sessionEntity != nil, "Gesture: rotation slider cannot find session entity")
        guard let sessionEntity = configuratorViewModel.sessionEntity else { return }
        configuratorViewModel.modelRotationRadians = -Float(.pi * configuratorViewModel.rotationAngle / 180)
        sessionEntity.setOrientation(simd_quatf(angle: configuratorViewModel.modelRotationRadians, axis: simd_float3(0, 1, 0)), relativeTo: nil)
    }

    @MainActor
    private func rotateRemoteWorldOrigin(by radians: Float) {
        precondition(configuratorViewModel.sessionEntity != nil, "Gesture: rotation cannot find session entity")
        guard let sessionEntity = configuratorViewModel.sessionEntity else { return }
        configuratorViewModel.modelRotationRadians += radians
        // limit its range to -pi to pi to avoid overflow.
        if configuratorViewModel.modelRotationRadians > .pi {
            configuratorViewModel.modelRotationRadians -= .pi * 2
        } else if configuratorViewModel.modelRotationRadians <= -.pi {
            configuratorViewModel.modelRotationRadians += .pi * 2
        }

        // Sync the rotation angle to the slider bar.
        configuratorViewModel.rotationAngle = 180 * Double(configuratorViewModel.modelRotationRadians) / .pi
        sessionEntity.setOrientation(simd_quatf(angle: configuratorViewModel.modelRotationRadians, axis: simd_float3(0, 1, 0)), relativeTo: nil)

        Self.logger.info("Gesture: rotate the session entity to \(self.configuratorViewModel.rotationAngle)")
    }

    @MainActor
    func scaleRemoteWorldOriginWithSlider() {
        precondition(configuratorViewModel.sessionEntity != nil, "Gesture: scaling slider cannot find session entity")
        guard let sessionEntity = configuratorViewModel.sessionEntity else { return }
        // No need to do scale correction when using slider.
        sessionEntity.scale = .one * Float(configuratorViewModel.objectScale)
    }

    @MainActor
    func scaleRemoteWorldOrigin(by factor: Float) {
        precondition(configuratorViewModel.sessionEntity != nil, "Gesture: scaling cannot find session entity")
        guard let sessionEntity = configuratorViewModel.sessionEntity else { return }
        let correctedScale = snapScale(by: factor)
        // Sync the scale to the slider bar.
        configuratorViewModel.objectScale = Double(correctedScale)
        sessionEntity.scale = .one * correctedScale

        Self.logger.info("Gesture: scale the session entity by \(correctedScale)")
    }
}
