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
import CloudXRKit

struct LabelButton: View {
    var label = "Label"
    var onText = "On"
    var offText = "Off"
    var toggleView = false
    var icon: AnyView
    @State var isOn = false

    var action: (Bool) -> Void = { _ in }
    var textCondition: (Bool) -> Bool = { on in on }
    var onOffWidth: CGFloat = ConfiguratorUIConstants.actionWidth
    // values that most closely match Max's designs
    var actionBackgroundColor = ConfiguratorUIConstants.actionButtonBackgroundColor

    var body: some View {
        Button {
            isOn.toggle()
            action(isOn)
        } label: {
            HStack {
                icon
                space
                Text(label)
                
                if toggleView {
                    space
                    Text(textCondition(isOn) ? onText : offText)
                        .frame(width: onOffWidth)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(actionBackgroundColor)
                                .frame(
                                    width: ConfiguratorUIConstants.actionToggleSize.width,
                                    height: ConfiguratorUIConstants.actionToggleSize.height
                                )
                        }
                }
            }
        }
    }

    /// A minimalist `Spacer()` for a small margin
    var space: some View {
        Spacer()
            .frame(width: UIConstants.margin, height: UIConstants.margin)
    }
}

#Preview {
    let dashed = Image(systemName: "app.dashed")
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(Color.init(hex: 0xFFD60A))
        .font(Font.body.weight(.medium))

    return LabelButton(
        label: "Doors",
        onText: "Open",
        offText: "Closed",
        toggleView: true,
        icon: AnyView(dashed)
    )  { isOn in
        dprint("it \(isOn ? "is" : "is not") on")
    }
}
