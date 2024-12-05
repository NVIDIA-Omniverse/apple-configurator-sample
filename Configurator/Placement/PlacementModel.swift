// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.
//import Foundation
//
import ARKit
import RealityKit
import CloudXRKit

@Observable
class PlacementModel {
    private(set) weak var placementManager: PlacementManager? = nil

    private(set) var modelDescriptors: [PlaceableModelDescriptor] = []

    func set(manager: PlacementManager) {
        placementManager = manager
    }

    // MARK: - ARKit state

    var providersStoppedWithError = false
    var sensingAuthorizationStatus: ARKitSession.AuthorizationStatus = .notDetermined

    func requestWorldSensingAuthorization(session: Session) async {
        dprint("\(Self.self).\(#function)")
        let authorizationResult = await CloudXRSession.requestAuthorization(for: PlaneDetectionProvider.requiredAuthorizations)
        // not sure we should be restricting to .worldSensing, but that's what the example code did..
        if let result = authorizationResult[.worldSensing] {
            sensingAuthorizationStatus = result
        } else {
            sensingAuthorizationStatus = .notDetermined
        }
    }
}
