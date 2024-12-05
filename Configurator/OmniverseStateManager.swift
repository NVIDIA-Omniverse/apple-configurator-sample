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

public class OmniverseStateManager {
    private static let logger = Logger(
        subsystem: Bundle(for: OmniverseStateManager.self).bundleIdentifier!,
        category: String(describing: OmniverseStateManager.self)
    )

    public struct OmniverseState {
        var currentState: (any OmniverseMessageProtocol)? = nil
        var desiredState: any OmniverseMessageProtocol
        var serverNotifiesCompletion: Bool
        var waitingForCompletion: Bool = false

        // Timestamp for the last time the state was synced with the server.
        var lastSync: TimeInterval?
        // Number of times we resynced.
        var resyncCount: Int = 0
        
        init(_ desiredState: any OmniverseMessageProtocol, serverNotifiesCompletion: Bool) {
            self.desiredState = desiredState
            self.serverNotifiesCompletion = serverNotifiesCompletion
        }
    }
    typealias StateDictionary = [String: OmniverseState]

    public var serverResponseTimedOut = false
    
    weak var session: Session?
    var serverListener: Task<Void, Never>? = nil
    let stateDispatchQueue  = DispatchQueue(label: "State Update Dispatch Queue")
    
    private let resyncDuration: TimeInterval
    private let resyncCountTimeout: Int

    private var stateDict: StateDictionary = [
        "color": .init(PurseColor.Beige, serverNotifiesCompletion: false),
        "style": .init(Style.Style01, serverNotifiesCompletion: false),
        "purseVisibility": .init(PurseVisibility.visible, serverNotifiesCompletion: false),
 
        "environment": .init(OmniverseEnvironment.plinths, serverNotifiesCompletion: false),
        "lightSlider": .init(LightSlider(1.0), serverNotifiesCompletion: false),

        "viewingMode": .init(ViewingMode.portal, serverNotifiesCompletion: true)
    ]
    
    public init(resyncDuration: TimeInterval, resyncCountTimeout: Int) {
        self.resyncDuration = resyncDuration
        self.resyncCountTimeout = resyncCountTimeout

        statePoll()
    }
    
    subscript(_ stateKey: String) -> (any OmniverseMessageProtocol)? {
        get {
            stateDispatchQueue.sync {
                guard let state = stateDict[stateKey] else { return nil }
                return state.currentState
            }
        }

        set {
            stateDispatchQueue.sync {
                // Disable adding new keys to the state dict.
                if newValue == nil {
                    return
                }
                guard let state = stateDict[stateKey] else { return }
                if state.waitingForCompletion {
                    Self.logger.error("Tried updating a state that is waiting for completion! \(stateKey)")
                    return
                }
                stateDict[stateKey]?.desiredState = newValue!
                stateDict[stateKey]?.lastSync = CACurrentMediaTime()
            }
            sync()
        }
    }
    
    public func desiredState(_ key: String) -> any OmniverseMessageProtocol {
        stateDispatchQueue.sync {
            return stateDict[key]!.desiredState
        }
    }
    
    public func isAwaitingCompletion(_ stateKey: String) -> Bool {
        stateDispatchQueue.sync {
            guard let state = stateDict[stateKey] else { return false }
            return state.waitingForCompletion
        }
    }

    public func sync() {
        guard let session = self.session else { return }
        if serverListener == nil {
            self.serverListener = Task {
                await eventDecoder(session)
            }
        }
        stateDispatchQueue.async { [self] in
            for (stateName, state) in self.stateDict {
                var newState = state
                if let currentState = state.currentState, currentState.isEqualTo(state.desiredState) {
                    continue
                } else {
                    Self.logger.info("Sending state to server: \(state.desiredState.encodable.message.description)")
                    session.sendServerMessage(encodeJSON(state.desiredState.encodable))
                    if state.serverNotifiesCompletion {
                        newState.waitingForCompletion = true
                    } else {
                        newState.currentState = state.desiredState
                    }
                    newState.lastSync = CACurrentMediaTime()
                    stateDict[stateName] = newState
                }
            }
        }
    }

    public func send(_ message: any OmniverseMessageProtocol) {
        guard let session = self.session else { return }
        Self.logger.info("Sending message to server: \(message.encodable.message.description)")
        session.sendServerMessage(encodeJSON(message.encodable))
    }
    
    public func resync() {
        stateDict.forEach {
            stateDict[$0.0]?.currentState = nil
            stateDict[$0.0]?.resyncCount = 0
            stateDict[$0.0]?.waitingForCompletion = false
        }
        serverResponseTimedOut = false
        sync()
    }
    
    private func eventDecoder(_ session: Session) async {
        for await message in session.serverMessageStream {
            if let decodedMessage = try? JSONSerialization.jsonObject(with: message, options: .mutableContainers) as? Dictionary<String, String> {
                // Decode ack messages from omniverse and update the state
                if decodedMessage["Type"] == "switchVariantComplete",
                   let variantName = decodedMessage["variantSetName"]
                {
                    variantCompletedCallback(variantName)
                }
            }
        }
    }
    
    private func variantCompletedCallback(_ variantName: String) {
        stateDispatchQueue.sync {
            for (stateName, state) in stateDict {
                if state.serverNotifiesCompletion, state.waitingForCompletion {
                    let stateVariantName = state.desiredState.encodable.message["variantSetName"] as? String
                    if stateVariantName == variantName {
                        var newState = state
                        newState.currentState = state.desiredState
                        newState.waitingForCompletion = false
                        newState.resyncCount = 0
                        stateDict[stateName] = newState
                    }
                }
            }
        }
    }
    
    private func statePoll() {
        stateDispatchQueue.asyncAfter(deadline: .now() + resyncDuration) {
            self.statePoll()
        }
        var syncNeeded = false
        for (stateName, state) in  stateDict {
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
                    stateDict[stateName] = newState
                    serverResponseTimedOut = true
                    session?.disconnect()
                }
                if (CACurrentMediaTime() - lastSync) > resyncDuration {
                    stateDict[stateName]?.resyncCount += 1
                    syncNeeded = true
                }
            }
        }
        if syncNeeded {
            sync()
        }
    }
}

