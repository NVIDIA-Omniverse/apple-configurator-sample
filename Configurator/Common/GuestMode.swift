// SPDX-FileCopyrightText: Copyright (c) 2023-2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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

// MARK: - Combined Guest Mode Component
@Observable class GuestModeComponent {
    // MARK: - UIViewRepresentable for the combined component
    struct AuthRepresentableView: UIViewRepresentable {
        let uiView: UIView

        func makeUIView(context: Context) -> UIView {
            return uiView
        }

        func updateUIView(_ view: UIView, context: Context) {
            // nothing to update
        }
    }

    // MARK: - Observable Properties
    var token: String?

    // MARK: - Private Properties
    let width: CGFloat = 640
    let height: CGFloat = 480
    let uiView = UIView()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: GuestModeComponent.self)
    )

    init() {
        self.uiView.backgroundColor = .clear
    }

    func makeView() -> some View {
        AuthRepresentableView(uiView: uiView)
            .frame(width: width, height: height, alignment: .center)
    }

    func configure(onSuccess: @escaping () -> Void) {
        Self.logger.error("Guest mode not implemented")
    }

    func getGuestAuth(appID: UInt) async throws -> AuthenticationType {
        fatalError("Guest mode not implemented")
    }
}

