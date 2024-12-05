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
import CompositorServices
import simd

let launchTitle = "launch"
let immersiveTitle = "immersive"

@main
struct ViewerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.openWindow) private var openWindow

    @State private var appModel = AppModel()
    @State private var viewModel = ViewModel()
    @State private var hmdProperties = HmdProperties()
    @State var displayConfig = true
    @State var showDisconnectionErrorAlert = false
    @State var showPoorQualityAlert = false

    @AppStorage("persistLaunchWindow") static var persistLaunchWindow = true
    @AppStorage("disableRecordingToggle") var disableRecordingToggle: Bool = false

    // Window sizes
    static let launchSize = CGSize(width: 620, height: 900)

    init() {
        ViewingModeSystem.registerSystem()
        CloudXRKit.registerSystems()
    }

    var body: some Scene {
        FetchHmdPropertiesImmersiveSpace(hmdProperties: hmdProperties)

        WindowGroup(id: launchTitle) {
            LaunchView()
                .frame(
                    // Fixed-size window
                    minWidth: Self.launchSize.width,
                    maxWidth: Self.launchSize.width,
                    minHeight: Self.launchSize.height,
                    maxHeight: Self.launchSize.height
                )
                .environment(appModel)
                .environment(viewModel)
                .environment(hmdProperties)
                .alert(isPresented: $showDisconnectionErrorAlert) {
                    makeDisconnectionAlert()
                }
                .alert("Session Quality Alert", isPresented: $showPoorQualityAlert) {
                            Button("OK", role: .cancel) { }
                        } message: {
                        Text("The current session quality is poor. Please check your network.")
                }
                .onAppear {
                    appDelegate.session = appModel.session
                    // have to reset as we do not want to remember this from last session
                    disableRecordingToggle = false

                    hmdProperties.beginIpdCheck(openImmersiveSpace: openImmersiveSpace, forceRefresh: false)
                }
        }
        .defaultSize(Self.launchSize)
        .windowResizability(.contentSize)

        ImmersiveSpace(id: immersiveTitle) {
            ImmersiveView()
                .onChange(of: appModel.session.state) { oldState, newState in
                    if case SessionState.disconnected = oldState {
                        return
                    }
                    if case SessionState.disconnected = newState {
                        Task {
                            defer {
                                viewModel.anyImmersiveSpaceRunning = false
                            }
                            if !Self.persistLaunchWindow {
                                openWindow(id: launchTitle)
                            }
                            await dismissImmersiveSpace()
                            alertAndRetryIfError()
                        }
                    }
                }.onDisappear {
                    viewModel.anyImmersiveSpaceRunning = false
                    switch appModel.session.state {
                    case .connecting, .connected:
                        appModel.session.pause()
                    default:
                        return
                    }
                }
        }
        .environment(appModel)
        .environment(viewModel)
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                viewModel.anyImmersiveSpaceRunning = false
                switch appModel.session.state {
                case .connecting, .connected:
                    appModel.session.pause()
                default:
                    return
                }
            } else if scenePhase == .active {
                if appModel.session.state == SessionState.paused {
                    viewModel.anyImmersiveSpaceRunning = true
                    Task {
                        await openImmersiveSpace(id: immersiveTitle)
                        try appModel.session.resume()
                    }
                }
            }
        }
    }

    func alertAndRetryIfError() {
        if case SessionState.disconnected(error: Result.failure(_)) = appModel.session.state {
            showDisconnectionErrorAlert = true
        }
        // Client disconnection error handling.
        if appModel.stateManager.serverResponseTimedOut {
            showDisconnectionErrorAlert = true
        }
    }

    func makeDisconnectionAlert() -> Alert {
        var errorMessage = "Connection failed without returning an error"
        let debugTips = "Please validate the configuration and, if using a local server instead of GDN, verify that Omniverse is ready."
        switch appModel.session.state {
        case .disconnected(let result):
            switch(result) {
            case .failure(let error):
                let description = "Error description: \(error.localizedDescription)"
                switch error {
                case .pauseTimeout:
                    errorMessage = "The session was paused too long and timed out on the server. Please start a new session.\n\n\(description)"
                case .dns:
                    errorMessage = "Error resolving server name. Please verify device's network connection.\n\n\(description)"
                case .failedConnectionAttempt:
                    errorMessage = "Connection attempt unsuccessful.\n\n\(debugTips)\n\n\(description)"
                case .sessionTerminatedUnknownReason:
                    errorMessage = "Session terminated for an unspecified reason.\n\n\(debugTips)\n\n\(description)"
                case .invalidServerURL:
                    errorMessage = "The server URL is invalid, please validate it and try again.\n\n\(description)"
                default:
                    errorMessage = "Error type: \(error.kind)\n\n\(description)"
                }
            default:
                if appModel.stateManager.serverResponseTimedOut {
                    errorMessage = "Server did not respond after multiple attempts!"
                }
            }
        default:
            break
        }

        return Alert(
            title: Text("Error"),
            message: Text(errorMessage),
            dismissButton: Alert.Button.default(
                Text("OK")
            )
        )
    }

}
