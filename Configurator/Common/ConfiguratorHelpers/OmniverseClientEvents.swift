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

let jsonEncoder = JSONEncoder()

func encodeJSON(_ data: Encodable) -> Data {
    try! jsonEncoder.encode(data)
}

public class ViewingModel: MessageProtocol, Equatable {
    public static func == (lhs: ViewingModel, rhs: ViewingModel) -> Bool {
        type(of: lhs) == type(of: rhs) && lhs.mode == rhs.mode
    }

    public static func != (lhs: ViewingModel, rhs: ViewingModel) -> Bool {
        lhs.mode != rhs.mode
    }

    public enum Mode: String, CaseIterable {
        case tabletop = "tabletop"
        case portal = "portal"
    }
    public var modeNames: [String] = Mode.allCases.map { $0.rawValue }

    public var mode: Mode = .tabletop

    public var isPortal: Bool { mode == .portal }

    public func toggle() -> ViewingModel {
        let newMode: Mode
        switch mode {
        case .tabletop:
            newMode = .portal
        case .portal:
            newMode = .tabletop
        }
        return makeViewingModel(newMode)
    }

    /// derived, asset-specific versions of this class should override this to return asset-specific classes
    public func makeViewingModel(_ mode: Mode) -> ViewingModel {
        ViewingModel(mode)
    }

    public init(_ mode: Mode) {
        self.mode = mode
    }

    // these should all be overridden by derived classes
    public var description: String {
        fatalError("`description` has not been overridden.")
    }
    public var encodable: any MessageDictionary {
        fatalError("`encodable` has not been overridden.")
    }
    public func isEqualTo(_ other: ViewingModel?) -> Bool { mode == other?.mode }
}

public struct LightSliderClientInputEvent: MessageDictionary {
    public let message: Dictionary<String, Float>
    public let type = "setLightSlider"

    public init(_ intensity: Float, asset: AssetModel) {
        // pin value to be within asset.lightnessRange
        let intensity = min(max(intensity, asset.lightnessRange.lowerBound), asset.lightnessRange.upperBound)
        message = [
            "intensity": intensity
        ]
    }
}

public struct LightSlider: Equatable, CustomStringConvertible, MessageProtocol {
    public var intensity: Float = 0
    public var asset: AssetModel

    public init(_ intensity: Float, asset: AssetModel) {
        self.intensity = intensity
        self.asset = asset
    }

    public var description: String {
        String(format:"%3g", intensity)
    }
    
    public var encodable: any MessageDictionary {
        LightSliderClientInputEvent(self.intensity, asset: asset)
    }

    public static func ==(lhs: LightSlider, rhs: LightSlider) -> Bool {
        lhs.intensity == rhs.intensity
    }
}
