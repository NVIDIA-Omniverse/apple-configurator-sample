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

let setVariantEventType = "setVariantSelection"

let jsonEncoder = JSONEncoder()

func encodeJSON(_ data: Encodable) -> Data {
    try! jsonEncoder.encode(data)
}

public protocol EncodableInputEvent: Encodable, Equatable {
    associatedtype Parameter
    var message: Dictionary<String, Parameter> { get }
    var type: String { get }
}

/// Use ModelMessageProtocol to automate as much of the process as possible for sending messages to a CloudXR session
public protocol OmniverseMessageProtocol {
    /// The encodable object being sent to the session's sendServerMessage method after encoding
    var encodable: any EncodableInputEvent { get }
    
    func isEqualTo(_ other: OmniverseMessageProtocol?) -> Bool
}

extension OmniverseMessageProtocol where Self: Equatable {
    public func isEqualTo(_ other: OmniverseMessageProtocol?) -> Bool {
        guard let otherX = other as? Self else { return false }
        return self == otherX
    }
}

public struct ViewingModeClientInputEvent: EncodableInputEvent {
    public let message: Dictionary<String, String>
    public let type = setVariantEventType

    public init(_ mode: ViewingMode) {
        message = [
            "primPath": "/World/Background/context",
            "variantSetName": "viewingMode",
            "variantName": mode.rawValue
        ]
    }
}

public enum ViewingMode: String, CaseIterable, OmniverseMessageProtocol {
    case tabletop = "tabletop"
    case portal = "portal"
    
    func toggle() -> ViewingMode {
        switch self {
        case .tabletop:
            .portal
        case .portal:
            .tabletop
        }
    }
    public var description: String { rawValue.capitalized }
    public var encodable: any EncodableInputEvent { ViewingModeClientInputEvent(self) }
}

public struct CameraClientInputEvent: EncodableInputEvent {
    static let cameraPrefix = "/World/Cameras/cameraViews/RIG_Main/RIG_Cameras/"
    static let setActiveCameraEventType = "setActiveCamera"

    public let message: Dictionary<String, String>
    public let type = Self.setActiveCameraEventType

    public init(_ camera: any CameraProtocol) {
        message = ["cameraPath": "\(Self.cameraPrefix)\(camera.rawValue)"]
    }
}

/// Cameras need a `description` since their rawValue may not be pretty
public protocol CameraProtocol: CustomStringConvertible, OmniverseMessageProtocol, RawRepresentable where RawValue: StringProtocol { }

extension CameraProtocol {
    public var encodable: any EncodableInputEvent { CameraClientInputEvent(self) }
}

public enum ExteriorCamera: String, CaseIterable, CameraProtocol {
    case front = "Front"
    case frontLeftQuarter = "Front_Left_Quarter"

    public var description: String { rawValue.replacingOccurrences(of: "_", with: " ") }
}

public struct ColorClientInputEvent: EncodableInputEvent {
    public let message: Dictionary<String, String>
    public let type = setVariantEventType

    public init(_ color: PurseColor) {
        message = [
            "variantSetName": "color",
            "variantName": color.rawValue
        ]
    }
}

public enum PurseColor: String, CaseIterable, OmniverseMessageProtocol {
    case Beige
    case Black
    case BlackEmboss
    case Orange
    case Tan
    case White

    public var description: String {
        switch self {
        case .Beige:
            "Beige Leather"
        case .Black:
            "Black Leather"
        case .BlackEmboss:
            "Black Emboss Leather"
        case .Orange:
            "Orange Leather"
        case .Tan:
            "Tan Leather"
        case .White:
            "White Leather"
        }
    }
    
    public var encodable: any EncodableInputEvent { ColorClientInputEvent(self) }

}


public struct StyleClientInputEvent: EncodableInputEvent {
    public let message: Dictionary<String, String>
    public let type = setVariantEventType

    public init(_ style: Style) {
        message = [
            "variantSetName": "style",
            "variantName": style.rawValue
        ]
    }
}

public enum Style: String, CaseIterable, OmniverseMessageProtocol {
    case Style01
    case Style02
    case Style03

    public var description: String {
        switch self {
        case .Style01:
            "Gold Triangle Clasp"
        case .Style02:
            "Chrome Ring Clasp"
        case .Style03:
            "Pink Ring Clasp"
        }
    }
    
    public var encodable: any EncodableInputEvent { StyleClientInputEvent(self) }

}

public struct VisibilityClientInputEvent: EncodableInputEvent {
    public let message: Dictionary<String, String>
    public let type = setVariantEventType

    public init(_ mode: PurseVisibility) {
        message = [
            "variantSetName": "Visibility",
            "variantName": mode.rawValue
        ]
    }
}

public enum PurseVisibility: String, OmniverseMessageProtocol {
    case visible = "Visible"
    case hidden = "Hidden"
    
    public var encodable: any EncodableInputEvent { VisibilityClientInputEvent(self) }
}

public struct AnimationClientInputEvent: EncodableInputEvent {
    public let message: Dictionary<String, String>
    public let type = "setPurseRotation"

    public init(_ animation: String) {
        message = [
            "animationName": animation
        ]
    }
}


public enum RotationAction: String, OmniverseMessageProtocol {
    case rotateCW = "RotateCW"
    case rotateCCW = "RotateCCW"
    
    public var encodable: any EncodableInputEvent { AnimationClientInputEvent(self.rawValue) }
}

public struct LightSliderClientInputEvent: EncodableInputEvent {
    public let message: Dictionary<String, Float>
    public let type = "setLightSlider"

    public init(_ intensity: Float) {
        assert((0.0...2.0).contains(intensity))
        message = [
            "intensity": intensity
        ]
    }
}

public struct LightSlider: Equatable, CustomStringConvertible, OmniverseMessageProtocol {
    public var intensity: Float = 0
    
    public init(_ intensity: Float) {
        self.intensity = intensity
    }
    
    public var description: String {
        String(format:"%3g", intensity)
    }
    
    public var encodable: any EncodableInputEvent {
        LightSliderClientInputEvent(intensity)
    }

    public static func ==(lhs: LightSlider, rhs: LightSlider) -> Bool {
        lhs.intensity == rhs.intensity
    }
}

public struct EnvironmentClientInputEvent: EncodableInputEvent {
    public let message: Dictionary<String, String>
    public let type = setVariantEventType

    public init(_ env: OmniverseEnvironment) {
        message = [
            "variantSetName": "environment",
            "variantName": env.rawValue
        ]
    }
}

public enum OmniverseEnvironment: String, CaseIterable, OmniverseMessageProtocol {
    case plinths = "Plinths"
    case desk = "Desk"
    case marblewall = "MarbleWall"

    public var description: String { rawValue }
    var isDisabled: Bool { OmniverseEnvironment.disabled.contains(self) }
    var isHidden: Bool { OmniverseEnvironment.hidden.contains(self) }
    var supportsLighting: Bool { OmniverseEnvironment.lightable.contains(self) }
    static var disabled: [OmniverseEnvironment] = []
    static var hidden: [OmniverseEnvironment] = []
    static var lightable: [OmniverseEnvironment] = [.plinths, .desk, .marblewall]
    
    public var encodable: any EncodableInputEvent { EnvironmentClientInputEvent(self) }
}
