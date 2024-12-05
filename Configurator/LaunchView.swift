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
    @Observable class UIState {
        // Using a Bool instead of an enum to pass its binding to a Toggle()
        var showViewSelector = false
    }

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(ViewModel.self) var viewModel
    @Environment(HmdProperties.self) var hmdProperties
    @State var uiState = UIState()

    func showImmersiveSpace() {
        viewModel.anyImmersiveSpaceRunning = true
        Task {
            await openImmersiveSpace(id: immersiveTitle)
            if !ViewerApp.persistLaunchWindow {
                dismissWindow(id: launchTitle)
            }
        }
    }

    var body: some View {
        if uiState.showViewSelector {
            ViewSelector()
        } else {
            VStack {
                Spacer(minLength: 24)
                SessionConfigView(uiState: uiState) { showImmersiveSpace() }
                Spacer(minLength: 24)
            }
            .glassBackgroundEffect()
        }
    }
}

#Preview {
    LaunchView()
}
