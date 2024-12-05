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

struct ConfigureView: View {
    @Binding var section: ViewSelector.Section
    @Environment(AppModel.self) var appModel
    @Environment(ViewModel.self) var viewModel

    @State var showTableView = false
    @State var showCameras = false
    @State private var scrollViewSize: CGSize = .zero

    let placementHelp = "Place model on a horizontal surface"
    let placementPortalHelp = "Placement only available in tabletop mode"
    let placementPlacingHelp = "Currently placing"
    // simulator does not support placement
    let placementNotInSimulator = "Cannot place in simulator"
    #if targetEnvironment(simulator)
    let allowPlacement = false
    #else
    let allowPlacement = true
    #endif

    var placementDisabled: Bool { viewModel.isPlacing || viewModel.currentViewingMode == .portal || !allowPlacement }

    var placementHelpString: String {
        if !allowPlacement {
            placementNotInSimulator
        } else if viewModel.currentViewingMode == .portal {
            placementPortalHelp
        } else if viewModel.isPlacing {
            placementPlacingHelp
        } else {
            placementHelp
        }
    }

    let dashed: AnyView = AnyView(
        Image(systemName: "app.dashed")
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(UIConstants.actionButtonDashColor)
            .font(Font.body.weight(.medium))
    )

    var body: some View {
        VStack {
            header("Color")
            colorList
            space
            header("Style")
            styleList
            space
            purseActions
            Spacer().frame(height: 10)
        }
        .padding(.all)
    }

    /// A minimalist `Spacer()` for a small margin
    var space: some View {
        Spacer()
            .frame(width: UIConstants.margin, height: UIConstants.margin)
    }

    /// A left-justified header in the appropriate font
    func header(_ str: String) -> some View {
        HStack {
            Text(str)
                .font(UIConstants.sectionFont)
            Spacer()
        }
    }

    var colorList: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: UIConstants.margin/2) {
                    ForEach (PurseColor.allCases, id: \.self) { color in
                        colorAsset(color)
                    }
                }
            }
        }
    }

    let styleSize: CGFloat = UIConstants.assetWidth * 0.66

    var styleList: some View {
        ScrollView(showsIndicators: false) {
            HStack {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: styleSize))]) {
                    ForEach (Style.allCases, id: \.self) { style in
                        styleAsset(style, size: styleSize)
                    }
                }
            }
        }
        .frame(height: UIConstants.maxTrimScrollHeight)
    }

    var purseActions: some View {
        // Horizontal stack to place the Rotate and Visibility buttons
        // side by side
        HStack {
            LabelButton(
                label: "Visibility",
                onText: "On",
                offText: "Off",
                toggleView: true,
                icon: AnyView(dashed),
                isOn: viewModel.purseVisible
            )  { isOn in
                // Updates the state of purse visibility
                appModel.stateManager["purseVisibility"] = isOn
                    ? PurseVisibility.visible
                    : PurseVisibility.hidden
            } textCondition: { _ in
                // Condition to determine the text displayed on the button
                viewModel.purseVisible
            }
            LabelButton(
                // The button's label
                label: "Rotate",
                // not a toggle button
                toggleView: false,
                // Icon for the button
                icon: AnyView(dashed),
                isOn: viewModel.purseRotated
            )  { isOn in
                // Sends the appropriate rotation action
                if isOn {
                    appModel.stateManager.send(RotationAction.rotateCCW)
                } else {
                    appModel.stateManager.send(RotationAction.rotateCW)
                }
                viewModel.purseRotated = isOn
            }
            LabelButton(
                label: "Place",
                toggleView: false,
                icon: AnyView(dashed)
            )  { isOn in
                viewModel.placementState = .started
                dprint("\(Self.self).\(#function) place model")
            }
            .disabled(placementDisabled)
            .help(placementHelpString)
        }
    }
    
    func colorAsset(_ item: PurseColor, size: CGFloat = UIConstants.assetWidth) -> some View {
        Button {
            appModel.stateManager["color"] = item
        } label: {
            VStack {
                // Item image - maybe fall back to something if image is not found?
                Image(String(item.rawValue))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .font(.system(size: 128, weight: .medium))
                    .cornerRadius(UIConstants.margin)
                    .frame(width: size)
                // Item name
                HStack {
                    Text(String(item.description))
                        .font(UIConstants.itemFont)
                    Spacer()
                }
            }.frame(width: size)
        }
        .buttonStyle(CustomButtonStyle())
    }
    
    func styleAsset(_ item: Style, size: CGFloat = UIConstants.assetWidth) -> some View {
        Button {
            appModel.stateManager["style"] = item
        } label: {
            VStack {
                // Item image - maybe fall back to something if image is not found?
                Image(String(item.rawValue))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .font(.system(size: 128, weight: .medium))
                    .cornerRadius(UIConstants.margin)
                    .frame(width: size)
                // Item name
                HStack {
                    Text(String(item.description))
                        .font(UIConstants.itemFont)
                    Spacer()
                }
            }.frame(width: size)
        }
        .buttonStyle(CustomButtonStyle())
    }
}

#Preview {
    @Previewable @State var viewModel = ViewModel()
    return VStack {
        ViewSelector(section: .configure)
    }
    .environment(viewModel)
    .ornamentStyle
}
