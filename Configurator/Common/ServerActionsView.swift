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
import CloudXRKit
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
    // Messages are sent via MessageChannel of the session in appModel.
    @Environment(AppModel.self) var appModel

    @State var lastMessageSent: String = ""
    @State var lastMessageReceived: String = ""

    @Binding var currentChannelSelection: ChannelInfo?
    @Binding var currentChannel: MessageChannel?

    // Dispatcher is provided by the parent to keep it alive across tabs.
    var messageDispatcher: ServerMessageDispatcher
    @State var incomingMessageListener = IncomingMessageListener()

    func sendMessage(message: String) {
        guard let channelSelection = currentChannelSelection else {
            Self.logger.warning("No channel selected")
            lastMessageSent = "Error - no channel"
            return
        }

        guard let messageData = message.data(using: .utf8) else {
            Self.logger.warning("String message could not be converted to data")
            lastMessageSent = "Error"
            return
        }

        if let channel = currentChannel {
            if channel.sendServerMessage(messageData) {
                lastMessageSent = message
            } else {
                Self.logger.warning("Failed to send message via current channel")
                lastMessageSent = "Error - failed to send"
            }
        } else {
            Self.logger.warning("No current channel available for send")
            lastMessageSent = "Error - no channel"
        }
    }

    var body: some View {
        Form {
            VStack {
                if let session = appModel.session {
                    Picker("Channels", selection: $currentChannelSelection) {
                        ForEach(session.availableMessageChannels, id: \.self) { channelInfo in
                            Text("Channel [\(channelInfo.uuid.map { String($0) }.joined(separator: ","))]").tag(channelInfo as ChannelInfo?)
                        }
                        Text("None").tag(nil as ChannelInfo?)
                    }
                    .pickerStyle(.menu)
                    .id(session.availableMessageChannels)
                    .onChange(of: currentChannelSelection) {
                        currentChannel = nil

                        guard let channelSelection = currentChannelSelection else {
                            return
                        }
                        guard let channel = session.getMessageChannel(channelSelection) else {
                            return
                        }

                        currentChannel = channel
                    }
                    .onChange(of: session.availableMessageChannels) {
                        if let channelSelection = currentChannelSelection,
                           !session.availableMessageChannels.contains(channelSelection)
                        {
                            currentChannelSelection = nil
                        }
                    }

                    if let channel = currentChannel {
                        Text("Status: \(channel.status.rawValue)")
                    } else {
                        Text("Status: N/A")
                    }
                }

                Divider()

                VStack {
                    HStack {
                        Spacer()
                        Button("Action 1") {
                            sendMessage(message: "Action 1")
                        }
                        .disabled(currentChannelSelection == nil)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                        Button("Action 2") {
                            sendMessage(message: "Action 2")
                        }
                        .disabled(currentChannelSelection == nil)
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
            guard let session = appModel.session else {
                Self.logger.warning("Cannot send message before initialization")
                return
            }
            // Update the lastMessageReceived when a message is received from the server so that it can be displayed.
            // In general, these messages can be used to trigger local actions on the client.
            incomingMessageListener.onMessageHandler = { [self] message in
                lastMessageReceived = message
            }

            // Bind the message dispatcher.
            messageDispatcher.attach(incomingMessageListener)
        }
        .onDisappear {
            messageDispatcher.detach(incomingMessageListener)
        }
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()
    @Previewable @State var selection: ChannelInfo? = nil
    @Previewable @State var channel: MessageChannel? = nil
    @Previewable @State var dispatcher = ServerMessageDispatcher()
    ServerActionsView(currentChannelSelection: $selection, currentChannel: $channel, messageDispatcher: dispatcher)
        .environment(appModel)
}
