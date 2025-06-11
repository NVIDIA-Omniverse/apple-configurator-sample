// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import SwiftUI
import RealityKit

/// The data that the app uses to configure its views.
@Observable
class ConfiguratorViewModel: Placeable {
    var sessionEntity: Entity?

    // Note that we only want to set currentViewing and viewIsLoading if their values have changed,
    // since setting these members, even if they already have the passed value, can trigger a UI refresh
    // Viewing Mode
    var currentViewing = ViewingModel(.portal) {
        willSet {
            assert(currentViewing != newValue)
        }
    }

    var viewIsLoading = true {
        willSet {
            assert(viewIsLoading != newValue)
        }
    }

    var purseVisible = true
    var purseRotated = false


    var lightIntensity: Float = 1.0


    var sceneEntity: Entity?
    // placement
    var placementState: PlacementManager.State = .none
    var placementPosition = simd_float3()
    var placementOrientation = simd_quatf.identity

    // gesture related
    var lastLocation = vector_float3.zero
    var lastScale = Float(1)
    var lastRotation = Float.zero
    var modelRotationRadians = Float.zero
    var currentGesture = CurrentGesture.none
}


extension ConfiguratorViewModel {
    func wasTapped() {
        // called when model is placed at placementPosition
        // Need something like ImmersiveView.dragPortal() since it translates the model
        if let sessionEntity = sessionEntity {
            sessionEntity.position = placementPosition
        }
    }
}

// stolen from CloudXRKit - statics need to be separately declared public, it seems
public extension simd_float4x4 {
    static var identity: simd_float4x4 { matrix_identity_float4x4 }
    static var zero: simd_float4x4 { simd_float4x4() }
}

public extension simd_quatf {
    static var identity: simd_quatf { .init(matrix_float4x4.identity) }
}
