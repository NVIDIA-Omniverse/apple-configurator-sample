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

/// AssetAction is a verb that can be applied to a model, e.g. "Open Door", "Rotate", etc
public class AssetAction: Identifiable {
    var asset: AssetModel
    var configuratorViewModel: ConfiguratorViewModel
    let label: String
    let onText: String?
    let offText: String?
    let shouldToggleView: Bool
    let isOn: Bool?
    let stateName: String?
    let enableEvent: (any MessageProtocol)?
    let disableEvent: (any MessageProtocol)?
    var textCondition: ((Bool) -> Bool)?
    var isDisabled: () -> Bool
    var helpText: () -> String
    public var id: String { label }

    init(
        asset: AssetModel,
        configuratorViewModel: ConfiguratorViewModel,
        label: String,
        onText: String? = nil,
        offText: String? = nil,
        shouldToggleView: Bool,
        isOn: Bool? = nil,
        stateName: String? = nil,
        enableEvent: (any MessageProtocol)? = nil,
        disableEvent: (any MessageProtocol)? = nil,
        textCondition: ((Bool) -> Bool)? = nil,
        isDisabled: @escaping () -> Bool  = { false },
        helpText: @escaping () -> String = { "" }
    ) {
        self.asset = asset
        self.configuratorViewModel = configuratorViewModel
        self.label = label
        self.onText = onText ?? ""
        self.offText = offText ?? ""
        self.shouldToggleView = shouldToggleView
        self.isOn = isOn ?? true
        self.stateName = stateName
        self.enableEvent = enableEvent
        self.disableEvent = disableEvent
        self.textCondition = textCondition
        self.isDisabled = isDisabled
        self.helpText = helpText
    }

    func toggle(_ isOn: Bool) {
        if let stateName, let enableEvent, let disableEvent {
            asset[stateName] = isOn ? enableEvent : disableEvent
        }
    }
}
