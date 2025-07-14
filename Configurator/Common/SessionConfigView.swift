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
import OSLog

struct SessionConfigView: View {
    @AppStorage("hostAddress") private var hostAddress: String = ""
    @AppStorage("zone") private(set) var zone: Zone = .us_west
    @AppStorage("autoReconnect") private var autoReconnect: Bool = false
    @AppStorage("authMethod") private(set) var authMethod: AuthMethod = .starfleet
    @AppStorage("resolutionPreset") private var resolutionPreset: ResolutionPreset = .standardPreset


    @AppStorage("genericAppID") var genericAppID: Int = 0

    @Environment(AppModel.self) var appModel
    @Environment(\.colorScheme) var colorScheme

#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    // TODO(tifchen): Revisit whether this can be included for iOS.
#endif


    @State var awsalb = ""
    @State var sessionId = ""
    @State private var showIpdMeasurementPopOver = false

    @Binding var application: Application

    private var sessionConnected: Bool {
        if let session = appModel.session {
            switch session.state {
            case .initialized, .disconnected, .paused:
                false
            default:
                true
            }
        } else {
            false
        }

    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SessionConfigView.self)
    )

    // The order of these vars is important - the completion handler should be at the end
    var completionHandler: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    Section {
#if os(visionOS)
                        if #available(visionOS 2.4, *) {
                            // Hide the IPD measure button as the tracking system will do it
                        } else {
                            HStack {
                                Button {showIpdMeasurementPopOver = true}
                                label: {
                                    Image(systemName: "questionmark.circle")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.blue)
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                                .popover(isPresented: $showIpdMeasurementPopOver) {
                                    Text("Measure user ipd and eye offsets. Only need to do once per user")
                                        .padding()
                                }
                                Text("Last ipd value: \(distance(appModel.hmdProperties.leftEyeInDeviceSpace, appModel.hmdProperties.rightEyeInDeviceSpace))")
                                Spacer()
                                Button("Measure ipd") {
                                    appModel.hmdProperties.beginIpdCheck(openImmersiveSpace: openImmersiveSpace, forceRefresh: true)
                                }
                                .disabled(appModel.windowStateManager.immersiveSpaceActive || appModel.session?.state == .paused)
                                .cornerRadius(20)
                                .multilineTextAlignment(.trailing)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxHeight: 24)
                        }

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
#elseif os(iOS)
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
#endif
                        }
                    }
#if os(visionOS)
                .frame(minHeight: 350, maxHeight: 790)
#elseif os(iOS)
                .frame(minHeight: 160, maxHeight: 690)
#endif


                Button(buttonLabel) {

                    if appModel.session?.state == .paused {
                        try! appModel.session?.resume()
                        self.completionHandler()
                        return
                    }

                    if appModel.session?.state == .connected {
                        appModel.showDisconnectionAlert = true
                        return
                    }

                    // To be safe, disconnect from previous session
                    switch appModel.session?.state {
                    case .disconnected, .disconnecting:
                        break
                    default:
                        appModel.session?.disconnect()
                    }

                    let preset = resolutionPreset
                    var cxrConfig = CloudXRKit.Config()
                    cxrConfig.resolutionPreset = preset


                    var appID: UInt = 0

                    if zone != .ipAddress {
                        if application.appID != .unknown {
                            appID = application.appID.rawValue
                        } else if genericAppID > 0 {
                            appID = UInt(genericAppID)
                        } else {
                            Self.logger.error("No valid appID configured for this application.")
                            return
                        }

                        if !usingGuestMode {
                            cxrConfig.connectionType = .nvGraphicsDeliveryNetwork(
                                appId: UInt(appID),
                                authenticationType: .starfleet(),
                                zone: zone.id
                            )
                        }
                    } else {
                        cxrConfig.connectionType = .local(ip: hostAddress)
                    }

                    if appModel.session == nil {
                        appModel.session = CloudXRSession(config: cxrConfig)
                    }

                    Task { @MainActor in
                        if usingGuestMode {
                            var comps = URLComponents()
                            comps.scheme = "https"
                            // TODO: Please replace this with your actual nonce endpoint.
                            comps.host = "dummy-nonce-host.com"
                            let nonceURL = comps.url!
                            var nonce: String
                            do {
                                nonce = try await getGuestNonce(url: nonceURL)
                            } catch {
                                Self.logger.error("Nonce request failed. Have you configured the nonce endpoint?")
                                return
                            }


                            cxrConfig.connectionType = .nvGraphicsDeliveryNetwork(
                                appId: UInt(appID),
                                authenticationType: .guest(partnerId: partnerIdentifier, tokenHost: nonceURL, nonce: nonce),
                                zone: zone.id)
                        }

                        appModel.session?.configure(config: cxrConfig)
                        try await appModel.session?.connect()
                        completionHandler()
                    }
                }
                .disabled(connectButtonDisabled)
                .sheet(isPresented: Binding(get: { appModel.isRatingViewPresented }, set: { _ in })) {
                    StarRatingView()
                }
                .confirmationDialog(
                    "Do you really want to disconnect?",
                    isPresented: Binding(
                        get: { appModel.showDisconnectionAlert },
                        set: { appModel.showDisconnectionAlert = $0 }
                    ),
                    titleVisibility: .visible
                ) {
                    if !appModel.disableFeedback {
                        Button("Disconnect with feedback") {
                            appModel.session?.disconnect()
                            appModel.isRatingViewPresented = true
                        }
                        Button("Disconnect without feedback", role: .destructive) {
                            appModel.session?.disconnect()
                        }
                    } else {
                        Button("Disconnect", role: .destructive) {
                            appModel.session?.disconnect()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

                Spacer()
                    .frame(height: 8)
                Text(stateDescription)
                Spacer()
                    .frame(height: 18)
#if os(visionOS)
                Form {
                    Section {
                        Picker("Resolution Preset", selection: $resolutionPreset) {
                            ForEach(ResolutionPreset.allCases, id: \.self) { preset in
                                Text(preset.rawValue)
                            }
                        }.disabled(sessionConnected)
                    }
                }
                .frame(minHeight: 800, maxHeight: 800)
#endif

                } // VStack.
#if os(iOS)
                .frame(width: 600, height: 330)
                .padding(.top, 100)
#endif
            } // ScrollView.
#if os(iOS)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .frame(minHeight: 300)
            .cornerRadius(20)
#endif
#if os(iOS)
            Spacer()
#endif
        } // VStack.
#if os(iOS)
        .padding(.top, 100)
#endif
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()
    return SessionConfigView(application: $appModel.application) { () -> Void in }
        .environment(appModel)
}
