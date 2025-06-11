// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import CloudXRKit
import SwiftUI
import RealityKit

extension ConfiguratorStreamingView {

    static private let sliderRange = Double(5)
    static private let sliderTextWidth = CGFloat(200)

    private var interactionButtonImage: String {
        switch selectedSection {
        case .transform:
            "hand.draw.fill"
        default:
            "hand.draw"
        }
    }

    private var transformResetButtonImage: String {
        "arrow.counterclockwise"
    }

    private var configButtonImage: String {
        switch selectedSection {
        case .launch:
            "gearshape.fill"
        default:
            "gearshape"
        }
    }

    private var modeButtonImage: String {
        switch configuratorViewModel.currentViewing.mode {
        case .portal:
            "cube.fill"
        case .tabletop:
            "cube"
        }
    }
    
    private var placementButtonImage: String {
        switch placementManager.state {
        case .started, .none:
            "square.and.arrow.down.fill"
        case .placed:
            "square.and.arrow.down"
        }
    }
    
    private var hudImage: String {
        showHUD ? "chart.bar.fill" : "chart.bar"
    }

    private var colorAndStyleImage: String {
        modifyColorAndStyle ? "paintpalette.fill" : "paintpalette"
    }

    var transformationControlView: some View {
        VStack {
            transformResetButton
            HStack {
                Text("Rotation: \(String(format: "%.0f", configuratorViewModel.rotationAngle))°")
                    .foregroundColor(.blue)
                    .padding()
                    .frame(width: Self.sliderTextWidth, alignment: .center)
                    .font(.title3)
                Slider(value: Binding(
                    get: {configuratorViewModel.rotationAngle},
                    set: {configuratorViewModel.rotationAngle = $0}
                ), in: -180...180)
                    .padding()
                    .onChange(of: configuratorViewModel.rotationAngle) {
                        configuratorAppModel.gestureHelper?.rotateRemoteWorldOriginWithSlider()
                    }
            }
            HStack {
                Text("Scale: \(String(format: "%.1f",configuratorViewModel.objectScale))")
                    .foregroundColor(.blue)
                    .padding()
                    .frame(width: Self.sliderTextWidth, alignment: .center)
                    .font(.title3)
                Slider(value: Binding(
                    get: {configuratorViewModel.objectScale},
                    set: {configuratorViewModel.objectScale = $0}
                ), in: 0.2...5.0)
                    .padding()
                    .onChange(of: configuratorViewModel.objectScale) {
                        configuratorAppModel.gestureHelper?.scaleRemoteWorldOriginWithSlider()
                    }
            }
            HStack {
                Text("X position: \(String(format: "%.1f", configuratorViewModel.userTranslationX))m")
                    .foregroundColor(.blue)
                    .padding()
                    .frame(width: Self.sliderTextWidth, alignment: .center)
                    .font(.title3)
                Slider(value: Binding(
                    get: {configuratorViewModel.userTranslationX},
                    set: {configuratorViewModel.userTranslationX = $0}
                ), in: -Self.sliderRange...Self.sliderRange)
                    .padding()
                    .onChange(of: configuratorViewModel.userTranslationX) {
                        configuratorAppModel.gestureHelper?.translateRemoteWorldOrigin(To: configuratorViewModel.translationFromUser)
                    }
            }

            HStack {
                Text("Y position: \(String(format: "%.1f", configuratorViewModel.userTranslationY))m")
                    .foregroundColor(.blue)
                    .padding()
                    .frame(width: Self.sliderTextWidth, alignment: .center)
                    .font(.title3)
                Slider(value: Binding(
                    get: {configuratorViewModel.userTranslationY},
                    set: {configuratorViewModel.userTranslationY = $0}
                ), in: -Self.sliderRange...Self.sliderRange)
                    .padding()
                    .onChange(of: configuratorViewModel.userTranslationY) {
                        configuratorAppModel.gestureHelper?.translateRemoteWorldOrigin(To: configuratorViewModel.translationFromUser)
                    }
            }

            HStack {
                Text("Z position: \(String(format: "%.1f", configuratorViewModel.userTranslationZ))m")
                    .foregroundColor(.blue)
                    .padding()
                    .frame(width: Self.sliderTextWidth, alignment: .center)
                    .font(.title3)
                Slider(value: Binding(
                    get: {configuratorViewModel.userTranslationZ},
                    set: {configuratorViewModel.userTranslationZ = $0}
                ), in: -Self.sliderRange...Self.sliderRange)
                .padding()
                .onChange(of: configuratorViewModel.userTranslationZ) {
                    configuratorAppModel.gestureHelper?.translateRemoteWorldOrigin(To: configuratorViewModel.translationFromUser)
                }
            }
        }
    }

    internal var modeButton: some View {
        customButton(
            image: modeButtonImage,
            text: "Mode",
            action: {
                guard let viewing = configuratorAppModel.asset[viewingKey] as? ViewingModel else { return }
                configuratorAppModel.asset[viewingKey] = viewing.toggle()
            },
            isDisabled: placementManager.state != .placed
        )
    }

    internal var interactionButton: some View {
        customButton(
            image: interactionButtonImage,
            text: "Transform",
            action: {
                if selectedSection == .none {
                    selectedSection = .transform
                } else {
                    selectedSection = .none
                }
            },
            isDisabled: placementManager.state != .placed || (selectedSection != .none && selectedSection != .transform)
        )
    }

    internal var transformResetButton: some View {
        customButton(
            image: transformResetButtonImage,
            text: "Reset",
            action: {
                // Reset rotation.
                configuratorViewModel.rotationAngle = 0
                configuratorAppModel.gestureHelper?.rotateRemoteWorldOriginWithSlider()
                // Reset scale.
                configuratorViewModel.objectScale = 1.0
                configuratorAppModel.gestureHelper?.scaleRemoteWorldOriginWithSlider()
                // Reset position.
                configuratorViewModel.userTranslationX = Double(configuratorViewModel.initPlacementLocation.x)
                configuratorViewModel.userTranslationY = Double(configuratorViewModel.initPlacementLocation.y)
                configuratorViewModel.userTranslationZ = Double(configuratorViewModel.initPlacementLocation.z)
                configuratorAppModel.gestureHelper?.translateRemoteWorldOrigin(To: configuratorViewModel.initPlacementLocation)
            },
            isDisabled: false
        )
    }

    internal var configButton: some View {
        customButton(
            image: configButtonImage,
            text: "Settings",
            action: {
                if selectedSection == .none {
                    selectedSection = .launch
                } else {
                    selectedSection = .none
                }
            },
            isDisabled: selectedSection != .none && selectedSection != .launch
        )
    }

    internal var hudButton: some View {
        customButton(
            image: hudImage,
            text: "Statistics",
            action: {
                showHUD.toggle()
            }
        )
    }

    internal var hudView: some View {
        HStack{
            Spacer()
            VStack {
                if let session = appModel.session {
                    HUDView(session: session, hudConfig: HUDConfig())
                        .frame(minWidth: 200, minHeight: 200)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding(.top, 50)
                }
                Spacer()
            }
            .padding(.top, 20)
        }
        .padding(.trailing, 20)
    }

    internal var styleAndColorButton: some View {
        customButton(
            image: colorAndStyleImage,
            text: "Style/color",
            action: {
                // Ensure UI updates have been completed before modifying the state of modifyColorAndStyle.
                DispatchQueue.main.async {
                    modifyColorAndStyle.toggle()
                }
            },
            isDisabled: placementManager.state != .placed
        )
    }

    internal var placementButton: some View {
        customButton(
            image: placementButtonImage,
            text: "Placement",
            action: {
                DispatchQueue.main.async {
                    if placementManager.state == .started {
                        placementManager.cancel()
                    } else {
                        selectedSection = .none
                        modifyColorAndStyle = false
                        placementManager.start()
                    }
                }
            },
            isDisabled: isSimulator
        )
    }

    internal var styleAndColorView: some View {
        HStack {
            VStack {
                Text(getConfigureText())
                    .font(UIConstants.titleFont)
                    .foregroundColor(.black)
                    .padding(.top, 50)
                colorList
                styleList
                Spacer()
            }
            .frame(width: sidebarWidth) // Set sidebar width.
            .background(Color.gray) // Sidebar color.
            .cornerRadius(10)
            Spacer()
        }
    }

    private func getConfigureText() -> String {
        if configuratorAppModel.asset is PurseAsset {
            return "Configure Purse"
        }


        fatalError("Unknown asset type")
    }

    var colorList: some View {
        VStack(alignment: .leading) {
            Button {
                withAnimation {
                    isExpandedColor.toggle()
                }
            } label: {
                HStack {
                    Text(getColorText())
                        .font(UIConstants.sectionFont)
                        .foregroundColor(Color(UIColor.darkGray))

                    Spacer()
                    Image(systemName: isExpandedColor ? "chevron.down" : "chevron.right")
                        .foregroundColor(.blue)
                        .font(.title)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            if isExpandedColor {
                ScrollView(showsIndicators: false) {
                    HStack {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: UIConstants.assetWidth * 0.5))],
                            spacing: 0
                        ) {
                            ForEach (configuratorAppModel.asset.styleList) { style in
                                styleAsset(key: "color", item: style, size: UIConstants.assetWidth * 0.5)
                                    .padding(5)
                            }
                        }
                    }
                    .padding(0)
                }
                .frame(height: ConfiguratorUIConstants.maxTrimScrollHeight)
            }
        }
        .padding()
    }

    private func getColorText() -> String {
        if configuratorAppModel.asset is PurseAsset {
            return "Leather Color"
        }


        return "Color"
    }

    var styleList: some View {
        VStack(alignment: .leading) {
            Button {
                withAnimation {
                    isExpandedStyle.toggle()
                }
            } label: {
                HStack {
                    Text("Style")
                        .font(UIConstants.sectionFont)
                        .foregroundColor(Color(UIColor.darkGray))
                    Spacer()
                    Image(systemName: isExpandedStyle ? "chevron.down" : "chevron.right")
                        .foregroundColor(.blue)
                        .font(.title)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            if isExpandedStyle {
                ScrollView(showsIndicators: false) {
                    HStack {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: UIConstants.assetWidth * 0.5))], spacing: 0) {
                            ForEach(configuratorAppModel.asset.subStyleList) { substyle in
                                styleAsset(key: "style", item: substyle, size: UIConstants.assetWidth * 0.5)
                                    .padding(5)
                            }
                        }
                    }
                    .padding(0)
                }
                .frame(height: ConfiguratorUIConstants.maxTrimScrollHeight)
            }
        }
        .padding()
    }

    // Branched from ConfigureView.swift for iOS(ipad) specific layout.
    func styleAsset(key: String, item: any AssetStyle, size: CGFloat = UIConstants.assetWidth) -> some View {
        Button {
            configuratorAppModel.asset[key] = item
        } label: {
            HStack {
                // Item image.
                Image(String(item.rawValue))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(UIConstants.margin)
                    .frame(width: size * 1.0)
                // Item name.
                HStack {
                    Text(String(item.description))
                        .font(ConfiguratorUIConstants.itemFont)
                        .foregroundColor(.black)
                        .frame(width: size * 0.5, alignment: .leading)
                }
            }.frame(width: size * 1.5)
        }
        .buttonStyle(CustomButtonStyle())
    }
}
