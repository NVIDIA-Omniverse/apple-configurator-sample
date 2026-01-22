// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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
import Network

extension SessionConfigView {
    var body: some View {
        mainView
        .ornament(
            visibility: useSimpleConfigView ? .visible : .hidden,
            attachmentAnchor: .scene(.init(x: 0.98, y: -0.02)),
            contentAlignment: .bottomTrailing
        ) {
            Button {
                useSimpleConfigView.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .padding(12)
            }
        }
    }

    @ViewBuilder
    var sessionConfigForm: some View {
        Form {
            Section {
                Picker("Select Zone", selection: $zone) {
                    ForEach (Zone.allCases, id: \.self) { Text($0.rawValue) }
                }
                .onChange(of: zone) {
                    if zone == .ipAddress {
                        // Dummy call to trigger request local network permissions early
                        NetServiceBrowser().searchForServices(ofType: "_http._tcp.", inDomain: "local.")
                    }
                }

                if zone == .ipAddress {
                    HStack {
                        Text("IP Address")
                        Spacer()
                        TextField("0.0.0.0", text: $hostAddress)
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                            .searchDictationBehavior(.inline(activation: .onLook))
                            .onSubmit {
                                // strip whitespace
                                hostAddress = hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                    }
                } else {
                    HStack {
                        Picker("Select Authentication Method", selection: $authMethod) {
                            ForEach (AuthMethod.allCases, id: \.self) { authOption in
                                Text(authOption.rawValue)
                            }
                        }
                    }
                }

                HStack {
                    Picker("Select Application", selection: $application) {
                        ForEach (Application.allCases, id: \.self) { appOption in
                            Text(appOption.rawValue)
                        }
                    }
                    .disabled(sessionConnected)
                }


                if zone != .ipAddress && application.appID == .unknown {
                    HStack {
                        Text("Enter Application ID")
                        Spacer()
                        TextField("", value: $genericAppID, format: .number.grouping(.never))
                            .disableAutocorrection(true)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Picker("Resolution Preset", selection: $resolutionPreset) {
                        ForEach(ResolutionPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue)
                        }
                    }.disabled(sessionConnected)
                }
            }
        }
        .frame(minHeight: 420, maxHeight: 790)
    }
}