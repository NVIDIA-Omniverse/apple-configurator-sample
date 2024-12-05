// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.
//
import Foundation
import RealityKit

class PlacedEntity: Entity {
    let entityName: String

    // The 3D model displayed for this object.
    private let renderContent: ModelEntity

    static let collisionGroup = CollisionGroup(rawValue: 1 << 29)

    // The origin of the UI attached to this object.
    // The UI is gravity aligned and oriented towards the user.
    let uiOrigin = Entity()

    var affectedByPhysics = false {
        didSet {
            guard affectedByPhysics != oldValue else { return }
            components[PhysicsBodyComponent.self]!.mode = affectedByPhysics ? .dynamic : .static
        }
    }

    var isBeingDragged = false {
        didSet {
            affectedByPhysics = !isBeingDragged
        }
    }

    var positionAtLastReanchoringCheck: simd_float3?

    var atRest = false

    init(
        descriptor: PlaceableModelDescriptor,
        renderContentToClone: ModelEntity,
        shapes: [ShapeResource]
    ) {
        entityName = descriptor.displayName
        renderContent = renderContentToClone.clone(recursive: true)
        renderContent.name = "Clone of \(renderContent.name)"
        super.init()
        name = renderContent.name

        // Apply the rendered content’s scale to this parent entity to ensure
        // that the scale of the collision shape and physics body are correct.
        scale = renderContent.scale
        renderContent.scale = .one

        // Make the object respond to gravity.
        let physicsMaterial = PhysicsMaterialResource.generate(restitution: 0.0)
        let physicsBodyComponent = PhysicsBodyComponent(
            shapes: shapes,
            mass: 1.0,
            material: physicsMaterial,
            mode: .static
        )
        components.set(physicsBodyComponent)
        components.set(CollisionComponent(
            shapes: shapes,
            isStatic: false,
            filter: CollisionFilter(group: PlacedEntity.collisionGroup, mask: .all)
        ))
        addChild(renderContent)
        addChild(uiOrigin)
        uiOrigin.position.y = extents.y / 2 // Position the UI origin in the object’s center.

        // Allow direct and indirect manipulation of placed entites.
        components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))

        // Add a grounding shadow to placed entites.
        renderContent.components.set(GroundingShadowComponent(castsShadow: true))
    }

    required init() {
        fatalError("`init` is unimplemented.")
    }
}
