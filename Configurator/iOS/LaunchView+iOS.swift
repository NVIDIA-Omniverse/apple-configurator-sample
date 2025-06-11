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
    @Environment(AppModel.self) var appModel
    @Environment(\.colorScheme) var colorScheme
    
    // Configurator-specific environment objects.
    @Environment(ConfiguratorAppModel.self) var configuratorAppModel
    @Environment(ConfiguratorViewModel.self) var configuratorViewModel

    @Binding var application: Application

    var body: some View {
        if application.isConfigurator {
            if appModel.showStreamingAppView {
                ConfiguratorStreamingView(application: $application)
                .ignoresSafeArea()
            } else {
                // Show the configuration view
                VStack {
                    Spacer(minLength: 24)
                    SessionConfigView(application: $application) {
                        // Setup configurator app model and transition to streaming view
                        if let session = appModel.session {
                            configuratorAppModel.setup(application: application, configuratorViewModel: configuratorViewModel, session: session)
                        }
                    }
                    Spacer(minLength: 24)
                }
                .background(colorScheme == .dark ? Color.black : Color.white)
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
    configuratorAppModel.setup(application: appModel.application, configuratorViewModel: configuratorViewModel, session: appModel.session!)

    return LaunchView(application: $appModel.application)
        .environment(appModel)
        .environment(configuratorAppModel)
        .environment(configuratorViewModel)
}
