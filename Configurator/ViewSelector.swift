// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import AVFAudio
import SwiftUI
import CloudXRKit
import RealityKit

struct ViewSelector: View {
    // TODO: If any state is needed here later, plumb it for real
    var dummyUiState = LaunchView.UIState()
    @AppStorage("showDebug") var showDebugUI = true

    enum Section {
        case configure
        case environment
        case hud
        case launch
        
        var title: String {
            switch self {
            case .configure:
                "Configure Purse"
            case .environment:
                "Environment"
            case .hud:
                "HUD"
            case .launch:
                "Config Screen"
            }
        }
    }

    @Environment(ViewModel.self) var viewModel
    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    /// current section being displayed
    @State var section = Section.configure
    /// is the list of cameras being displayed
    @State var showCameras = false
    @State var showDebugPopup = false

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
#endif

        VStack {
            titleBar
                .padding(.all)

            Spacer()
                .frame(width: 1, height: UIConstants.margin)

            // decide which panel to show in this window
            switch section {
            case .configure:
                ConfigureView(section: $section)
            case .environment:
                EnvironmentView(section: $section)
            case .hud:
                HUDView(session: appModel.session, hudConfig: HUDConfig())
            case .launch:
                SessionConfigView(uiState: dummyUiState) {
                    viewModel.anyImmersiveSpaceRunning = true
                    Task {
                        await openImmersiveSpace(id: immersiveTitle)
                    }
                }
            }
        }
        .ornament(visibility: .visible, attachmentAnchor: .scene(.init(x: 0.5, y: 0.92))) {
            // view selection "tabs" along the bottom of the window
            HStack {
                Button("Configure Purse") { section = .configure }
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
                    .frame(width: 240, height: showDebugUI ? 150 : 95)
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
                guard let viewingMode = appModel.stateManager["viewingMode"] as? ViewingMode else { return }
                appModel.stateManager["viewingMode"] = viewingMode.toggle()
            } label: {
                if viewModel.viewIsLoading {
                    ProgressView()
                } else {
                    Image(systemName: portalSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: UIConstants.topCornerButtonSize,
                        height: UIConstants.topCornerButtonSize
                    )
                    .padding(.vertical, UIConstants.margin)
                    .help(portalHelp)
                }
            }
            .disabled(viewModel.isPlacing)

            Spacer()

            VStack{
                // Title
                Text(section.title)
                    .font(UIConstants.titleFont)

                Button(viewModel.ratingText) {
                    viewModel.isRatingViewPresented = true
                }
                .disabled(viewModel.disableFeedback)
                .sheet(isPresented: Binding(get: { viewModel.isRatingViewPresented }, set: { _ in } )) {
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
                            width: UIConstants.topCornerButtonSize,
                            height: UIConstants.topCornerButtonSize
                        )
                        .padding(.vertical, UIConstants.margin)
                        .help(cameraHelp)
                }
            }
            // we need both of the below since we want the invisible menu to be disabled as well
            .opacity(viewModel.currentViewingMode == .tabletop ? 0 : 1)
            .disabled(viewModel.currentViewingMode == .tabletop)
            // popover sheet presented when the camera icon is tapped
            .popover(isPresented: $showCameras) {
                CameraSheet()
                    .frame(
                        width: UIConstants.cameraSheetSize.width,
                        height: UIConstants.cameraSheetSize.height
                    )
                    .padding()
            }
        }
    }

    /// symbol used for portal depending on mode
    var portalSymbol: String {
        switch viewModel.currentViewingMode {
        case .portal:
            "cube.fill"
        case .tabletop:
            viewModel.isPlacing ? "arrow.down" : "cube"
        }
    }

    var portalHelp: String {
        switch viewModel.currentViewingMode {
        case .portal:
            "Toggle AR View"
        case .tabletop:
            viewModel.isPlacing ? "Placing model" : "Toggle Portal View"
        }
    }

    /// Help text for each mode
    var cameraHelp: String {
        switch viewModel.currentViewingMode {
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
    @Previewable @State var session = CloudXRSession(config: Config())
    return ViewSelector(section: .configure)
        .environment(session)
}
