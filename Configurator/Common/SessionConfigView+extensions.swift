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
    case guest = "Guest Mode"
}

enum Zone: String, CaseIterable {
    case auto = "Auto"
    case us_east = "US East"
    case us_northwest = "US Northwest"
    case us_west = "US West"
    case eu_north = "EU North"
    case ipAddress = "Manual IP address"

    var id: String? {
        switch self {
        case .auto:
            nil // automatic
        case .us_east:
           "np-atl-03" // "us-east"
        case .us_northwest:
           "np-pdx-01" // "us-northwest"
        case .us_west:
            "np-sjc6-04" // "us-west"
        case .eu_north:
            "np-sth-04" // "eu-north"
        default:
            nil
        }
    }
}

enum AppID: UInt, CaseIterable {
    // Add CMS IDs here
    case unknown

    var rawValue: UInt {
        switch self {
        case .unknown:
            return 000_000_000
        }
    }
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

extension SessionConfigView {

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

    var usingGuestMode: Bool {
        authMethod == .guest && zone != .ipAddress
    }

    var connectButtonDisabled: Bool {
        switch appModel.session?.state {
        case .connecting, .authenticating, .authenticated, .disconnecting, .resuming, .pausing:
            true
        default:
            false
        }
    }
}
