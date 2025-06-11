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
    // Add CMS IDs here
    case unknown = 000_000_000
}

enum Application: String, CaseIterable {
    case purse_rel = "Purse Configurator"



    var appID: AppID {
        switch self {
            // Add mapping from Applications to CMS IDs here
        default:
            .unknown
        }
    }

    var isConfigurator: Bool {
        switch self {
            
        default:
            true
        }
    }
}

let apiHost = "api-prod.nvidia.com"
let captchaEndpoint = "/gfn-als-app/api/captcha/img"
let nonceEndpoint = "/gfn-als-app/api/als/nonce"

let partnerIdentifier = ""

var globalToken: String = ""

extension SessionConfigView {
    struct NonceReqData : Codable {
        let cSessionId: String
        let AWSALB: String
    }

    struct CaptchaResponse : Codable {
        let base64Data: String
        let cSessionId: String
        let AWSALB: String
    }

    var stateDescription: String {
        appModel.session?.state.description ?? ""
    }

    var buttonLabel: String {
        switch appModel.session?.state {
        case .connected: "Disconnect"
        case .paused, .pausing: "Resume"
        default: "Connect"
        }
    }

    var displayCAPTCHA: Bool {
        switch appModel.session?.state {
        case nil, .disconnected, .initialized:
            usingGuestMode
        default:
            false
        }
    }

    var usingGuestMode: Bool {
        authMethod == .guest && zone != .ipAddress
    }

    var connectButtonDisabled: Bool {
        switch appModel.session?.state {
        case .connecting, .authenticating, .authenticated, .disconnecting, .resuming, .pausing:
            true
        case .connected, .paused:
            false
        default:
            requiredCAPTCHAEmpty
        }
    }

    var requiredCAPTCHAEmpty: Bool {
        usingGuestMode && captchaText.isEmpty
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
}
