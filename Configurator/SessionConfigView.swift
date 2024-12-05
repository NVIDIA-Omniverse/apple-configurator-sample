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

enum AuthMethod: String, CaseIterable {
    case starfleet = "Geforce NOW login"
    case guest = "CAPTCHA"
}

enum Zone: String, CaseIterable {
    case auto = "Auto"
//    case us_east = "US East"
//    case us_northwest = "US Northwest"
    case us_west = "US West"
    case ipAddress = "Manual IP address"

    var id: String? {
        switch self {
        case .auto:
            nil // automatic
//        case .us_east:
//            "np-atl-03" // "us-east"
//        case .us_northwest:
//            "np-pdx-01" // "us-northwest"
        case .us_west:
            "np-sjc6-04" // "us-west"
        default:
            nil
        }
    }
}

enum AppID: UInt, CaseIterable {
    case purse_rel = 000_000_000
}

enum Application: String, CaseIterable {
    case purse_rel = "Purse Configurator Release"

    var appID: AppID? {
        switch self {
        case .purse_rel:
            AppID.purse_rel
        }
    }
}

let apiHost = "api-prod.nvidia.com"
let captchaEndpoint = "/gfn-als-app/api/captcha/img"
let nonceEndpoint = "/gfn-als-app/api/als/nonce"
let partnerIdentifier = "<insert-partner-identifier-here>"

struct SessionConfigView: View {
    @AppStorage("hostAddress") private var hostAddress: String = ""
    @AppStorage("zone") private var zone: Zone = .auto
    @AppStorage("application") private var application: Application = .purse_rel
    @AppStorage("autoReconnect") private var autoReconnect: Bool = false
    @AppStorage("authMethod") private var authMethod: AuthMethod = .starfleet
    @AppStorage("resolutionPreset") private var resolutionPreset: ResolutionPreset = .standardPreset
    @AppStorage("disableRecordingToggle") var disableRecordingToggle: Bool = false

    @Environment(AppModel.self) var appModel
    @Environment(ViewModel.self) var viewModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    @State var captcha = UIImage()
    @State var captchaText: String = ""
    @State var captchaPrompt: String = "Enter image text here"
    @State var awsalb: String = ""
    @State var sessionId: String = ""
    @State private var showIpdMeasurementPopOver = false

    @Environment(HmdProperties.self) var hmdProperties

    @Bindable var uiState: LaunchView.UIState

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SessionConfigView.self)
    )

    // The order of these vars is important - the completion handler should be at the end
    var completionHandler: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    Section {
                        HStack {
                            Button(action: {showIpdMeasurementPopOver = true}){
                                Image(systemName: "questionmark.circle").resizable().frame(width: 24, height: 24).foregroundColor(.blue)
                            }.frame(width: 24, height: 24).clipShape(Circle()).popover(isPresented: $showIpdMeasurementPopOver) {
                                Text("Measure user ipd and eye offsets. Only need to do once per user")
                                    .padding()
                            }
                            Text("Last ipd value: \(hmdProperties.measuredIpd)")
                            Spacer()
                                .frame(width: 100)
                            Button("Measure ipd", action: {
                                    hmdProperties.beginIpdCheck(openImmersiveSpace: openImmersiveSpace, forceRefresh: true)
                                }
                            )
                            .disabled(viewModel.anyImmersiveSpaceRunning || appModel.session.state == .paused).cornerRadius(20)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxHeight: 24)

                        Picker("Select Zone", selection: $zone) {
                            ForEach (Zone.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .frame(width: 500)
                        .onChange(of: zone) {
                            if zone != .us_west {
                                // Dummy call to trigger request local network permissions early
                                NetServiceBrowser().searchForServices(ofType: "_http", inDomain: "")
                            }
                        }
                        if zone == .ipAddress {
                            HStack {
                                Text("IP Address")
                                Spacer()
                                    .frame(width: 100)
                                TextField("0.0.0.0", text: $hostAddress)
                                    .disableAutocorrection(true)
                                    .autocapitalization(.none)
                            }
                        } else {
                            HStack {
                                Picker("Select Application", selection: $application) {
                                    ForEach (Application.allCases, id: \.self) { appOption in
                                        Text(appOption.rawValue)
                                    }
                                }
                                .frame(width: 500)
                            }
                            HStack {
                                Picker("Select Authentication Method", selection: $authMethod) {
                                    ForEach (AuthMethod.allCases, id: \.self) { authOption in
                                        Text(authOption.rawValue)
                                    }
                                }
                                .frame(width: 500)
                            }
                        }

                    }
                }
                .frame(minHeight: 250, maxHeight: 790)

                if displayCAPTCHA {
                    Button("Regenerate CAPTCHA image") {
                        Task {
                            try await getCaptchaImage()
                        }
                    }
                    Image(uiImage: captcha).onAppear {
                        Task {
                            try await getCaptchaImage()
                        }
                    }
                    .padding()

                    TextField(captchaPrompt, text: $captchaText)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40))
                        .padding()
                }
                Button(buttonLabel) {
                    captchaPrompt = "Enter image text here"
                    var connectionType: ConnectionType?
                    // Only allow changing the preset until the connect button has been clicked
                    if buttonLabel == "Connect" {
                        disableRecordingToggle = true
                    }

                    if appModel.session.state == .paused {
                        try! appModel.session.resume()
                        self.completionHandler()
                        return
                    }

                    if appModel.session.state == .connected {
                        viewModel.showDisconnectionAlert = true
                        return
                    }

                    // To be safe, disconnect from previous session
                    switch appModel.session.state {
                    case .disconnected, .disconnecting:
                        break
                    default:
                        appModel.session.disconnect()
                    }

                    let preset = resolutionPreset
                    var cxrConfig = CloudXRKit.Config()
                    cxrConfig.resolutionPreset = preset

                    if zone != .ipAddress {
                        if !usingGuestMode {
                            if let appID = application.appID?.rawValue {
                                connectionType = .nvGraphicsDeliveryNetwork(
                                    appId: UInt(appID),
                                    authenticationType: .starfleet(),
                                    // zone can be nil
                                    zone: zone.id
                                )
                            }

                            if let connectionType {
                                cxrConfig.connectionType = connectionType
                            }
                        }
                    } else {
                        cxrConfig.connectionType = .local(ip: hostAddress)
                    }

                    Task { @MainActor in
                        if usingGuestMode {
                            guard let appID = application.appID else {
                                Self.logger.error("No appID configured for guest mode authentication.")
                                return
                            }
                            var comps = URLComponents()
                            comps.scheme = "https"
                            comps.host = apiHost
                            comps.path = nonceEndpoint
                            comps.queryItems = [
                                URLQueryItem(name: "locale", value: Locale.current.identifier(Locale.IdentifierType.bcp47)),
                                URLQueryItem(name: "t", value: self.captchaText),
                                URLQueryItem(name: "app", value: "cloudxr"),
                                URLQueryItem(name: "cms_id", value: String(appID.rawValue)),
                            ]
                            let nonceURL = comps.url!
                            var nonce: String
                            do {
                                nonce = try await getGuestNonce(url: nonceURL)
                            } catch {
                                self.captchaText = ""
                                self.captchaPrompt = "CAPTCHA error, please try again"
                                try await getCaptchaImage()
                                return
                            }
                            self.captchaText = ""

                            if zone.id != nil, let appId = application.appID {
                                connectionType = .nvGraphicsDeliveryNetwork(appId: UInt(appId.rawValue), authenticationType: .guest(partnerId: partnerIdentifier, tokenHost: comps.url!, nonce: nonce), zone: zone.id)
                            } else if let appId = application.appID {
                                connectionType = .nvGraphicsDeliveryNetwork(appId: UInt(appId.rawValue), authenticationType: .guest(partnerId: partnerIdentifier, tokenHost: comps.url!, nonce: nonce))
                            }
                            if let connectionType {
                                cxrConfig.connectionType = connectionType
                            }
                        }

                        appModel.session.configure(config: cxrConfig)

                        try await appModel.session.connect()
                        uiState.showViewSelector = true
                        completionHandler()
                    }
                }
                .disabled(connectButtonDisabled)
                .sheet(isPresented: Binding(get: { viewModel.isRatingViewPresented }, set: { _ in })) {
                    StarRatingView()
                }
                .confirmationDialog(
                    "Do you really want to disconnect?",
                    isPresented: Binding(
                        get: { viewModel.showDisconnectionAlert },
                        set: { viewModel.showDisconnectionAlert = $0 }
                    ),
                    titleVisibility: .visible
                ) {
                    if !viewModel.disableFeedback {
                        Button("Disconnect with feedback") {
                            appModel.session.disconnect()
                            viewModel.isRatingViewPresented = true
                        }
                        Button("Disconnect without feedback", role: .destructive) {
                            appModel.session.disconnect()
                        }
                    } else {
                        Button("Disconnect", role: .destructive) {
                            appModel.session.disconnect()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

                Spacer()
                    .frame(height: 8)
                Text(stateDescription)
                Spacer()
                    .frame(height: 18)

                Form {
                    Section {
                        Picker("Resolution Preset", selection: $resolutionPreset) {
                            ForEach(ResolutionPreset.allCases, id: \.self) { preset in
                                Text(preset.rawValue)
                            }
                        }.disabled(disableRecordingToggle)
                    }
                }
                .frame(minHeight: 800, maxHeight: 800)
            }
        }
    }

    var stateDescription: String {
        appModel.session.state.description
    }

    var buttonLabel: String {
        switch appModel.session.state {
        case .connected: "Disconnect"
        case .paused, .pausing: "Resume"
        default: "Connect"
        }
    }

    struct NonceReqData : Codable {
        let cSessionId: String
        let AWSALB: String
    }

    func getGuestNonce(url: URL) async throws -> String {
        var req = URLRequest(url: url)

        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.addValue("text/plain", forHTTPHeaderField: "Accept")
        req.addValue("*/*", forHTTPHeaderField: "Accept")

        req.httpBody = try! JSONEncoder().encode(NonceReqData(cSessionId: sessionId, AWSALB: awsalb))
        let (data, _) = try! await URLSession.shared.data(for: req)

        struct NonceRespData : Codable {
            let nonce: String
        }
        let nonceResp = try JSONDecoder().decode(NonceRespData.self, from: data)
        return nonceResp.nonce
    }

    struct CaptchaResponse : Codable {
        let base64Data: String
        let cSessionId: String
        let AWSALB: String
    }

    func getCaptchaImage() async throws {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = apiHost
        comps.path = captchaEndpoint

        let (data, _) = try await URLSession.shared.data(from: comps.url!)

        let response = try JSONDecoder().decode(CaptchaResponse.self, from: data)

        let imgData = Data(base64Encoded: response.base64Data)!
        self.captcha = UIImage(data: imgData)!
        self.awsalb = response.AWSALB
        self.sessionId = response.cSessionId
    }

    var displayCAPTCHA: Bool {
        switch appModel.session.state {
        case .disconnected, .initialized:
            usingGuestMode
        default:
            false
        }
    }

    var usingGuestMode: Bool {
        authMethod == .guest && zone != .ipAddress
    }

    var connectButtonDisabled: Bool {
        switch appModel.session.state {
        case .connecting, .authenticating, .authenticated, .disconnecting, .resuming, .pausing:
            true
        case .connected, .paused:
            viewModel.ipdImmersiveSpaceRunning
        default:
            viewModel.ipdImmersiveSpaceRunning || requiredCAPTCHAEmpty
        }
    }

    var requiredCAPTCHAEmpty: Bool {
        usingGuestMode && captchaText.isEmpty
    }
}


#Preview {
    SessionConfigView(uiState: LaunchView.UIState()) { () -> Void in }
}
