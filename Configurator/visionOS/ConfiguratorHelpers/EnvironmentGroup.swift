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

struct EnvironmentGroup: ViewModifier {
    var opacity: Double
    var radius: CGFloat
    var cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(.all)
            .contentMargins(radius)
            .background(Color(white: opacity, opacity: opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct EnvironmentButton: ViewModifier {
    var opacity: Double = 0.6
    var cornerRadius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(Color(white: opacity, opacity: opacity))
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

extension View {
    /// allows adding `.environmentGroup` to any view to use `EnvironmentGroup` on it - used to group several
    /// UI elements visually
    func environmentGroup(
        opacity: Double = 0.5,
        radius: CGFloat = 10.0,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(EnvironmentGroup(opacity: opacity, radius: radius, cornerRadius: cornerRadius))
    }

    /// allows adding `.environmentButton` to any view to use `EnvironmentButton` on it, which draws buttons in the manner
    /// expected for the environment view
    func environmentButton(
        opacity: Double = 0.6,
        cornerRadius: CGFloat = 24
    ) -> some View {
        modifier(EnvironmentButton(opacity: opacity, cornerRadius: cornerRadius))
    }
}
