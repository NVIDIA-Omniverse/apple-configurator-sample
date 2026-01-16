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

// This file will be the home of many asset-neutral types; they will be created/moved here over time.

/// Swift protocol that will be used by style modifiers of assets (color, trim, etc)
public protocol AssetStyle: MessageProtocol, CaseIterable, Identifiable where ID == String {
    var id: Self.ID { get }

    var rawValue: String { get }
    var description: String { get }
}

/// Swift protocol magic to allow ForEach to work cleanly at call sites without specifying `id` manually
extension ForEach where ID == String, Content: View, Data.Element == any AssetStyle {
    init(_ data: Data, @ViewBuilder content: @escaping (any AssetStyle) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

public protocol AssetEnvironment: MessageProtocol, CaseIterable, Identifiable where ID == String
{
    var id: Self.ID { get }
    var rawValue: String { get }
    var description: String { get }

    var isDisabled: Bool { get }
    var isHidden: Bool { get }
    var supportsLighting: Bool { get }
}

public extension AssetEnvironment {
    var id: String { rawValue }
}

/// Swift protocol magic to allow ForEach to work cleanly at call sites without specifying `id` manually
extension ForEach where ID == String, Content: View, Data.Element == any AssetEnvironment {
    init(_ data: Data, @ViewBuilder content: @escaping (any AssetEnvironment) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

public class AssetCamera: Identifiable, MessageProtocol {
    /// name of camera entity in Omniverse
    public var ovName = ""
    /// English name to use in UI
    public var description = ""
    public var encodable: any MessageDictionary
    public var id: String { ovName }

    init(
        ovName: String = "",
        description: String = "",
        encodable: any MessageDictionary = BaseMessageDictionary()
    ) {
        self.ovName = ovName
        self.description = description
        self.encodable = encodable
    }

    public func isEqualTo(_ other: MessageProtocol?) -> Bool {
        guard let otherCamera = other as? AssetCamera else { return false }
        return self.ovName == otherCamera.ovName
    }
}

/// Eventually, we will not need to subclass AssetModel, but will read all the data
/// from an external source. For now though, we will subclass PurseAssetModel
/// and CarAssetModel
public class AssetModel {
    /// The list of top-level styles (colors, what have you) applied to the model
    var styleList: [any AssetStyle]
    /// The currently selected style
    var style: any AssetStyle
    /// List of adornments / modifications to the main style (clasp color, trim, etc)
    var subStyleList: [any AssetStyle]
    /// current subStyle
    var subStyle: any AssetStyle
    /// available interior cameras
    var interiorCameras: [AssetCamera]
    /// available exterior cameras
    var exteriorCameras: [AssetCamera]
    /// available seat cameras
    var seatCameras: [AssetCamera]
    /// the current camera, if any (there is none for tabletop mode)
    var camera: AssetCamera?
    /// Dictionary of paths to specific features of all models (cameras etc)
    var path: [ModelPath: String]
    /// Trigger action list rebuilding based on updated view model
    weak var configuratorViewModel: ConfiguratorViewModel? {
        didSet {
            onViewModel()
        }
    }
    /// List of actions with UI
    var actions: [AssetAction]

    var environments: [any AssetEnvironment]

    var lightnessRange: ClosedRange<Float> = 0.0...1.0
    var lighting: (any MessageProtocol)? {
        set { stateManager[lightingKey] = newValue }
        get { stateManager[lightingKey] }
    }
    var lightingKey = ""

    var stateManager: OmniverseStateManager

    var serverResponseTimedOut: Bool { stateManager.serverResponseTimedOut }

    /// string returned from server when "switchVariant" is complete
    var switchVariantCompleteType: String

    /// string send to server to set the variant
    var variantSetNameField: String

    /// this asset's state dictionary
    var stateDict: StateDictionary

    func isAwaitingCompletion(_ stateKey: String) -> Bool { stateManager.isAwaitingCompletion(stateKey) }

    enum Feature {
        case rotation
        case interiorViews
        case exteriorViews
        case seatView
    }

    func supports(_ feature: Feature) -> Bool {
        // by default support nothing
        false
    }

    subscript(_ stateKey: String) -> (any MessageProtocol)? {
        get { stateManager[stateKey] }
        set { stateManager[stateKey] = newValue }
    }

    func resync() { stateManager.resync() }

    public func makeViewingModel(_ mode: ViewingModel.Mode) -> ViewingModel {
        fatalError("base method should never be called")
    }

    init(
        styleList: [any AssetStyle],
        style: any AssetStyle,
        subStyleList: [any AssetStyle],
        subStyle: any AssetStyle,
        path: [ModelPath: String],
        stateDict: StateDictionary,
        actions: [AssetAction],
        environments: [any AssetEnvironment],
        interiorCameras: [AssetCamera],
        exteriorCameras: [AssetCamera],
        seatCameras: [AssetCamera],
        switchVariantCompleteType: String,
        variantSetNameField: String
    ) {
        self.styleList = styleList
        self.style = style
        self.subStyleList = subStyleList
        self.subStyle = subStyle
        self.path = path
        self.switchVariantCompleteType = switchVariantCompleteType
        self.variantSetNameField = variantSetNameField
        self.stateDict = stateDict
        self.stateManager = OmniverseStateManager(
            resyncDuration: 15.0,
            resyncCountTimeout: 20
        )
        self.actions = actions
        self.environments = environments
        self.exteriorCameras = exteriorCameras
        self.interiorCameras = interiorCameras
        self.seatCameras = seatCameras
        self.stateManager.asset = self
    }

    // base class does nothing - override in derived classes
    func onViewModel() { }

    // bas class does nothing - override in derived classes
    func syncPortalBrightness() { }
}

public enum ModelPath: String {
    case cameraPrefix
    case cameraActivate
    case cameraPath

    case viewingMode
    case viewingModeVariant
    case viewingModeName
}
