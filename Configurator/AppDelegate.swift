// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import Foundation
import SwiftUI
import os.log
import CloudXRKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var app: UIApplication?
    var session: Session?

    private static let logger = Logger(
        subsystem: Bundle(for: AppDelegate.self).bundleIdentifier!,
        category: String(describing: AppDelegate.self)
    )

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        app = application
        return true
    }

    // Currently never called for visionOS
    func applicationWillTerminate(_ application: UIApplication) {
        AppDelegate.logger.info("Disconnecting before app terminates")
        session?.disconnect()
    }
}
