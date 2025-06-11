// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

//  Unit/Integration testing of the visionOS CXR client.
//
//  Created by Reid Ellis on 2024-04-24.
//  Further work by David Chait.
//

import XCTest
import SwiftUI
import CloudXRKit
import OSLog
@testable import Configurator

final class ConfiguratorTests: XCTestCase {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ConfiguratorTests.self)
    )

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSessionStateAtStart() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.

        let configuratorAppModel = ConfiguratorAppModel()
        if configuratorAppModel.session == nil {
            configuratorAppModel.session = CloudXRSession(config: CloudXRKit.Config())
        }
        XCTAssertTrue(configuratorAppModel.session?.state == .initialized)
    }

    func testViewModel() throws {
        let configuratorViewModel = ConfiguratorViewModel()
        XCTAssertTrue(configuratorViewModel.viewIsLoading)
    }

    func testConnectingPurseWithScreenshot() async throws {
        let session = CloudXRSession(config: CloudXRKit.Config())

        TestHelper.appModel!.application = Application.purse_rel
        TestHelper.appModel!.session = session
        TestHelper.configuratorAppModel!.asset = PurseAsset()
        let expectation = expectation(description: "Connecting")
        Task { @MainActor in
            try await session.connect()
            while session.state != .connecting {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            // Signal to CI log scan that it's time to take a screenshot
            Self.logger.info("screenshot--coat_purse_connecting_test")
            XCTAssertTrue(session.state == .connecting)
            try await Task.sleep(nanoseconds: 1_000_000_000 * 10)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 20.0)
    }
}
