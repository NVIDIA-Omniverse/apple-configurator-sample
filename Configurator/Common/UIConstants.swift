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
