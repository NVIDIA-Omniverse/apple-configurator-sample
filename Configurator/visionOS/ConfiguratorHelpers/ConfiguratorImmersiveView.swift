// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import CloudXRKit
import SwiftUI
import RealityKit

struct ConfiguratorImmersiveView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(ConfiguratorAppModel.self) var configuratorAppModel
    @Environment(ConfiguratorViewModel.self) var configuratorViewModel
    
    @State private var sceneEntity = Entity()
    @State private var sessionEntity = Entity()
    @State private var spinnerEntity = Entity()

    @State private var cameraAnchor = Entity()
    @State private var placementManager = PlacementManager()
    
    var body: some View {
        RealityView { content, attachments in
            placementManager.placeable = configuratorViewModel

            sceneEntity.name = "Scene"
            sessionEntity.name = "Session"
            spinnerEntity.name = "Spinner"

            if let session = configuratorAppModel.session {
                sessionEntity.components[CloudXRSessionComponent.self] = .init(session: session)
            }
            configuratorViewModel.sessionEntity = sessionEntity
            spinnerEntity = Entity()
            spinnerEntity.opacity = 1.0
            content.add(spinnerEntity)

            sceneEntity.components[ViewingModeComponent.self] = .init(
                configuratorAppModel: configuratorAppModel,
                cloudXrEntity: sessionEntity,
                spinnerEntity: spinnerEntity
            )
            sceneEntity.components[OpacityComponent.self] = .init(opacity: 0.0)

            configuratorViewModel.sceneEntity = sceneEntity

            content.add(sceneEntity)
            cameraAnchor = Entity()
            content.add(cameraAnchor)
            cameraAnchor.addChild(makeInvisibleGestureWall())
            _ = content.subscribe(to:SceneEvents.Update.self,on: nil, componentType: nil) { frameData in
                if configuratorViewModel.viewIsLoading != configuratorAppModel.isAwaitingCompletion(viewingKey) {
                    configuratorViewModel.viewIsLoading = configuratorAppModel.isAwaitingCompletion(viewingKey)
                }
                
                let purseVisibility = (configuratorAppModel.asset["purseVisibility"] as? PurseVisibility == PurseVisibility.visible)
                if configuratorViewModel.purseVisible != purseVisibility {
                    configuratorViewModel.purseVisible = purseVisibility
                }
            
                if let currentViewing = configuratorAppModel.asset[viewingKey] as? ViewingModel,
                   currentViewing != configuratorViewModel.currentViewing {
                     configuratorViewModel.currentViewing = currentViewing
                }
                if let headPose = configuratorAppModel.session?.latestHeadPose {
                    cameraAnchor.transform = headPose
                }
            }
        } update: { content, attachments in
            if let session = configuratorAppModel.session {
                placementManager.update(session: session, content: content, attachments: attachments)
            }
        } attachments: {
            if configuratorViewModel.isPlacing {
                placementManager.attachments()
            }
        }
        .placing(with: placementManager, sceneEntity: sceneEntity, placeable: configuratorViewModel)
        .simultaneousGesture(configuratorAppModel.gestureHelper?.dragGesture)
        .simultaneousGesture(configuratorAppModel.gestureHelper?.rotationGesture)
        .simultaneousGesture(configuratorAppModel.gestureHelper?.magnifyGesture)
        .onChange(of: configuratorAppModel.session?.state) { oldState, newState in
            if newState == .connected {
                configuratorAppModel.asset.stateManager.startPolling()
                configuratorAppModel.asset.resync()
            } else {
                configuratorAppModel.asset.stateManager.stopPolling()
            }
        }
    }

    // TODO: Change this to the bounding box of the object sent from OV
    func makeInvisibleGestureWall() -> Entity {
        // Add an invisible plane that covers the viewport, attached to the headset that can accept gestures
        // so as to not get in the way of gestures on UI objects, the plane is 20 meters away.
        let plane = Entity()
        plane.components.set(InputTargetComponent())
        var collision = CollisionComponent(shapes: [.generateBox(width: 40, height: 40, depth: 0.01)])
        collision.mode = .trigger
        plane.components.set(collision)
        plane.position.z = -20
        return plane
    }
}
