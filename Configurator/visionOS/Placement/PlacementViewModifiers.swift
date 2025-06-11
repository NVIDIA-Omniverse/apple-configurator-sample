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

struct PlacementModifier: ViewModifier {
    var placementManager: PlacementManager
    var sceneEntity: Entity
    var placeable: Placeable

    func body(content: Content) -> some View {
        content
        // Tasks attached to a view automatically receive a cancellation
        // signal when the user dismisses the view. This ensures that
        // loops that await anchor updates from the ARKit data providers
        // immediately end.
        .gesture(
            SpatialTapGesture().targetedToAnyEntity().onEnded { event in
                placementManager.tap(event: event, rootEntity: sceneEntity)
            }
        )
    }
}

extension View {
    func placing(with manager: PlacementManager, sceneEntity: Entity, placeable: Placeable) -> some View {
        modifier(PlacementModifier(placementManager: manager, sceneEntity: sceneEntity, placeable: placeable))
    }
}
