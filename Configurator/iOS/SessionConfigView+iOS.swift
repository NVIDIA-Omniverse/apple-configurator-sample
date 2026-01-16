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
    }

    @ViewBuilder
    var sessionConfigForm: some View {
        Form {
            Section {
                VStack {
                    Picker("Select Zone", selection: $zone) {
                        ForEach (Zone.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .frame(width: 500)
                    .onChange(of: zone) {
                        if zone == .ipAddress {
                            // Dummy call to trigger request local network permissions early
                            NetServiceBrowser().searchForServices(ofType: "_http._tcp.", inDomain: "local.")
                        }
                    }

                    if zone == .ipAddress {
                        HStack {
                            Text("IP Address")
                                // TODO(chaoyehc): Investigate why removing the padding
                                // causes slight misalignment in the text.
                                .padding(.vertical, 7)
                                .frame(alignment: .leading)
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
                        .frame(width: 500)
                    } else {
                        HStack {
                            Picker("Select Authentication Method", selection: $authMethod) {
                                ForEach (AuthMethod.allCases, id: \.self) { authOption in
                                    Text(authOption.rawValue)
                                }
                            }
                            .frame(width: 500)
                        }
                    }

                    HStack {
                        Text("Resolution Preset")
                            .frame(alignment: .leading)
                        Spacer()
                        Picker("", selection: $resolutionPreset) {
                            ForEach(ResolutionPreset.allCases, id: \.self) { preset in
                                Text(preset.rawValue)
                            }
                        }
                        .disabled(sessionConnected)
                    }
                    .frame(width: 500)

                    HStack {
                        Picker("Select Application", selection: $application) {
                            ForEach (Application.allCases, id: \.self) { appOption in
                                Text(appOption.rawValue)
                            }
                        }
                        .disabled(sessionConnected)
                        .frame(width: 500)
                    }

                    if zone != .ipAddress && application.appID == .unknown {
                        HStack {
                            Text("Enter Application ID")
                                .frame(alignment: .leading)
                            Spacer()
                            TextField("", value: $genericAppID, format: .number.grouping(.never))
                                .disableAutocorrection(true)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(width: 500)
                    }
                }
            }
        }
        .padding(.top, 100)
        .frame(minWidth: 600, maxWidth: 600, minHeight: 360, maxHeight: 690)
    }
}
