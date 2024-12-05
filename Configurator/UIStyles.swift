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

struct OrnamentStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .padding(12)
            .glassBackgroundEffect(in: .rect(cornerRadius: 50))
    }
}

extension View {
    /// allows adding `.ornamentStyle` to any view to use `OrnamentStyle` on it
    var ornamentStyle: some View {
        modifier(OrnamentStyle())
    }
}

struct SelectedStyle: ViewModifier {
    var isSelected: Bool
    func body(content: Content) -> some View {
        if isSelected {
            ZStack {
                content
                    .buttonStyle(.borderedProminent)
                    .tint(Color(white: 1.0, opacity: 0.1))
            }
        } else {
            content
        }
    }
}

extension View {
    /// allows adding `.coatSelectedStyle(isSelected: true)` to make the view look "selected" per `COATSelectedStyle`
    func selectedStyle(isSelected: Bool) -> some View {
        modifier(SelectedStyle(isSelected: isSelected))
    }
}

struct CustomButtonStyle: ButtonStyle {
    let faint = Color(red: 1, green: 1, blue: 1, opacity: 0.05)
    var isDisabled = false
    func makeBody(configuration: Self.Configuration) -> some View {
        if isDisabled {
            configuration.label
                .background(.clear)
        } else {
            configuration.label
                .background(configuration.isPressed ? faint : .clear)
                .hoverEffect(.lift)
        }
    }
}
