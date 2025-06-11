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
import ARKit
import RealityKit

class PlaneAnchorHandler {
    var rootEntity: Entity

    // A map of plane anchor UUIDs to their entities.
    private var planeEntities: [UUID: Entity] = [:]

    // A dictionary of all current plane anchors based on the anchor updates received from ARKit.
    private var planeAnchorsByID: [UUID: PlaneAnchor] = [:]

    init(rootEntity: Entity) {
        self.rootEntity = rootEntity
    }

    var planeAnchors: [PlaneAnchor] {
        Array(planeAnchorsByID.values)
    }

    @MainActor
    func process(_ anchorUpdate: AnchorUpdate<PlaneAnchor>) async {
        let anchor = anchorUpdate.anchor

        if anchorUpdate.event == .removed {
            planeAnchorsByID.removeValue(forKey: anchor.id)
            if let entity = planeEntities.removeValue(forKey: anchor.id) {
                entity.removeFromParent()
            }
            return
        }

        planeAnchorsByID[anchor.id] = anchor

        let entity = Entity()
        entity.name = "Plane \(anchor.id)"
        entity.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)

        // Generate a collision shape for the plane (for object placement and physics).
        var shape: ShapeResource? = nil
        do {
            let vertices = anchor.geometry.meshVertices.asSIMD3(ofType: Float.self)
            shape = try await ShapeResource.generateStaticMesh(
                positions: vertices,
                faceIndices: anchor.geometry.meshFaces.asUInt16Array()
            )
        } catch {
            dprint("Failed to create a static mesh for a plane anchor: \(error).")
            return
        }

        if let shape {
            var collisionGroup = PlaneAnchor.verticalCollisionGroup
            if anchor.alignment == .horizontal {
                collisionGroup = PlaneAnchor.horizontalCollisionGroup
            }

            entity.components.set(CollisionComponent(
                shapes: [shape], isStatic: true,
                filter: CollisionFilter(group: collisionGroup, mask: .all))
            )
            // The plane needs to be a static physics body so that objects come to rest on the plane.
            let physicsMaterial = PhysicsMaterialResource.generate()
            let physics = PhysicsBodyComponent(
                shapes: [shape],
                mass: 0.0,
                material: physicsMaterial,
                mode: .static
            )
            entity.components.set(physics)
        }

        let existingEntity = planeEntities[anchor.id]
        planeEntities[anchor.id] = entity

        rootEntity.addChild(entity)
        existingEntity?.removeFromParent()
    }
}
