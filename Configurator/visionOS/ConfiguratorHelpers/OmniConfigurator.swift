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
import RealityKit

struct OmniConfigurator: View {
    @AppStorage("showDebug") var showDebugUI = true

    enum Section {
        case configure
        case environment
        case hud
        case launch
        
        var title: String {
            switch self {
            case .configure:
                "Configure"
            case .environment:
                "Environment"
            case .hud:
                "HUD"
            case .launch:
                "Config Screen"
            }
        }
    }

    @Environment(AppModel.self) var appModel
    @Environment(ConfiguratorViewModel.self) var configuratorViewModel
    @Environment(ConfiguratorAppModel.self) var configuratorAppModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    /// current section being displayed
    @State var section = Section.configure
    /// is the list of cameras being displayed
    @State var showCameras = false
    @State var showDebugPopup = false

    @Binding var application: Application

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
#endif

        VStack {
            titleBar
                .padding(.all)

            // decide which panel to show in this window
            switch section {
            case .configure:
                ConfigureView()
            case .environment:
                EnvironmentView()
            case .hud:
                if let session = configuratorAppModel.session {
                    ScrollView {
                        HUDView(session: session, hudConfig: HUDConfig())
                    }
                }
            case .launch:
                SessionConfigView(application: $application) {}
            }
        }
        .ornament(visibility: .visible, attachmentAnchor: .scene(.init(x: 0.5, y: 0.92))) {
            // view selection "tabs" along the bottom of the window
            HStack {
                Button("Configure") { section = .configure }
                    .selectedStyle(isSelected: section == .configure)
                Button("Environment") { section = .environment }
                    .selectedStyle(isSelected: section == .environment)
                Button {
                    showDebugPopup = true
                } label: {
                    Image(systemName: "ellipsis")
                }
                .popover(isPresented: $showDebugPopup) {
                    Form {
                        if showDebugUI {
                            Button("HUD") {
                                section = .hud
                                showDebugPopup = false
                            }
                            .selectedStyle(isSelected: section == .hud)
                        }
                        Button("Config Screen") {
                            section = .launch
                            showDebugPopup = false
                        }
                        .selectedStyle(isSelected: section == .launch)
                    }
                    .formStyle(.grouped)
                    .padding(.vertical)
                    .frame(width: 300, height: showDebugUI ? 150 : 95)
                }
            }
            .ornamentStyle
        }
        // align all the useful information to the top of the window
        Spacer()
    }
    
    /// The titlebar at the top of the panel showing the panel name and controls at left and right
    var titleBar: some View {
        HStack {
            // Portal / Tabletop selector
            Button {
                guard let viewing = configuratorAppModel.asset[viewingKey] as? ViewingModel else { return }
                configuratorAppModel.asset[viewingKey] = viewing.toggle()
            } label: {
                if configuratorViewModel.viewIsLoading {
                    ProgressView()
                } else {
                    Image(systemName: portalSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: ConfiguratorUIConstants.topCornerButtonSize,
                        height: ConfiguratorUIConstants.topCornerButtonSize
                    )
                    .padding(.vertical, UIConstants.margin)
                    .help(portalHelp)
                }
            }
            .disabled(configuratorViewModel.isPlacing)

            Spacer()

            VStack{
                // Title
                Text(section.title)
                    .font(UIConstants.titleFont)

                Button(appModel.ratingText) {
                    appModel.isRatingViewPresented = true
                }
                .disabled(appModel.disableFeedback)
                .sheet(isPresented: Binding(get: { appModel.isRatingViewPresented }, set: { _ in } )) {
                    StarRatingView()
                }
            }

            Spacer()

            // Camera popover
            Button {
                showCameras.toggle()
            } label: {
                VStack {
                    cameraImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: ConfiguratorUIConstants.topCornerButtonSize,
                            height: ConfiguratorUIConstants.topCornerButtonSize
                        )
                        .padding(.vertical, UIConstants.margin)
                        .help(cameraHelp)
                }
            }
            // we need both of the below since we want the invisible menu to be disabled as well
            .opacity(configuratorViewModel.currentViewing.mode == .tabletop ? 0 : 1)
            .disabled(configuratorViewModel.currentViewing.mode == .tabletop)
            // popover sheet presented when the camera icon is tapped
            .popover(isPresented: $showCameras) {
                CameraSheet()
                    .frame(
                        width: ConfiguratorUIConstants.cameraSheetSize.width,
                        height: ConfiguratorUIConstants.cameraSheetSize.height
                    )
                    .padding()
            }
        }
    }

    /// symbol used for portal depending on mode
    var portalSymbol: String {
        switch configuratorViewModel.currentViewing.mode {
        case .portal:
            "cube.fill"
        case .tabletop:
            configuratorViewModel.isPlacing ? "arrow.down" : "cube"
        }
    }

    var portalHelp: String {
        switch configuratorViewModel.currentViewing.mode {
        case .portal:
            "Toggle AR View"
        case .tabletop:
            configuratorViewModel.isPlacing ? "Placing model" : "Toggle Portal View"
        }
    }

    /// Help text for each mode
    var cameraHelp: String {
        switch configuratorViewModel.currentViewing.mode {
        case .portal:
            "Change Portal View"
        case .tabletop:
            "Only available in portal"
        }
    }

    /// camera/seat symbol used in camera menu
    var cameraImage: Image {
        Image(systemName: showCameras ? "video" : "video.fill")
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

    return OmniConfigurator(application: $appModel.application)
        .environment(appModel)
        .environment(configuratorViewModel)
        .environment(configuratorAppModel)
}
