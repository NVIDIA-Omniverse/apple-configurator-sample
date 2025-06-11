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
import OSLog

enum CurrentGesture: String {
    case none
    case rotating
    case scaling
}

class GestureHelper: ObservableObject {
    var configuratorViewModel: ConfiguratorViewModel
    var configuratorAppModel: ConfiguratorAppModel

    let minimumRotation = Angle(degrees: 2)
    let minimumScale = CGFloat(0.075)
    private let gestureOffDelay = Double(0.2)

    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: GestureHelper.self)
    )

    init(configuratorViewModel: ConfiguratorViewModel, configuratorAppModel: ConfiguratorAppModel) {
        self.configuratorViewModel = configuratorViewModel
        self.configuratorAppModel = configuratorAppModel
    }

    @MainActor
    func translateRemoteWorldOrigin(To translationVecFromUser: simd_float3) {
        if let sessionEntity = configuratorViewModel.sessionEntity {
            sessionEntity.position = translationVecFromUser
        }
    }

    func snapScale(by factor: Float) -> Float {
        let newScale = Float(factor) * configuratorViewModel.lastScale
        var scale = Float(0)
        if newScale > 5 {
            scale = 5
        } else if newScale < 0.2 {
            scale = 0.2
        } else if newScale < 1.1 && newScale > 0.9 {
            scale = 1.0
        } else {
            scale = newScale
        }
        return scale
    }

    func rotateGestureCorrection(to radians: Float) -> Float {
        // RotateGesture3D seems to not have a large range of rotation, so magnify it
        // by a scalar value to allow for more range - arrived at through trial and error
        let rotationFactor: Float = 3

        // rotations start at minimumRotation, so remove that first, appropriately signed +/-
        let rotation = radians * rotationFactor

        // the only session rotation method available is rotating by a delta
        let delta = rotation - configuratorViewModel.lastRotation

        // remember the previous value for the next delta
        configuratorViewModel.lastRotation = rotation

        return delta
    }

    func cleanUpOnRotationGestureEnd() {
        configuratorViewModel.lastRotation = 0
        turnOffGestureAfterDelay()
    }

    func cleanUpOnDragGestureEnd() {
        configuratorViewModel.lastLocation = .zero
    }

    func cleanUpOnScaleGestureEnd() {
        if let sessionEntity = configuratorViewModel.sessionEntity {
            configuratorViewModel.lastScale = sessionEntity.scale.x
        }
        turnOffGestureAfterDelay()
    }

    // turn off currentGesture after a short delay; otherwise we might get a spurious rotation gesture
    // thrown in right at the end
    private func turnOffGestureAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + gestureOffDelay) {
            self.configuratorViewModel.currentGesture = .none
        }
    }
}
