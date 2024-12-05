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
import UIKit
import CloudXRKit

struct EnvironmentView: View {
    @Binding var section: ViewSelector.Section
    @State var userText = ""
    @Environment(AppModel.self) var appModel
    @Environment(ViewModel.self) var viewModel
    @State var lightingUnvailable = false

    var body: some View {
        VStack {
            ScrollView(showsIndicators: false) {
                
                switch viewModel.currentViewingMode {
                case .portal:
                    places

                    space

                    portalLighting
                case .tabletop:
                    EnvironmentTabletop(section: $section)
                }
            }
            .padding(.all)
        }
    }

    func isConnected() -> Bool{
        if appModel.session.state == .connected {
            return true
        } else {
            return false
        }
    }

    var places: some View {
        VStack {
            HStack {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: UIConstants.assetWidth))]) {
                    ForEach(OmniverseEnvironment.allCases, id: \.rawValue) { env in
                        if !env.isHidden {
                            place(env)
                        }
                    }
                }
            }
        }
    }

    var portalLighting: some View {
        // make viewModel bindable
        @Bindable var viewModel = viewModel
        // have to actually return the VStack since above line is not a view
        return VStack {
            header("Lighting")
            smallSpace
            HStack {
                Image(systemName: "sun.min")
                Spacer()
                Image(systemName: "sun.max")
            }
            smallSpace
            Slider(value: $viewModel.lightIntensity, in: 0.0...2.0) { isEditing in
                // Wait for user to finish dragging
                if !isEditing {
                    appModel.stateManager["lightSlider"] = LightSlider(viewModel.lightIntensity)
                }
            }
            .disabled(lightingUnvailable)
        }
    }

    var space: some View {
        Spacer()
            .frame(width: UIConstants.margin, height: UIConstants.margin*2)
    }

    var smallSpace: some View {
        Spacer()
            .frame(width: UIConstants.margin, height: UIConstants.margin)
    }

    func header(_ str: String) -> some View {
        HStack {
            Text(str)
                .font(UIConstants.sectionFont)
            Spacer()
        }
    }

    func place(_ env: OmniverseEnvironment) -> some View {
        Button {
            appModel.stateManager["environment"] = env
            lightingUnvailable = !env.supportsLighting
        } label: {
            VStack {
                // Environment image - maybe fall back to something if image is not found?
                Image(String(env.rawValue))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .font(.system(size: 128, weight: .medium))
                    .cornerRadius(UIConstants.margin)
                    .frame(width: UIConstants.assetWidth)
                    .contrast(env.isDisabled ? 0.5 : 1)
                // Environment name
                HStack {
                    Spacer()
                    Text(String(env.description))
                        .font(UIConstants.itemFont)
                        .disabled(env.isDisabled)
                        .foregroundStyle(env.isDisabled ? Color(white: 1.0, opacity: 0.5) : .white)
                    Spacer()
                }
            }
            .frame(width: UIConstants.assetWidth)
            .onSubmit {
                hideKeyboard()
            }
        }
        .disabled(env.isDisabled)
        .buttonStyle(CustomButtonStyle(isDisabled: env.isDisabled))
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    @Previewable @State var session = CloudXRSession(config: Config())
    @Previewable @State var viewModel = ViewModel()
    return VStack {
        ViewSelector(section: .environment)
    }
    .environment(session)
    .environment(viewModel)
    .ornamentStyle
}
