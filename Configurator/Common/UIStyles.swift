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

func customButton(image: String, text: String, action: @escaping () -> Void, isDisabled: Bool = false) -> some View {
    Button(
        action: action,
        label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 170, height: 60)
                HStack {
                    Image(systemName: image)
                        .font(.largeTitle)
                        .foregroundColor(.white)

                    Text(text)
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(.leading, 20)
            }
        }
    )
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.5 : 1)
}
