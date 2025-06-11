// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import SwiftUI
import os.log

// A simple message handler that executes a closure when a message is received from the server.
class IncomingMessageListener: ServerMessageListener {
    var messageCounter = 0
    var onMessageHandler = { (message: String) -> Void in
        // Replace with custom handler.
    }

    func onMessageReceived(message: Data) {
        messageCounter += 1
        onMessageHandler("Message \(messageCounter): " + String(decoding: message, as: UTF8.self))
    }
}

struct ServerActionsView: View {
    static var logger = Logger()
    // Messages are sent via the session in appModel.
    @Environment(AppModel.self) var appModel

    @State var lastMessageSent: String = ""
    @State var lastMessageReceived: String = ""

    // Required to handle incoming messages from the server.
    @State var messageDispatcher = ServerMessageDispatcher()
    @State var incomingMessageListener = IncomingMessageListener()

    func sendMessage(message: String) {
        guard let session = appModel.session else {
            Self.logger.warning("Cannot send message before initialization")
            return
        }

        if session.state == .connected {
            guard let messageData = message.data(using: .utf8) else {
                Self.logger.warning("String message could not be converted to data")
                lastMessageSent = "Error"
                return
            }
            session.sendServerMessage(messageData)
            lastMessageSent = message
        } else {
            Self.logger.warning("Cannot send message before being connected.")
        }
    }

    var body: some View {
        Form {
            VStack {
                VStack {
                    HStack {
                        Spacer()
                        Button("Action 1") {
                            sendMessage(message: "Action 1")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                        Button("Action 2") {
                            sendMessage(message: "Action 2")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
                Divider()
                VStack {
                    Text("Last message sent: ")
                    Divider()
                    Text(lastMessageSent)
                    Spacer()
                }
                Divider()
                VStack {
                    Text("Last message received:")
                    Divider()
                    Text(lastMessageReceived)
                    Spacer()
                }
            }
        }
        .onAppear {
            // Update the lastMessageReceived when a message is received from the server so that it can be displayed.
            // In general, these messages can be used to trigger local actions on the client.
            incomingMessageListener.onMessageHandler = { [self] message in
                lastMessageReceived = message
            }

            // Bind the message dispatcher.
            messageDispatcher.session = appModel.session
            messageDispatcher.attach(incomingMessageListener)
        }
        .onDisappear {
            messageDispatcher.detach(incomingMessageListener)
        }
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()
    ServerActionsView()
        .environment(appModel)
}

