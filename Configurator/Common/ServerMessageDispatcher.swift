// SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import CloudXRKit
import Foundation
import os.log

public protocol ServerMessageListener: AnyObject {
    func onMessageReceived(message: Data)
}

public class ServerMessageDispatcher {
    private static let logger = Logger(
        subsystem: Bundle(for: ServerMessageDispatcher.self).bundleIdentifier!,
        category: String(describing: ServerMessageDispatcher.self)
    )

    private var serverListener: Task<Void, Never>?
    private var listeners = [ServerMessageListener]()

    public var session: Session? {
        didSet {
            self.serverListener = Task {
                await eventDecoder()
            }
        }
    }

    public func attach(_ listener: ServerMessageListener) {
        detach(listener)
        listeners.append(listener)
    }

    func detach(_ listener: ServerMessageListener) {
        if let index = listeners.firstIndex(where: { $0 === listener }) {
            listeners.remove(at: index)
        }
    }

    private func eventDecoder() async {
        guard let session = self.session else {
            Self.logger.error("Message dispatcher's session is not valid, cannot listen to incoming messages from the server!")
            return
        }
        for await message in session.serverMessageStream {
            listeners.forEach({ $0.onMessageReceived(message: message) })
        }
    }
}
