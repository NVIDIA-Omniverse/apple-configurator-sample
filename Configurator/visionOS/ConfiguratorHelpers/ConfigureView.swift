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
    @Environment(ConfiguratorAppModel.self) var configuratorAppModel
    @Environment(ConfiguratorViewModel.self) var configuratorViewModel

    @State var showTableView = false
    @State var showCameras = false
    @State private var scrollViewSize: CGSize = .zero

    let dashed: AnyView = AnyView(
        Image(systemName: "app.dashed")
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(ConfiguratorUIConstants.actionButtonDashColor)
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
            actionButtons
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
                    ForEach(configuratorAppModel.asset.styleList) { color in
                        styleAsset(key: "color", item: color)
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
                    ForEach(configuratorAppModel.asset.subStyleList) { substyle in
                        styleAsset(key: "style", item: substyle, size: styleSize)
                    }
                }
            }
        }
        .frame(height: ConfiguratorUIConstants.maxTrimScrollHeight)
    }

    var actionButtons: some View {
        VStack {
            HStack {
                ForEach(configuratorAppModel.asset.actions) { action in
                    LabelButton(
                        label: action.label,
                        onText: action.onText ?? "",
                        offText: action.offText ?? "",
                        toggleView: action.shouldToggleView,
                        icon: AnyView(dashed),
                        isOn: action.isOn ?? true
                    ) { isOn in
                        action.toggle(isOn)
                    } textCondition: { isOn in
                        action.textCondition?(isOn) ?? true
                    }
                    // should probably use the `.if()` viewModifier here
                    // see: https://www.avanderlee.com/swiftui/conditional-view-modifier/
                    .disabled(action.isDisabled())
                    .help(action.helpText())
                }
            }
        }
    }

    func styleAsset(key: String, item: any AssetStyle, size: CGFloat = UIConstants.assetWidth) -> some View {
        Button {
            configuratorAppModel.asset[key] = item
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
                        .font(ConfiguratorUIConstants.itemFont)
                    Spacer()
                }
            }.frame(width: size)
        }
        .buttonStyle(CustomButtonStyle())
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()
    @Previewable @State var configuratorViewModel = ConfiguratorViewModel()
    @Previewable @State var configuratorAppModel = ConfiguratorAppModel()

    appModel.application = .purse_rel
    appModel.session = CloudXRSession(config: Config())

    configuratorAppModel
        .setup(application: appModel.application, configuratorViewModel: configuratorViewModel, session: appModel.session!)

    return
        ConfigureView()
            .environment(configuratorAppModel)
            .environment(configuratorViewModel)
            .environment(appModel)

}
