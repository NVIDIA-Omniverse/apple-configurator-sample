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

import RealityKit
import SwiftUI

@Observable
final class PlacementManager {
    public enum State {
        case none
        case started
        case placed
    }
    
    private var placementPlaneEntity: Entity
    private var floorAnchor: AnchorEntity
    private weak var sessionEntity: Entity?

#if targetEnvironment(simulator)
    public var state: State = .placed
#else
    public var state: State = .none
#endif

    init() {
        dprint("\(Self.self).\(#function)")
        var material = UnlitMaterial(color: .purple.withAlphaComponent(0.75))
        material.opacityThreshold = 0.74
        let plane = ModelEntity(
            mesh: .generatePlane(width: 100, height: 100),
            materials: [material]
        )
        plane.orientation = .init(angle: -.pi/2, axis: .init(x: 1.0, y: 0.0, z: 0.0))
        // To avoid depth fighting
        plane.position.y += 0.01
        plane.generateCollisionShapes(recursive: true)
        plane.components.set(InputTargetComponent())
        placementPlaneEntity = plane
        floorAnchor = AnchorEntity(plane: .horizontal, classification: .floor)
        floorAnchor.addChild(placementPlaneEntity)
    }
    
    public func setup(sessionEntity: Entity, content: RealityViewCameraContent) {
        content.add(floorAnchor)
        self.sessionEntity = sessionEntity
    }

    var placementGesture : some Gesture {
        SpatialTapGesture().targetedToEntity(placementPlaneEntity)
            .onEnded { event in
                if let remoteEntity = self.sessionEntity,
                   let cast = event.hitTest(point: event.location, in: .global).first,
                   cast.entity == self.placementPlaneEntity {
                    remoteEntity.position = cast.position
                    remoteEntity.position.y -= 0.01
                    self.state = .placed
                    self.placementPlaneEntity.isEnabled = false
                }
            }
    }
    
    public func start() {
#if !targetEnvironment(simulator)
        placementPlaneEntity.isEnabled = true
        state = .started
#endif
    }
    
    public func cancel() {
#if !targetEnvironment(simulator)
        placementPlaneEntity.isEnabled = false
        state = .placed
#endif
    }
    
}
