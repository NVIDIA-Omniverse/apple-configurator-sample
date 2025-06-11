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

let setPurseVariantEventType = "setVariantSelection"

class PurseCamera: AssetCamera {
    init(_ ovName: String = "") {
        super.init(
            ovName: ovName,
            description: ovName.replacingOccurrences(of: "_", with: " "),
            encodable: PurseCameraClientInputEvent(ovName)
        )
    }
}

public class PurseAsset: AssetModel {
    let exteriorPurseCameras: [AssetCamera] = [
        PurseCamera("Front"),
        PurseCamera("Front_Left_Quarter")
    ]

#if os(visionOS)
    let defaultViewingModel = PurseViewingModel(.portal)
#else
    let defaultViewingModel = PurseViewingModel(.tabletop)
#endif

    init() {
        super.init(
            styleList: PurseColor.allCases,
            style: PurseColor.Beige,
            subStyleList: PurseClasps.allCases,
            subStyle: PurseClasps.Style01,
            path: [
                .cameraPrefix: "/World/Cameras/cameraViews/RIG_Main/RIG_Cameras/",
                .cameraActivate: "setActiveCamera"
            ],
            stateDict: [
                "color": .init(PurseColor.Beige),
                "style": .init(PurseClasps.Style01),
                "purseVisibility": .init(PurseVisibility.visible),
                "environment": .init(PurseEnvironment.plinths),
                viewingKey: .init(defaultViewingModel, serverNotifiesCompletion: true)
            ],
            // can't set actions yet as we do not have a non-nil viewModel yet
            actions: [],
            environments: PurseEnvironment.allCases,
            interiorCameras: [],
            exteriorCameras: exteriorPurseCameras,
            seatCameras: [],
            switchVariantCompleteType: "switchVariantComplete",
            variantSetNameField: "variantSetName"
        )
        lightnessRange = 0.0...2.0
        lightingKey = "lightSlider"
        let midLighting = (lightnessRange.upperBound - lightnessRange.lowerBound) / 2.0
        stateDict[lightingKey] = .init(LightSlider(midLighting, asset: self))
    }

    override func supports(_ feature: Feature) -> Bool {
        switch feature {
        case .rotation:
            true
        case .seatView:
            false
        default:
            super.supports(feature)
        }
    }

    override func onViewModel() {
        if let configuratorViewModel {
            actions = [
                PurseVisibleAction(configuratorViewModel: configuratorViewModel, asset: self),
                PurseRotateAction(configuratorViewModel: configuratorViewModel, asset: self),
                PursePlacement(configuratorViewModel: configuratorViewModel, asset: self)
            ]
            configuratorViewModel.lightIntensity = (lightnessRange.upperBound - lightnessRange.lowerBound) / 2.0
            let portalViewing = makeViewingModel(.portal)
            if configuratorViewModel.currentViewing != portalViewing {
                configuratorViewModel.currentViewing = portalViewing
            }
        }
    }

    override public func syncPortalBrightness() {
        guard let configuratorViewModel else { return }
        self[lightingKey] = LightSlider(configuratorViewModel.lightIntensity, asset: self)
    }

    override public func makeViewingModel(_ mode: ViewingModel.Mode) -> ViewingModel {
        PurseViewingModel(mode)
    }
}

public struct PurseViewingModeClientInputEvent: MessageDictionary {
    public let message: Dictionary<String, String>
    public let type = setPurseVariantEventType

    public init(_ viewing: PurseViewingModel) {
        message = [
            "primPath": "/World/Background/context",
            "variantSetName": viewingKey,
            "variantName": viewing.mode.rawValue
        ]
    }
}

public class PurseViewingModel: ViewingModel {
    public override var description: String { mode.rawValue.capitalized }
    public override var encodable: any MessageDictionary { PurseViewingModeClientInputEvent(self) }

    override public func makeViewingModel(_ mode: Mode) -> ViewingModel {
        PurseViewingModel(mode)
    }
}

public enum PurseColor: String, AssetStyle {
    public var id: String { rawValue }

    case Beige
    case Black
    case BlackEmboss
    case Orange
    case Tan
    case White

    public var description: String {
        switch self {
        case .Beige:
            "Beige"
        case .Black:
            "Black"
        case .BlackEmboss:
            "Black Emboss"
        case .Orange:
            "Orange"
        case .Tan:
            "Tan"
        case .White:
            "White"
        }
    }

    public var encodable: any MessageDictionary { PurseColorClientInputEvent(self) }
}

public struct PurseColorClientInputEvent: MessageDictionary {
    public let message: [String: String]
    public let type = setPurseVariantEventType

    public init(_ color: PurseColor) {
        message = [
            "variantSetName": "color",
            "variantName": color.rawValue
        ]
    }
}

public enum PurseClasps: String, AssetStyle {
    public var id: String { rawValue }

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

    public var encodable: any MessageDictionary {
        PurseStyleClientInputEvent(self)
    }
}

public struct PurseStyleClientInputEvent: MessageDictionary {
    public let message: Dictionary<String, String>
    public let type = setPurseVariantEventType

    public init(_ style: any AssetStyle) {
        message = [
            "variantSetName": "style",
            "variantName": style.rawValue
        ]
    }
}

/// Inherit from this action to affect assets in the scene, and override the `toggle` method to perform
/// the given action. e.g. for purse visibility:
public class PurseVisibleAction: AssetAction {
    init(configuratorViewModel: ConfiguratorViewModel, asset: AssetModel) {
        super.init(
            asset: asset,
            configuratorViewModel: configuratorViewModel,
            label: "Visibility",
            onText: "On",
            offText: "Off",
            shouldToggleView: true,
            isOn: configuratorViewModel.purseVisible,
            stateName: "purseVisibility",
            enableEvent: PurseVisibility.visible,
            disableEvent: PurseVisibility.hidden,
            textCondition: { _ in configuratorViewModel.purseVisible },
            helpText: {
                "Toggle visibility of the purse"
            }
        )
    }
}

public class PurseRotateAction: AssetAction {
    init(configuratorViewModel: ConfiguratorViewModel, asset: AssetModel) {
        super.init(
            asset: asset,
            configuratorViewModel: configuratorViewModel,
            label: "Rotate",
            onText: "On",
            offText: "Off",
            shouldToggleView: false,
            isOn: configuratorViewModel.purseRotated,
            helpText: {
                "Rotate the purse 180°"
            }
        )
    }

    override func toggle(_ isOn: Bool) {
        // Sends the appropriate rotation action
        if isOn {
            asset.stateManager.send(PurseRotationStates.rotateCCW)
        } else {
            asset.stateManager.send(PurseRotationStates.rotateCW)
        }
        configuratorViewModel.purseRotated = isOn
    }
}

public class PursePlacement: AssetAction {
    static let placementHelp = "Place model on a horizontal surface"
    static let placementPortalHelp = "Placement only available in tabletop mode"
    static let placementPlacingHelp = "Currently placing"
    // simulator does not support placement
    static let placementNotInSimulator = "Cannot place in simulator"

#if targetEnvironment(simulator)
    static let isSimulator = true
#else
    static let isSimulator = false
#endif

    init(configuratorViewModel: ConfiguratorViewModel, asset: AssetModel) {
        super.init(
            asset: asset,
            configuratorViewModel: configuratorViewModel,
            label: "Place",
            shouldToggleView: false,
            isDisabled: {
                configuratorViewModel.isPlacing || configuratorViewModel.currentViewing.mode == .portal || Self.isSimulator
            },
            helpText: {
                if Self.isSimulator {
                    Self.placementNotInSimulator

                } else if configuratorViewModel.currentViewing.mode == .portal {
                    Self.placementPortalHelp
                } else if configuratorViewModel.isPlacing {
                    Self.placementPlacingHelp
                } else {
                    Self.placementHelp
                }
            }
        )
    }

    override func toggle(_ isOn: Bool) {
        configuratorViewModel.placementState = .started
    }
}

public struct PurseEnvironmentClientInputEvent: MessageDictionary {
    public let message: [String: String]
    public let type = setPurseVariantEventType

    public init(_ env: PurseEnvironment) {
        message = [
            "variantSetName": "environment",
            "variantName": env.rawValue
        ]
    }
}

public enum PurseEnvironment: String, AssetEnvironment {
    case plinths = "Plinths"
    case desk = "Desk"
    case marblewall = "MarbleWall"

    public var description: String { rawValue }
    public var isDisabled: Bool { PurseEnvironment.disabled.contains(self) }
    public var isHidden: Bool { PurseEnvironment.hidden.contains(self) }
    public var supportsLighting: Bool { PurseEnvironment.lightable.contains(self) }
    static var disabled: [PurseEnvironment] = []
    static var hidden: [PurseEnvironment] = []
    static var lightable: [PurseEnvironment] = [.plinths, .desk, .marblewall]

    public var encodable: any MessageDictionary { PurseEnvironmentClientInputEvent(self) }
}

public struct PurseCameraClientInputEvent: MessageDictionary {
    static let cameraPrefix = "/World/Cameras/cameraViews/RIG_Main/RIG_Cameras/"
    static let setActiveCameraEventType = "setActiveCamera"

    public let message: Dictionary<String, String>
    public let type = Self.setActiveCameraEventType

    public init(_ cameraName: String) {
        message = ["cameraPath": "\(Self.cameraPrefix)\(cameraName)"]
    }
}

public struct PurseVisibilityClientInputEvent: MessageDictionary {
    public let message: Dictionary<String, String>
    public let type = setPurseVariantEventType

    public init(_ mode: PurseVisibility) {
        message = [
            "variantSetName": "Visibility",
            "variantName": mode.rawValue
        ]
    }
}

public enum PurseVisibility: String, MessageProtocol {
    case visible = "Visible"
    case hidden = "Hidden"

    public var encodable: any MessageDictionary { PurseVisibilityClientInputEvent(self) }
}

public struct PurseAnimationClientInputEvent: MessageDictionary {
    public let message: Dictionary<String, String>
    public let type = "setPurseRotation"

    public init(_ animation: String) {
        message = [
            "animationName": animation
        ]
    }
}

public enum PurseRotationStates: String, MessageProtocol {
    case rotateCW = "RotateCW"
    case rotateCCW = "RotateCCW"

    public var encodable: any MessageDictionary { PurseAnimationClientInputEvent(self.rawValue) }
}
