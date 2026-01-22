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

struct LaunchView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) var scenePhase
    @Environment(AppModel.self) var appModel

    // Configurator-specific environment objects.
    @Environment(ConfiguratorAppModel.self) var configuratorAppModel
    @Environment(ConfiguratorViewModel.self) var configuratorViewModel

    @Binding var application: Application

    func showImmersiveSpace() {
        Task {
            await openImmersiveSpace(id: immersiveTitle)
            if !ViewerApp.persistLaunchWindow {
                dismissWindow(id: launchTitle)
            }
        }
    }

    var body: some View {
        if application.isConfigurator {
            VStack {
                Spacer(minLength: 24)
                SessionConfigView(application: $application) {
                    ViewingModeSystem.registerSystem()
                    guard let session = appModel.session else {
                        fatalError("No session available in the connection completion handler.")
                    }
                    configuratorAppModel.setup(application: application, configuratorViewModel: configuratorViewModel, session: session)

                    showImmersiveSpace()
                }
                .onChange(of: scenePhase) {
                    appModel.windowStateManager.windowOnScenePhaseChange(scenePhase: scenePhase)
                }
                Spacer(minLength: 24)
            }
            .glassBackgroundEffect()
        }

    }
}

#Preview {
    @Previewable @State var appModel = AppModel()
    @Previewable @State var configuratorViewModel = ConfiguratorViewModel()
    @Previewable @State var configuratorAppModel = ConfiguratorAppModel()

    return LaunchView(application: $appModel.application)
        .environment(appModel)
        .environment(configuratorViewModel)
        .environment(configuratorAppModel)
}

