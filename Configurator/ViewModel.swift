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
class ViewModel: Placeable {
    // Note that we only want to set currentViewingMode and viewIsLoading if their values have changed,
    // since setting these members, even if they already have the passed value, can trigger a UI refresh
    // Viewing Mode
    var currentViewingMode: ViewingMode = ViewingMode.portal {
        willSet {
            assert(currentViewingMode != newValue)
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
    var sessionEntity: Entity?
    var anyImmersiveSpaceRunning = false
    var ipdImmersiveSpaceRunning = false
    var disableFeedback = false
    var isRatingViewPresented = false
    var ratingText = "Feedback"
    var showDisconnectionAlert = false

    // placement
    var placementState: PlacementManager.State = .none
    var placementPosition = simd_float3()
    var placementOrientation = simd_quatf.identity
}

extension ViewModel {
    func wasTapped() {
        // called when model is placed at placementPosition
        // Need something like ImmersiveView.dragPortal() since it translates the model
        if let sessionEntity {
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
