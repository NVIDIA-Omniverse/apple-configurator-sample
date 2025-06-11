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
import simd

#if os(visionOS)
// For measuring render camera positions.
import CompositorServices
#endif

let launchTitle = "launch"
let immersiveTitle = "immersive"

@main
struct ViewerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.openWindow) private var openWindow

    @State private var appModel = AppModel()
    @State var showDisconnectionErrorAlert = false

#if os(visionOS)
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @AppStorage("persistLaunchWindow") static var persistLaunchWindow = true
#endif

    // Configurator-specific state
    @State private var configuratorAppModel = ConfiguratorAppModel()
    @State private var configuratorViewModel = ConfiguratorViewModel()

    // Window sizes
    static let launchSize = CGSize(width: 680, height: 900)

    init() {
        CloudXRKit.registerSystems()

#if os(visionOS)
        // For tests.
        TestHelper.appModel = appModel

        TestHelper.configuratorAppModel = configuratorAppModel
        TestHelper.configuratorViewModel = configuratorViewModel

#endif
    }

#if os(visionOS)
    var body: some Scene {
        FetchHmdPropertiesImmersiveSpace(hmdProperties: appModel.hmdProperties)

        WindowGroup(id: launchTitle) {
            LaunchView(application: $appModel.application)
                .environment(appModel)
                .environment(configuratorAppModel) // Configurator-specific.
                .environment(configuratorViewModel) // Configurator-specific.
                .frame(
                    // Fixed-size window
                    minWidth: Self.launchSize.width,
                    maxWidth: Self.launchSize.width,
                    minHeight: Self.launchSize.height,
                    maxHeight: Self.launchSize.height
                )
                .alert(isPresented: $showDisconnectionErrorAlert) {
                    makeDisconnectionAlert()
                }
                .onAppear {
                    appDelegate.session = appModel.session
                    if #available(visionOS 2.4, *) {
                        // Skip the IPD check as the tracking system will do so
                    } else {
                        appModel.hmdProperties.beginIpdCheck(openImmersiveSpace: openImmersiveSpace, forceRefresh: false)
                    }
                }
        }
        .defaultSize(Self.launchSize)
        .windowResizability(.contentSize)

        ImmersiveSpace(id: immersiveTitle) {
            // Configurator-specific.
            if appModel.application.isConfigurator {
                ConfiguratorImmersiveView()
                    .environment(configuratorAppModel)
                    .environment(configuratorViewModel)
                    .onDisappear {
                        appModel.anyImmersiveSpaceRunning = false
                        switch appModel.session?.state {
                        case .connecting, .connected:
                            appModel.session?.pause()
                        default:
                            return
                        }
                    }
                    .onAppear {
                        appModel.anyImmersiveSpaceRunning = true
                    }
            }

        }
        .environment(appModel)
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                appModel.anyImmersiveSpaceRunning = false
                switch appModel.session?.state {
                case .connecting, .connected:
                    appModel.session?.pause()
                default:
                    return
                }
            } else if scenePhase == .active {
                if appModel.session?.state == SessionState.paused {
                    Task {
                        await openImmersiveSpace(id: immersiveTitle)
                        try appModel.session?.resume()
                    }
                }
            }
        }
        .onChange(of: appModel.session?.state) { oldState, newState in
            guard let oldState, let newState else { return }
            if case SessionState.disconnected = oldState {
                return
            }
            if case SessionState.disconnected = newState {
                Task {
                    if !Self.persistLaunchWindow {
                        openWindow(id: launchTitle)
                    }
                    await dismissImmersiveSpace()
                    alertAndRetryIfError()
                }
            }
        }
    }
#elseif os(iOS)
    var body: some Scene {
        WindowGroup {
            LaunchView(application: $appModel.application)
                .onAppear {
                    appDelegate.session = appModel.session
                }
                .alert(isPresented: $showDisconnectionErrorAlert) {
                    makeDisconnectionAlert()
                }
                .environment(appModel)
                // Only required for configurator.
                .environment(configuratorAppModel)
                .environment(configuratorViewModel)
                .onChange(of: appModel.session?.state) { oldState, newState in
                    guard let oldState, let newState else { return }
                    if case SessionState.disconnected = oldState {
                        return
                    }
                    if case SessionState.disconnected = newState {
                        Task {
                            alertAndRetryIfError()
                        }
                    }
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .background {
                        switch appModel.session?.state {
                        case .connecting, .connected:
                            appModel.session?.pause()
                        default:
                            return
                        }
                    } else if scenePhase == .active {
                        if appModel.session?.state == SessionState.paused {
                            Task {
                                try appModel.session?.resume()
                            }
                        }
                    }
                }
        }
    }
#endif
    
    func alertAndRetryIfError() {
        if let state = appModel.session?.state,
           case SessionState.disconnected(error: Result.failure(_)) = state
        {
            showDisconnectionErrorAlert = true
        }

        // Client disconnection error handling for configurator
        if configuratorAppModel.asset.serverResponseTimedOut {
            showDisconnectionErrorAlert = true
        }
    }

    func makeDisconnectionAlert() -> Alert {
        var errorMessage = "Connection failed without returning an error"
        let debugTips = "Please validate the configuration and, if using a local server instead of GDN, verify that Omniverse is ready."
        
        // First check appModel session state
        switch appModel.session?.state {
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
                // Check configurator session state
                if configuratorAppModel.asset.serverResponseTimedOut {
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
