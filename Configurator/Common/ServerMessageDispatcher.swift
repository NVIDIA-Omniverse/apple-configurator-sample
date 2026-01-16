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

/// Represents a message queued for transmission.
///
/// Used by the internal send queue to defer sending until the
/// target channel is ready.
/// - `data`: Raw message payload destined for the server.
/// - `channelUUID`: Optional target channel UUID. When `nil`, the
///   first available channel will be used.
private struct QueuedMessage {
    let data: Data
    let channelUUID: Data?
}

public class ServerMessageDispatcher {
    private static let logger = Logger(
        subsystem: Bundle(for: ServerMessageDispatcher.self).bundleIdentifier!,
        category: String(describing: ServerMessageDispatcher.self)
    )

    private var messageListenerTasks = [Data: Task<Void, Never>]()
    private var listeners = [ObjectIdentifier: ServerMessageListener]()
    private var messageChannels = [Data: MessageChannel]()

    // AsyncStream as a producer-consumer queue for sending messages.
    private var sendMessageStream: AsyncStream<QueuedMessage>
    private var sendMessageQueue: AsyncStream<QueuedMessage>.Continuation!
    private var messageProcessingTask: Task<Void, Never>?

    private var lock = OSAllocatedUnfairLock()

    // Monitoring of available channels lifecycle.
    private var availableChannelsWatchTask: Task<Void, Never>?

    public var session: Session? {
        didSet {
            setupChannelListeners()
            watchAvailableChannels()
        }
    }

    /// Returns the first channel announced by the server, or nil if none available.
    public var firstAvailableChannelInfo: ChannelInfo? {
        guard let session = session else { return nil }
        return session.availableMessageChannels.first
    }

    public init() {
        var continuation: AsyncStream<QueuedMessage>.Continuation!
        self.sendMessageStream = AsyncStream { cont in
            continuation = cont
        }
        self.sendMessageQueue = continuation

        // Start the message processing consumer task
        startMessageProcessing()
    }

    /// Attach a listener to receive messages from all channels.
    public func attach(_ listener: ServerMessageListener) {
        lock.withLock {
            listeners[ObjectIdentifier(listener)] = listener
        }
    }

    /// Detach a listener.
    public func detach(_ listener: ServerMessageListener) {
        lock.withLock {
            listeners.removeValue(forKey: ObjectIdentifier(listener))
        }
    }
    /// Send a message. Defaults to the first available channel when
    /// `channelUUID` is nil.
    ///
    /// Note that using the first available channel can lead to unexpected
    /// behavior if it is not the one you want to send the message to, or if it
    /// changes over time. Default the channel to the first available one is
    /// useful when the application creates a single channel and the client can
    /// be agnostic of its UUID.
    public func sendMessage(_ data: Data, channelUUID: Data? = nil) -> Bool {
        return lock.withLock {
            guard let session = session else {
                Self.logger.error("Cannot send message: session not available")
                return false
            }

            // Resolve the target channel.
            let targetChannel = resolveTargetChannel(channelUUID)

            guard let channel = targetChannel else {
                // Queue with the originally requested UUID.
                let queuedMessage = QueuedMessage(data: data, channelUUID: channelUUID)
                sendMessageQueue.yield(queuedMessage)

                let channelDesc = channelUUID?.map { String($0) }.joined(separator: ",") ?? "first available"
                Self.logger.info("Channel [\(channelDesc)] not ready - queued message")
                return true
            }

            return channel.sendServerMessage(data)
        }
    }

    /// Get a message channel by UUID.
    public func getMessageChannel(uuid: Data) -> MessageChannel? {
        guard let session = session else {
            Self.logger.error("Cannot get channel: session not available")
            return nil
        }

        let channelInfo = session.availableMessageChannels.first { channelInfo in
            channelInfo.uuid == uuid
        }

        guard let channelInfo = channelInfo else {
            Self.logger.warning("Channel with UUID '\(uuid.map { String($0) }.joined(separator: ","))' not found in available channels")
            return nil
        }

        return session.getMessageChannel(channelInfo)
    }

    /// AsyncStream consumer task that processes queued messages.
    ///
    /// Note that this example implementation has head-of-line blocking as
    /// processQueuedMessage waits for a channel to be ready.
    private func startMessageProcessing() {
        messageProcessingTask = Task {
            for await queuedMessage in sendMessageStream {
                await processQueuedMessage(queuedMessage)
            }
        }
    }

    /// Process a single queued message, waiting for channel readiness.
    private func processQueuedMessage(_ message: QueuedMessage) async {
        while !isChannelReady(message.channelUUID) {
            // Wait a short time before retrying.
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        let success = lock.withLock {
            guard let channel = resolveTargetChannel(message.channelUUID) else { return false }
            return channel.sendServerMessage(message.data)
        }
        if !success {
            Self.logger.error("Failed to send queued message")
        }
    }

    /// Check if a channel is ready for sending.
    private func isChannelReady(_ channelUUID: Data?) -> Bool {
        return lock.withLock {
            if let channelUUID = channelUUID {
                return messageChannels[channelUUID] != nil
            } else {
                return !messageChannels.isEmpty
            }
        }
    }

    /// Resolve a target channel based on the requested UUID.
    /// Must be called with `lock` held.
    private func resolveTargetChannel(_ requestedUUID: Data?) -> MessageChannel? {
        guard let uuid = requestedUUID else {
            // If the requested UUID is nil, return the first available channel.
            return messageChannels.values.first
        }
        return messageChannels[uuid]
    }

    private func uuidString(_ uuid: Data) -> String {
        uuid.map { String($0) }.joined(separator: ",")
    }

    private func setupChannelListeners() {
        guard let session = session else {
            // Clear everything when session is gone.
            messageListenerTasks.values.forEach { $0.cancel() }
            messageListenerTasks.removeAll()
            messageChannels.removeAll()
            Self.logger.info("Session cleared and channel listeners stopped")
            return
        }

        // Build a lookup of available channels keyed by UUID.
        let availableByUUID: [Data: ChannelInfo] = Dictionary(
            uniqueKeysWithValues: session.availableMessageChannels.map { ($0.uuid, $0) }
        )

        // Remove listeners for channels that are gone.
        let toRemove = Set(messageChannels.keys).subtracting(Set(availableByUUID.keys))
        for uuid in toRemove {
            Self.logger.info("Removing listener for channel: [\(self.uuidString(uuid))]")
            messageListenerTasks[uuid]?.cancel()
            messageListenerTasks[uuid] = nil
            messageChannels[uuid] = nil
        }

        // Set up listeners for new channels.
        for (uuid, info) in availableByUUID where messageChannels[uuid] == nil {
            Self.logger.info("Setting up listener for new channel: [\(self.uuidString(uuid))]")
            guard let channel = session.getMessageChannel(info) else {
                Self.logger.error("Failed to get channel for UUID: [\(self.uuidString(uuid))]")
                continue
            }

            messageChannels[uuid] = channel
            messageListenerTasks[uuid] = Task {
                await listenToChannel(channel: channel, uuid: uuid)
            }
        }

        if availableByUUID.isEmpty {
            Self.logger.warning("No message channels available.")
        }
    }

    /// Watch for changes in available message channels.
    private func watchAvailableChannels() {
        // Cancel any existing monitoring.
        availableChannelsWatchTask?.cancel()

        guard let session = session else {
            availableChannelsWatchTask = nil
            return
        }

        func observeAvailableChannels() {
            guard !Task.isCancelled else { return }

            withObservationTracking {
                _ = session.availableMessageChannels
            } onChange: {
                Task { @MainActor in
                    guard !Task.isCancelled else { return }
                    Self.logger.info("Detected available channel changes via observation")
                    self.setupChannelListeners()

                    // Continue observing for next change.
                    observeAvailableChannels()
                }
            }
        }

        availableChannelsWatchTask = Task { @MainActor in
            observeAvailableChannels()

            // Keep the task alive.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private func listenToChannel(channel: MessageChannel, uuid: Data) async {
        let uuidString = self.uuidString(uuid)
        Self.logger.info("Starting to listen to channel: [\(uuidString)]")

        do {
            for await message in channel.receivedMessageStream {
                let listenersSnapshot = lock.withLock { Array(listeners.values) }
                for listener in listenersSnapshot {
                    listener.onMessageReceived(message: message)
                }
            }
        } catch {
            Self.logger.error("Error listening to channel [\(uuidString)]: \(error)")
        }

        Self.logger.info("Stopped listening to channel: [\(uuidString)]")
    }

    deinit {
        messageListenerTasks.values.forEach { $0.cancel() }
        availableChannelsWatchTask?.cancel()
        messageProcessingTask?.cancel()
        sendMessageQueue.finish()
    }
}