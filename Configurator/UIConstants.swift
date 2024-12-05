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

struct UIConstants {
    /// general margin
    static let margin: CGFloat = 20

    /// size of image assets (trim is subject to being 2/3 this size)
    static let assetWidth: CGFloat = 277

    /// size of the camera sheet popover
    static let cameraSheetSize = CGSize(width: 400, height: 700)

    /// size of the buttons in the top corners of the window
    static let topCornerButtonSize: CGFloat = 33

    /// minimize the scrollview height so there isn't a big scroll-bounce space between
    /// it and the buttons
    static let maxTrimScrollHeight: CGFloat = 266

    /// width of entire action control
    static let actionWidth: CGFloat = 75

    /// width of toggle button section of action control
    static let actionToggleSize = CGSize(width: 120, height: 35)

    /// value that most closely matches Figma design
    static let actionButtonBackgroundColor = Color(hex: 0xaeaeae, alpha: 0.33)

    /// value copied from Figma design
    static let actionButtonDashColor = Color(hex: 0x13BCA5)

    /// General font used for descriptions of assets etc
    static let itemFont: Font = .custom("SF Pro", size: 17)
        .weight(.bold)

    /// size of font used in toolbar at the bottom of the view
    static let toolbarFont: Font = .custom("SF Pro", size: 17)
        .leading(.loose)
        .weight(.bold)

    /// size of font used to headline each section of the window
    static let sectionFont: Font = .custom("SF Pro", size: 24)
        .leading(.loose)
        .weight(.bold)

    /// size of font used in the titlebar of the window
    static let titleFont: Font = .custom("SF Pro", size: 29)
        .leading(.loose)
        .weight(.bold)
}

#if DEBUG
func dprint(_ strings: String...) {
    print(strings.joined(separator: " "))
}
#else
func dprint(_ str: String...) { }
#endif
