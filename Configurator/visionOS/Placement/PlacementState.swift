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
import RealityKit

@Observable
class PlacementState {
    var selectedObject: PlaceableObject?
    var highlightedObject: PlacedEntity?
    var objectToPlace: PlaceableObject? { isPlacementPossible ? selectedObject : nil }
    var userDraggedAnObject = false

    var planeToProjectOnFound = false

    var activeCollisions = 0
    var collisionDetected: Bool { activeCollisions > 0 }
    var dragInProgress = false
    var userPlacedAnObject = false
    var deviceAnchorPresent = false
    var planeAnchorsPresent = false

    var shouldShowPreview: Bool {
        deviceAnchorPresent && planeAnchorsPresent && !dragInProgress && highlightedObject == nil
    }

    var isPlacementPossible: Bool {
        selectedObject != nil && shouldShowPreview && planeToProjectOnFound && !collisionDetected && !dragInProgress
    }
}

extension PlacementState {
    func withPlaneFound() -> PlacementState {
        planeToProjectOnFound = true
        return self
    }

    func withCollisionDetected() -> PlacementState {
        activeCollisions = 1
        return self
    }
}
