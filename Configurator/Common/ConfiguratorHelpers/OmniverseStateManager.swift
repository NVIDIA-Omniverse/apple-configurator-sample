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
import CloudXRKit
import os.log
import QuartzCore

public struct OmniverseState {
    var currentState: (any MessageProtocol)?
    var desiredState: any MessageProtocol
    var serverNotifiesCompletion: Bool
    var waitingForCompletion: Bool = false

    // Timestamp for the last time the state was synced with the server.
    var lastSync: TimeInterval?
    // Number of times we resynced.
    var resyncCount: Int = 0

    init(_ desiredState: any MessageProtocol, serverNotifiesCompletion: Bool = false) {
        self.desiredState = desiredState
        self.serverNotifiesCompletion = serverNotifiesCompletion
    }
}

public typealias StateDictionary = [String: OmniverseState]

@Observable
public class OmniverseStateManager : ServerMessageListener {
    private static let logger = Logger(
        subsystem: Bundle(for: OmniverseStateManager.self).bundleIdentifier!,
        category: String(describing: OmniverseStateManager.self)
    )

    public var serverResponseTimedOut = false

    weak var session: Session?
    var serverListener: Task<Void, Never>? = nil
    let stateDispatchQueue = DispatchQueue(label: "State Update Dispatch Queue")

    private let resyncDuration: TimeInterval
    private let resyncCountTimeout: Int

    var asset: AssetModel?

    public init(
        resyncDuration: TimeInterval,
        resyncCountTimeout: Int
    ) {
        self.resyncDuration = resyncDuration
        self.resyncCountTimeout = resyncCountTimeout
    }

    var isActive = false

    func startPolling() {
        isActive = true
        statePoll()
    }

    func stopPolling() {
        isActive = false
    }

    subscript(_ stateKey: String) -> (any MessageProtocol)? {
        get {
            stateDispatchQueue.sync {
                guard let stateDict = asset?.stateDict, let state = stateDict[stateKey] else { return nil }
                return state.currentState
            }
        }

        set {
            stateDispatchQueue.sync {
                // Disable adding new keys to the state dict.
                guard let newValue else {
                    return
                }
                guard let asset, let state = asset.stateDict[stateKey] else { return }
                if state.waitingForCompletion {
                    Self.logger.error("Tried updating a state that is waiting for completion! \(stateKey)")
                    return
                }
                asset.stateDict[stateKey]?.desiredState = newValue
                asset.stateDict[stateKey]?.lastSync = CACurrentMediaTime()
            }
            sync()
        }
    }

    public func desiredState(_ key: String) -> (any MessageProtocol)? {
        guard let asset else {
            fatalError("nil asset")
        }
        guard let state = asset.stateDict[key] else {
            fatalError("nil state for key \(key)")
        }
        var message: MessageProtocol?
        stateDispatchQueue.sync {
            message = state.desiredState
        }
        return message
    }

    public func isAwaitingCompletion(_ stateKey: String) -> Bool {
        stateDispatchQueue.sync {
            guard let asset, let state = asset.stateDict[stateKey] else { return false }
            return state.waitingForCompletion
        }
    }

    public func sync() {
        guard session != nil else {
            return
        }

        stateDispatchQueue.async { [self] in
            guard let asset else { return }
            for (stateName, state) in asset.stateDict {
                var newState = state
                if let currentState = state.currentState, currentState.isEqualTo(state.desiredState) {
                    continue
                } else {
                    Self.logger.info("Sending state to server: \(state.desiredState.encodable.message.description)")
                    let messageData = encodeJSON(state.desiredState.encodable)
                    // Note that this sends the message to the first available channel and we assume the application
                    // creates the first channel to receive client UI messages.
                    if ConfiguratorAppModel.omniverseMessageDispatcher.sendMessage(messageData) {
                        if state.serverNotifiesCompletion {
                            newState.waitingForCompletion = true
                        } else {
                            newState.currentState = state.desiredState
                        }
                        newState.lastSync = CACurrentMediaTime()
                        asset.stateDict[stateName] = newState
                    } else {
                        Self.logger.error("Failed to send state message for \(stateName)")
                    }
                }
            }
        }
    }

    public func send(_ message: any MessageProtocol) {
        guard session != nil else { return }
        Self.logger.info("Sending message to server: \(message.encodable.message.description)")
        let messageData = encodeJSON(message.encodable)
        if !ConfiguratorAppModel.omniverseMessageDispatcher.sendMessage(messageData) {
            Self.logger.error("Failed to send message: \(message.encodable.message.description)")
        }
    }

    public func resync() {
        if let asset {
            asset.stateDict.forEach {
                asset.stateDict[$0.0]?.currentState = nil
                asset.stateDict[$0.0]?.resyncCount = 0
                asset.stateDict[$0.0]?.waitingForCompletion = false
            }
            serverResponseTimedOut = false
        }
        sync()
    }

    public func onMessageReceived(message: Data) {
        if let asset, let decodedMessage = try? JSONSerialization.jsonObject(with: message, options: .mutableContainers) as? [String: String] {
            if decodedMessage["Type"] == asset.switchVariantCompleteType,
               let variantName = decodedMessage[asset.variantSetNameField] {
                variantCompletedCallback(variantName)
            }
        }
    }

    private func variantCompletedCallback(_ variantName: String) {
        stateDispatchQueue.sync {
            guard let asset else { return }
            for (stateName, state) in asset.stateDict {
                if state.serverNotifiesCompletion, state.waitingForCompletion {
                    let stateVariantName = state.desiredState.encodable.message[asset.variantSetNameField] as? String
                    if stateVariantName == variantName {
                        var newState = state
                        newState.currentState = state.desiredState
                        newState.waitingForCompletion = false
                        newState.resyncCount = 0
                        asset.stateDict[stateName] = newState
                    }
                }
            }
        }
    }

    private func statePoll() {
        guard isActive else {
            dprint("Stopping omniverse state manager polling.")
            return
        }

        guard let asset else {
            dprint("Error: asset should be set before OmniverseStateManager polling starts")
            return
        }
        stateDispatchQueue.asyncAfter(deadline: .now() + resyncDuration) { [weak self] in
            self?.statePoll()
        }
        var syncNeeded = false
        for (stateName, state) in asset.stateDict {
            if state.waitingForCompletion {
                guard let lastSync = state.lastSync else {
                    Self.logger.error("State is waiting for completion but no sync timestamp! \(stateName)")
                    return
                }
                if state.resyncCount > resyncCountTimeout {
                    Self.logger.warning("State update timed out, disconnecting \(stateName) \(state.resyncCount)")
                    var newState = state
                    newState.currentState = state.desiredState
                    newState.waitingForCompletion = false
                    newState.resyncCount = 0
                    asset.stateDict[stateName] = newState
                    serverResponseTimedOut = true
                    session?.disconnect()
                }
                if (CACurrentMediaTime() - lastSync) > resyncDuration {
                    asset.stateDict[stateName]?.resyncCount += 1
                    syncNeeded = true
                }
            }
        }
        if syncNeeded {
            sync()
        }
    }
}
