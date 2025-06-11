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
import Combine
import SwiftUI
import RealityKit
import os.log
import Spatial

let viewingKey = "viewingMode"

// Animation callbacks
private var playbackCompletedSubscriptions: Set<AnyCancellable> = .init()

/// Viewing Mode information and entities .
struct ViewingModeComponent: Component {
    static let query = EntityQuery(where: .has(ViewingModeComponent.self))

    weak var cloudXrEntity: Entity?
    weak var configuratorAppModel: ConfiguratorAppModel?

    var currentViewing: ViewingModel? = nil
    var viewIsLoading: Bool = false

    var portalContainer: Entity?
    var portalWorld: Entity?
    var portal: Entity?
    var spinnerEntity: Entity?
    var initPortalPos: SIMD3<Float>? = nil

    public init(configuratorAppModel: ConfiguratorAppModel, cloudXrEntity: Entity, spinnerEntity: Entity) {
        self.configuratorAppModel = configuratorAppModel
        self.cloudXrEntity = cloudXrEntity
        self.spinnerEntity = spinnerEntity
    }
    
    /// Returns the Entity in the given Scene that contains a ViewingModeComponent, if present. Only one ViewingModeComponent is allowed.
    static func findEntityIn(_ context: SceneUpdateContext) -> Entity? {
        let entities = context.entities(
            matching: ViewingModeComponent.query,
            updatingSystemWhen: SystemUpdateCondition.rendering
        ).suffix(2)
        switch entities.count {
        case 0:
            return nil
        case 1:
            return entities[0]
        default:
            fatalError("Only one ViewingModeComponent is permitted per Scene")
        }
    }
}

class ViewingModeSystem: System {
    private static let logger = Logger(
        subsystem: Bundle(for: ViewingModeSystem.self).bundleIdentifier!,
        category: String(describing: ViewingModeSystem.self)
    )
    
    static let portalWidth: Float = 3.25
    static let portalHeight: Float = 2.5
    static let cornerRadius: Float = 0.2
    static let portalContainerPosition = simd_float3(0, 0.25, -2.5)
    static let barWidth: Float = ViewingModeSystem.portalWidth / 9
    static let barHeight: Float = 0.02
    static let barPortalOffset = (ViewingModeSystem.portalHeight / 2) + (ViewingModeSystem.barHeight * 3)
    static let portalBarName = "portalBar"

    static let fadeOutDurationSeconds = 0.25
    static let fadeInDurationSeconds = 0.5

    required init(scene: RealityKit.Scene) {
    }

    func update(context: SceneUpdateContext) {
        guard let sceneEntity = ViewingModeComponent.findEntityIn(context) else {
            return
        }

        var viewingComponent = sceneEntity.components[ViewingModeComponent.self]!
        defer { sceneEntity.components[ViewingModeComponent.self] = viewingComponent }
        guard
            let configuratorAppModel = viewingComponent.configuratorAppModel,
            let sessionEntity = viewingComponent.cloudXrEntity,
            let sessionComponent = sessionEntity.components[CloudXRSessionComponent.self]
        else {
            return
        }
        let session = sessionComponent.session
        
        if session.state != .connected {
            return
        }
        
        // Initialize portal and its world.
        if viewingComponent.portal == nil {
            let world = Entity()
            world.components[WorldComponent.self] = .init()
            (viewingComponent.portalContainer, viewingComponent.portal) = makePortal(world: world)
            viewingComponent.portalWorld = world
            if viewingComponent.initPortalPos == nil {
                viewingComponent.initPortalPos = viewingComponent.portal?.position(relativeTo: nil)
                // Offset z value for the portal camera
                viewingComponent.initPortalPos?.z += 2.0
            }
        }

        guard let world = viewingComponent.portalWorld,
              let portalContainer = viewingComponent.portalContainer,
              let portal = viewingComponent.portal,
              let spinner = viewingComponent.spinnerEntity,
              let targetViewing = configuratorAppModel.desiredState(viewingKey) as? ViewingModel
        else { return }
        
        // Fade out and prepare the viewing mode if needed.
        if  (!viewingComponent.viewIsLoading &&
             configuratorAppModel.isAwaitingCompletion(viewingKey)) || !targetViewing.isEqualTo(viewingComponent.currentViewing) {

            // No fadeout on loading.
            let fadeOutDuration = (viewingComponent.currentViewing == nil) ? 0 : Self.fadeOutDurationSeconds
            spinner.setOpacity(1.0, from: spinner.opacity, animated: true, duration: fadeOutDuration)

            viewingComponent.viewIsLoading = true
            viewingComponent.currentViewing = targetViewing

            switch targetViewing.mode {
            case .tabletop:
                sceneEntity.setOpacity(0.0, from: sceneEntity.opacity, animated: true, duration: fadeOutDuration)
                DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                    // Move the session entity outside of portal world and add to the scene
                    world.removeChild(sessionEntity)
                    sceneEntity.removeChild(portalContainer)
                    sceneEntity.removeChild(world)
                    sceneEntity.addChild(sessionEntity)
                    
                    // Reset camera transforms and switch to portal on server
                    sessionEntity.transform = .init()

                    // Put the tabletop object where portal was. Using Portal Movement transform.
                    let portalPos = portal.position(relativeTo: nil)
                    sessionEntity.transform = Transform().translated(by: Vector3D(x:portalPos.x, y: 0, z:portalPos.z))
                }
            case .portal:
                sceneEntity.setOpacity(0.0, from: sceneEntity.opacity, animated: true, duration: fadeOutDuration)
                DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                    // Remove the session entity from the scene and add to the portal world
                    sceneEntity.removeChild(sessionEntity)
                    world.addChild(sessionEntity)
                    sceneEntity.addChild(world)
                    sceneEntity.addChild(portalContainer)
                    
                    // Reset camera transforms and switch to default camera
                    sessionEntity.transform = .init()
                    // this means the first camera in the list should always be the "front" camera
                    if let frontCamera = configuratorAppModel.asset.exteriorCameras.first {
                        session.sendServerMessage(encodeJSON(frontCamera.encodable))
                    }
                }
            }
        } else if viewingComponent.viewIsLoading,
           !configuratorAppModel.isAwaitingCompletion(viewingKey) {
            // Fade in the scene if we are done loading.
            sceneEntity.setOpacity(1.0, from: sceneEntity.opacity, animated: true, duration: Self.fadeInDurationSeconds)
            spinner.setOpacity(0.0, from: spinner.opacity, animated: true, duration: Self.fadeInDurationSeconds)
            viewingComponent.viewIsLoading = false
        }

        // Set portal camera transform based on portal position in the world.
        if viewingComponent.currentViewing?.mode == .portal, !viewingComponent.viewIsLoading {
            guard let portal = viewingComponent.portal, let initPos = viewingComponent.initPortalPos else { return }
            var portalTransform = Transform(matrix: portal.transformMatrix(relativeTo: nil).inverse)
            portalTransform = portalTransform.translated(by: Vector3D(initPos))
            sessionEntity.transform = .init(matrix: portalTransform.matrix.inverse)
        }
    }
    
    private func makePortalEntity(world: Entity) -> Entity {
        let portal = Entity()
        portal.components[ModelComponent.self] = .init(
            mesh: .generatePlane(
                width: Self.portalWidth,
                height: Self.portalHeight,
                cornerRadius: Self.cornerRadius
            ),
            materials: [PortalMaterial()]
        )
        portal.components[PortalComponent.self] = .init(target: world)
        portal.position = simd_float3(0, Self.barPortalOffset, 0)
        return portal
    }

    private func makePortalBarEntity() -> Entity {
        let barMaterial = UnlitMaterial(color: .white)

        let bar = ModelEntity()
        bar.name = Self.portalBarName
        bar.components[ModelComponent.self] = .init(
            mesh: .generatePlane(
                width: Self.barWidth,
                height: Self.barHeight,
                cornerRadius: Self.barHeight/2
            ),
            materials: [barMaterial]
        )
        bar.components.set(HoverEffectComponent())
        bar.addGestureSupport()
        
        return bar
    }

    /// Creates the portal entity and its container which includes a drag bar.
    ///
    /// portalContainer -> bloomPreventionParent -> { portal, bar }
    private func makePortal(world: Entity) -> (Entity, Entity) {
        let portal = makePortalEntity(world: world)

        let bloomPreventionParent = Entity()
        bloomPreventionParent.name = "bloomPreventionParent"

        let portalContainer = ModelEntity()
        portalContainer.name = "portalContainer"
        portalContainer.addChild(bloomPreventionParent)
        portalContainer.position = Self.portalContainerPosition

        let bar = makePortalBarEntity()

        bloomPreventionParent.addChild(portal)
        bloomPreventionParent.addChild(bar)

        return (portalContainer, portal)
    }
}

extension ModelEntity {
    /// Add gesture control by generating collision shapes and setting input target component.
    func addGestureSupport() {
        generateCollisionShapes(recursive: true)
        components.set(InputTargetComponent())
        collision?.mode = .trigger
    }
}

extension Entity {
    /// Entity opacity animation logic from https://gist.github.com/drewolbrich/1e9d3da074c8a1d5ca93721124b97596
    /// The opacity value applied to the entity and its descendants.
    ///
    /// `OpacityComponent` is assigned to the entity if it doesn't already exist.
    var opacity: Float {
        get {
            components[OpacityComponent.self]?.opacity ?? 1
        }
        set {
            if !components.has(OpacityComponent.self) {
                components[OpacityComponent.self] = OpacityComponent(opacity: newValue)
            } else {
                components[OpacityComponent.self]?.opacity = newValue
            }
        }
    }

   /// Sets the opacity value applied to the entity and its descendants with optional animation.
   ///
   /// `OpacityComponent` is assigned to the entity if it doesn't already exist.
    func setOpacity(_ opacity: Float, from: Float = 0.0, animated: Bool, duration: TimeInterval = 0.5, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
       guard animated else {
           self.opacity = opacity
           return
       }
       
       if !components.has(OpacityComponent.self) {
           components[OpacityComponent.self] = OpacityComponent(opacity: 1)
       }

       let animation = FromToByAnimation(name: "Entity/setOpacity", from: from, to: opacity, duration: duration, timing: .linear, isAdditive: false, bindTarget: .opacity, delay: delay)
        
       do {
           let animationResource: AnimationResource = try .generate(with: animation)
           let animationPlaybackController = playAnimation(animationResource)
           
           if completion != nil {
               scene?.publisher(for: AnimationEvents.PlaybackCompleted.self)
                   .filter { $0.playbackController == animationPlaybackController }
                   .sink(receiveValue: { event in
                       completion?()
                   }).store(in: &playbackCompletedSubscriptions)
           }
       } catch {
           assertionFailure("Could not generate animation: \(error.localizedDescription)")
       }
    }
}
