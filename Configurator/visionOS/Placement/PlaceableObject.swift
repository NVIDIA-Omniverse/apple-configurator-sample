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
import RealityKit

struct PlaceableModelDescriptor: Identifiable, Hashable {
    let displayName: String

    var id: String { displayName }

    init(displayName: String) {
        dprint("\(Self.self).\(#function) \(displayName)")
        self.displayName = displayName
    }
}

private enum PreviewMaterials {
    static let active = UnlitMaterial(color: .gray.withAlphaComponent(0.5))
    static let inactive = UnlitMaterial(color: .gray.withAlphaComponent(0.1))
}

@MainActor
class PlaceableObject {
    let descriptor: PlaceableModelDescriptor
    var previewEntity: Entity
    private var renderContent: ModelEntity

    static let previewCollisionGroup = CollisionGroup(rawValue: 1 << 15)

    init(_ name: String, renderContent: ModelEntity, previewEntity: Entity) {
        dprint("\(Self.self).\(#function) \(previewEntity.name)")
        descriptor = PlaceableModelDescriptor(displayName: name)
        self.previewEntity = previewEntity
        previewEntity.applyMaterial(PreviewMaterials.active)
        self.renderContent = renderContent
    }

    var isPreviewActive: Bool = true {
        didSet {
            if oldValue != isPreviewActive {
                previewEntity.applyMaterial(isPreviewActive ? PreviewMaterials.active : PreviewMaterials.inactive)
                // Only act as input target while active to prevent intercepting drag gestures from intersecting placed entities.
                previewEntity.components[InputTargetComponent.self]?.allowedInputTypes = isPreviewActive ? .indirect : []
            }
        }
    }

    func materialize() -> PlacedEntity {
        let shapes = previewEntity.components[CollisionComponent.self]!.shapes
        return PlacedEntity(descriptor: descriptor, renderContentToClone: renderContent, shapes: shapes)
    }

    func matchesCollisionEvent(event: CollisionEvents.Began) -> Bool {
        event.entityA == previewEntity || event.entityB == previewEntity
    }

    func matchesCollisionEvent(event: CollisionEvents.Ended) -> Bool {
        event.entityA == previewEntity || event.entityB == previewEntity
    }

    func attachPreviewEntity(to entity: Entity) {
        entity.addChild(previewEntity)
    }
}

extension Entity {
    func applyMaterial(_ material: Material) {
        if let modelEntity = self as? ModelEntity {
            modelEntity.model?.materials = [material]
        }
        for child in children {
            child.applyMaterial(material)
        }
    }

    var extents: simd_float3 { visualBounds(relativeTo: self).extents }

    func look(at target: simd_float3) {
        look(
            at: target,
            from: position(relativeTo: nil),
            relativeTo: nil,
            forward: .positiveZ
        )
    }

    // Traverse the entity tree to attach a certain debug mode through components.
    func attachDebug(_ debug: ModelDebugOptionsComponent) {
        components.set(debug)
        for child in children {
            child.attachDebug(debug)
        }
    }
    // Respond to a button or UI element. func
    func debugLightingDiffuse() {
        let debugComponent = ModelDebugOptionsComponent(visualizationMode: .lightingDiffuse)
        self.attachDebug(debugComponent)
    }

    @MainActor
    func dump(indent: Int = 1) {
        let indentStr = String(repeating: "    ", count: indent)
        dprint(indentStr + "\"\(name)\" - \(type(of: self))")
        dprint(indentStr + " - transform: \(transform)")
        children.forEach { child in
            child.dump(indent: indent + 1)
        }
    }
}
