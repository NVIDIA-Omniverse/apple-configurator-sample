//
//  PlacementViewModifiers.swift
//  CloudXRViewer
//
//  Created by Reid Ellis on 2024-07-17.
//

import SwiftUI
import RealityKit

struct PlacementModifier: ViewModifier {
    var placementManager: PlacementManager
    var sceneEntity: Entity
    var placeable: Placeable

    func body(content: Content) -> some View {
        content
        // Tasks attached to a view automatically receive a cancellation
        // signal when the user dismisses the view. This ensures that
        // loops that await anchor updates from the ARKit data providers
        // immediately end.
        .gesture(
            SpatialTapGesture().targetedToAnyEntity().onEnded { event in
                placementManager.tap(event: event, rootEntity: sceneEntity)
            }
        )
    }
}

extension View {
    func placing(with manager: PlacementManager, sceneEntity: Entity, placeable: Placeable) -> some View {
        modifier(PlacementModifier(placementManager: manager, sceneEntity: sceneEntity, placeable: placeable))
    }
}
