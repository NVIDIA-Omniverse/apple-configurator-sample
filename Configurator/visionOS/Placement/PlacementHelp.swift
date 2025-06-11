// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import SwiftUI

struct PlacementHelp: View {
    var placementState: PlacementState

    var body: some View {
        if let message {
            HelpView(text: message)
        }
    }

    var message: String? {
        // Decide on a message to display, in order of importance.
        if !placementState.planeToProjectOnFound {
            return "Point the device at a horizontal surface nearby."
        }
        if placementState.collisionDetected {
            return "The space is occupied."
        }
        if !placementState.userPlacedAnObject {
            return "Tap to place objects."
        }
        return nil
    }
}
