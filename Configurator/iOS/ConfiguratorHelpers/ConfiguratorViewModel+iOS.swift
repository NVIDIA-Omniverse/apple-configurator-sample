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
class ConfiguratorViewModel {
    // Note that we only want to set currentViewing and viewIsLoading if their values have changed,
    // since setting these members, even if they already have the passed value, can trigger a UI refresh
    // Viewing Mode
    var currentViewing = ViewingModel(.tabletop) {
        willSet {
            assert(currentViewing.mode != newValue.mode)
        }
    }

    var viewIsLoading = true {
        willSet {
            assert(viewIsLoading != newValue)
        }
    }

    // Asset states.
    var purseVisible = true
    var purseRotated = false

    var lightIntensity: Float = 1.0
    
    var sessionEntity: Entity?

    var placementState: PlacementManager.State = .none
    var isPlacing: Bool { false }

    // iPad gesture related
    var lastLocation = vector_float3.zero
    var lastScale = Float(1)
    var lastRotation = Float.zero
    var modelRotationRadians = Float.zero
    var currentGesture = CurrentGesture.none

    var userTranslationX = Double(0)
    var userTranslationY = Double(0)
    var userTranslationZ = Double(0)
    var rotationAngle = Double(0)
    var objectScale = Double(1.0)
    var initPlacementLocation = vector_float3.zero

    var translationFromUser: simd_float3 {
        simd_float3(
            Float(userTranslationX),
            Float(userTranslationY),
            Float(userTranslationZ)
        )
    }
}

public extension simd_float4x4 {
    static var identity: simd_float4x4 { matrix_identity_float4x4 }
    static var zero: simd_float4x4 { simd_float4x4() }
}

public extension simd_quatf {
    static var identity: simd_quatf { .init(matrix_float4x4.identity) }
}
