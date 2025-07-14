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
import RealityKit
import CloudXRKit

struct SavedSettings {
    @AppStorage("application") static var application: Application = .purse_rel
}

/// The data that the app uses to configure its views.
@Observable
public class AppModel {
    public var session: Session?

#if DEBUG
    var disableFeedback = true
#else
    var disableFeedback = false
#endif

    var isRatingViewPresented = false
    var ratingText = "Feedback"
    var showDisconnectionAlert = false

    var showStreamingAppView: Bool {
        guard let session else {
            return false
        }

        if session.state == .connected || session.state == .connecting {
            return true
        }

        return false
    }

    var application = SavedSettings.application {
        didSet {
            SavedSettings.application = application
        }
    }

    #if os(visionOS)
    let hmdProperties = HmdProperties()
    let windowStateManager = WindowStateManager()
    #endif
}
