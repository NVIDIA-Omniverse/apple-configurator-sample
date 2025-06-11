// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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

@Observable
public class ConfiguratorAppModel {
    public static var omniverseMessageDispatcher = ServerMessageDispatcher()

    public var session: Session? {
        get { asset.stateManager.session }
        set {
            asset.stateManager.session = newValue
            Self.omniverseMessageDispatcher.session = session
            Self.omniverseMessageDispatcher.attach(asset.stateManager)
        }
    }

    public var asset: AssetModel = PurseAsset()

    // simplifying wrapper methods for asset.stateManager; ideally nobody needs to know about
    // OmniverseStateManager

    public func desiredState(_ key: String) -> (any MessageProtocol)? {
        asset.stateManager.desiredState(key)
    }

    public func isAwaitingCompletion(_ stateKey: String) -> Bool {
        asset.stateManager.isAwaitingCompletion(stateKey)
    }

    public func send(_ message: any MessageProtocol) {
        asset.stateManager.send(message)
    }

    var gestureHelper: GestureHelper?

    func setup(application: Application, configuratorViewModel: ConfiguratorViewModel, session: Session) {
        switch application {

        case Application.purse_rel:
            asset = PurseAsset()
        default:
            fatalError("Unknown application type")
        }

        if let configuratorViewModel = asset.configuratorViewModel {
            configuratorViewModel.lightIntensity = (asset.lightnessRange.upperBound - asset.lightnessRange.lowerBound) / 2.0
            configuratorViewModel.currentViewing = asset.makeViewingModel(.portal)
        }
        asset.configuratorViewModel = configuratorViewModel

        gestureHelper = GestureHelper(
            configuratorViewModel: configuratorViewModel,
            configuratorAppModel: self
        )

        self.session = session
    }
}
