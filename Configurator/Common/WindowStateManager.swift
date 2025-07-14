// SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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
import os.log

#if os(visionOS)
// Manages the state and lifecycle of windows and immersive spaces in the application
class WindowStateManager {
    // Logger instance for debugging and error tracking
    private static let logger = Logger()

    // Current state of the main window visibility
    private var windowVisible = false

    // Current state of the immersive space
    private(set) var immersiveSpaceActive = false

    // Indicates if the manager has been configured with necessary actions
    private var configured = false

    // Reference to the appModel (weak to avoid retain cycle)
    private weak var appModel: AppModel!

    // Actions for managing windows and immersive spaces
    private var openImmersiveSpace: OpenImmersiveSpaceAction!
    private var dismissImmersiveSpace: DismissImmersiveSpaceAction!
    private var openWindow: OpenWindowAction!
    private var dismissWindow: DismissWindowAction!

    // When the immersive space is dismissed, we want to disconnect, but in the case of the IPD check, we do not.
    private var _pauseOnImmersiveSpaceDismissed = true
    private var lock = OSAllocatedUnfairLock()

    var pauseOnImmersiveSpaceDismissed: Bool {
        get { lock.withLock { _pauseOnImmersiveSpaceDismissed } }
        set { lock.withLock { _pauseOnImmersiveSpaceDismissed = newValue } }
    }

    // Configures the manager with necessary actions and session reference.
    // Should be called before all other functions.
    // - Parameters:
    //   - cxrSession: The CloudXR session
    //   - openImmersiveSpace: Action to open immersive space
    //   - dismissImmersiveSpace: Action to dismiss immersive space
    //   - openWindow: Action to open window
    //   - dismissWindow: Action to dismiss window
    func windowOnAppear(appModel: AppModel,
                        openImmersiveSpace: OpenImmersiveSpaceAction,
                        dismissImmersiveSpace: DismissImmersiveSpaceAction,
                        openWindow: OpenWindowAction,
                        dismissWindow: DismissWindowAction) {
        guard !windowVisible else {
            fatalError("windowOnAppear called while window already open")
        }

        if !configured {
            self.appModel = appModel
            self.openImmersiveSpace = openImmersiveSpace
            self.dismissImmersiveSpace = dismissImmersiveSpace
            self.openWindow = openWindow
            self.dismissWindow = dismissWindow

            configured = true
        }

        windowVisible = true
    }

    func windowOnDisappear() {
        guard windowVisible else {
            fatalError("windowOnDisappear called when window is already dismissed")
        }
        windowVisible = false
    }

    // For cases that window is closed but onDisappear() won't trigger
    func windowOnScenePhaseChange(scenePhase: ScenePhase) {
        guard configured else {
            fatalError("Window state manager not configured when scene phase changed")
        }
        if scenePhase == .inactive {
            if windowVisible {
                dismissWindow(id: launchTitle)
            }
        } else if scenePhase == .active {
            if appModel.session?.state == .paused {
                Task { @MainActor in
                    try appModel.session?.resume()
                    if !immersiveSpaceActive {
                        await openImmersiveSpace(id: immersiveTitle)
                    }
                }
            }
        }
    }

    func dismissImmersiveSpaceIfOpen() {
        if immersiveSpaceActive {
            Task { @MainActor in
                await dismissImmersiveSpace()
            }
        }
    }

    func onConnectionStateChanged(oldState: SessionState, newState: SessionState) async {
        switch newState {
        case .connected:
            await handleConnectionEstablished()
        case .disconnected:
            await handleDisconnection()
        default:
            return
        }
    }

    // Handles connection established event.
    // Behavior: Opens immersive space and optionally hides window based on settings.
    private func handleConnectionEstablished() async {
        guard configured else {
            fatalError("Connection established before window manager was configured")
        }

        if !immersiveSpaceActive {
            await openImmersiveSpace(id: immersiveTitle)
        }

        if await !ViewerApp.persistLaunchWindow {
            await dismissWindow(id: launchTitle)
        }
    }

    // Handles disconnection event
    // Behavior: Restores window visibility and dismisses immersive space
    private func handleDisconnection() async {
        guard configured else {
            fatalError("Disconnection before window manager was configured")
        }

        if windowVisible == false {
            await openWindow(id: launchTitle)
        }
        if immersiveSpaceActive == true {
            await dismissImmersiveSpace()
        }
    }

    func immersiveSpaceOnAppear() {
        guard !immersiveSpaceActive else {
            fatalError("Immersive space was already active when onAppear was called")
        }

        immersiveSpaceActive = true
    }

    // Handles immersive space dismissal (especially triggered by crown press)
    // Behavior: Restores window visibility and pauses session if active
    func immersiveSpaceOnDisappear() {
        guard immersiveSpaceActive else {
            fatalError("Immersive space state incorrect on disappear")
        }

        guard configured else {
            fatalError("Window manager not configured when immersive space disappeared")
        }

        immersiveSpaceActive = false

        // If the window was not visible, open the window.
        if windowVisible == false {
            openWindow(id: launchTitle)
        }

        // Pause the session if necessary
        switch appModel.session?.state {
        case .disconnecting, .disconnected, .initialized, .pausing, .paused:
            return
        default:
            if pauseOnImmersiveSpaceDismissed {
                appModel.session?.pause()
                // If headset is removed, dismiss immersive space rather than leaving it in background.
                Task { @MainActor in
                    if immersiveSpaceActive {
                        await dismissImmersiveSpace()
                    }
                }
            }
        }
    }

    // Toggles the visibility of the main window
    func toggleWindow() {
        guard configured else {
            fatalError("Window manager is not configured when toggling the window")
        }

        if windowVisible {
            dismissWindow(id: launchTitle)
        } else {
            openWindow(id: launchTitle)
        }
    }
}
#endif
