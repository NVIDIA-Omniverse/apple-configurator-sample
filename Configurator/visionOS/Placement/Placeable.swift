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

/// Placeable describes a class that handles placing an object on a horizontal surface.
/// When `tapped(at position: with orientation:)` is called, the default implementation
/// sets the values of `placementPosition` and `placementOrientation`, and then calls
/// the `wasTapped()` method to allow the class to perform any other cleanup that is required.
///
/// The `PlacementManager` object is passed this class, and when its `start()` method is called,
/// initiates the placement activity, adding the placement "puck" to the scene. Before the `tapped()` method
/// is called, the puck is removed from the scene by the manager.
protocol Placeable: AnyObject {
    var placementState: PlacementManager.State { get set }
    var placementPosition: simd_float3 { get set }
    var placementOrientation: simd_quatf { get set }
    var isPlacing: Bool { get }
    func tapped(at position: simd_float3, with orientation: simd_quatf)
    func wasTapped()
    func alert(_ message: String)
}

extension Placeable {
    var isPlacing: Bool { placementState != .none }

    func tapped(at position: simd_float3, with orientation: simd_quatf) {
        placementPosition = position
        placementOrientation = orientation
        placementState = .none
        wasTapped()
    }
    
    // override this to perform more actions after being tapped
    func wasTapped() {
    }
    
    // this should be overridden with an alert dialog
    func alert(_ message: String) {
        dprint("Placenemt: \(message)")
    }
}
