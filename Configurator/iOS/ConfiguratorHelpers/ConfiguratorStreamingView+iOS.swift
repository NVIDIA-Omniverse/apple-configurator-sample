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
import RealityKit
import CloudXRKit
import ARKit
import Foundation

struct ConfiguratorStreamingView : View {
    enum Section {
        case none
        case launch
        case transform
    }

#if targetEnvironment(simulator)
    let isSimulator = true
#else
    let isSimulator = false
#endif

    @Environment(ConfiguratorAppModel.self) var configuratorAppModel
    @Environment(ConfiguratorViewModel.self) var configuratorViewModel
    @Environment(AppModel.self) var appModel

    @Environment(\.colorScheme) var colorScheme

    @State private var sessionEntity = Entity()
    @State var showHUD = false
    @State var modifyColorAndStyle = false
    let sidebarWidth: CGFloat = 300
    @State var isExpandedColor = false
    @State var isExpandedStyle = false

    @State var selectedSection: Section = .none
    
    @State var placementManager = PlacementManager()

    @Binding var application: Application

    private var transformViewIsOff: Bool {
        selectedSection != .transform
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RealityView { content in
                sessionEntity.name = "Session"
                // The camera that displays virtual RealityKit content and camera passthrough, with tracking capabilities.
                content.camera = .spatialTracking
                if let session = configuratorAppModel.session {
                    sessionEntity.components[CloudXRSessionComponent.self] = .init(session: session)
                }
                configuratorViewModel.sessionEntity = sessionEntity

                // Set the inital purse location.
                configuratorAppModel.gestureHelper?.translateRemoteWorldOrigin(To: configuratorViewModel.translationFromUser)

                content.add(sessionEntity)

#if !targetEnvironment(simulator)
                placementManager.setup(sessionEntity: sessionEntity, content: content)
                placementManager.start()
#endif
                _ = content.subscribe(to:SceneEvents.Update.self,on: nil, componentType: nil) { frameData in
                    if configuratorViewModel.viewIsLoading != configuratorAppModel.isAwaitingCompletion(viewingKey) {
                        configuratorViewModel.viewIsLoading = configuratorAppModel.isAwaitingCompletion(viewingKey)
                    }

                    let purseVisibility = (configuratorAppModel.asset["purseVisibility"] as? PurseVisibility == PurseVisibility.visible)
                    if configuratorViewModel.purseVisible != purseVisibility {
                        configuratorViewModel.purseVisible = purseVisibility
                    }

                    if let currentViewing = configuratorAppModel.asset[viewingKey] as? ViewingModel,
                       currentViewing != configuratorViewModel.currentViewing {
                         configuratorViewModel.currentViewing = currentViewing
                    }
                }
            }.onChange(of: placementManager.state) { _, newState in
                if newState == .placed {
                    configuratorViewModel.userTranslationX = Double(sessionEntity.position.x)
                    configuratorViewModel.userTranslationY = Double(sessionEntity.position.y)
                    configuratorViewModel.userTranslationZ = Double(sessionEntity.position.z)
                    sessionEntity.setOpacity(1.0, from: sessionEntity.opacity, animated: true, duration: 0.5)

                    // Record the init placement location for future reset.
                    configuratorViewModel.initPlacementLocation = configuratorViewModel.translationFromUser
                } else {
                    sessionEntity.setOpacity(0.0, from: sessionEntity.opacity, animated: true, duration: 0.5)
                }
            }
            .onChange(of: configuratorAppModel.session?.state) { oldState, newState in
                // Show the streaming view by default when connected.
                // We need to reset this to none when user re-connect or disconnected.
                selectedSection = .none
                if newState == .connected {
                    configuratorAppModel.asset.stateManager.startPolling()
                    configuratorAppModel.asset.resync()
                } else {
                    configuratorAppModel.asset.stateManager.stopPolling()
                }
            }
            .edgesIgnoringSafeArea(.all)
            .gesture(
                transformViewIsOff ? SimultaneousGesture(
                    configuratorAppModel.gestureHelper?.rotationGesture,
                    configuratorAppModel.gestureHelper?.magnifyGesture
                ) : nil
            )
            .gesture(
                transformViewIsOff ? placementManager.placementGesture : nil
            )

            if showHUD {
                hudView
            }

            if modifyColorAndStyle {
                styleAndColorView
            }

            switch selectedSection {
            case .transform:
                transformationControlView
                    .padding(.bottom, 250)
                    .frame(width: 800, height: 400)
            case .launch:
                SessionConfigView(application: $application) {}
            case .none:
                EmptyView()
            }
            
            // Show the overylay UI only when connected.
            if configuratorAppModel.session?.state == .connected {
                VStack {
                    Spacer()
                    // Button to enable modify color and style.
                    HStack {
                        styleAndColorButton
                            .padding(.leading, modifyColorAndStyle ? sidebarWidth : 0)
                        Spacer()
                        placementButton
                    }
                    // Button to enable/disable HUD.
                    HStack {
                        modeButton
                            .padding(.leading, modifyColorAndStyle ? sidebarWidth : 0)
                        Spacer()
                        if placementManager.state == .started {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 340, height: 60)
                                Text("Tap on the floor to place the object").font(.body)
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                        hudButton
                    }
                    HStack {
                        interactionButton
                            .padding(.leading, modifyColorAndStyle ? sidebarWidth : 0)
                        Spacer()
                        configButton
                    }
                }
                .padding([.leading, .trailing, .bottom], 16)
            } else {
                // Show black/white background instead of passthrough when not connected.
                (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()
                // Show the SessionConfigView for user to reconnect.
                SessionConfigView(application: $application) {}
            }
        }
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

    return ConfiguratorStreamingView(application: $appModel.application)
        .environment(appModel)
        .environment(configuratorViewModel)
        .environment(configuratorAppModel)
}
