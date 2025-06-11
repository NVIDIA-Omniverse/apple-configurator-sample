// SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import SwiftUI
import RealityKit
import os.log
import simd
import CloudXRKit


/// Define the prim path client event.
struct RequestPrimInfoInputEvent: MessageDictionary {
    public let message: [String: String]
    public let type = "initial_prim_path"

    public init(_ primPath: String) {
        message = [
            "PrimPath": primPath
        ]
    }
}

/// Define the prim transformation client event.
struct SetPrimTransformationInputEvent: MessageDictionary {
    public let message: [String: String]
    public let type = "write_prim_transformation_extension"

    public init(_ primPath: String, transformation: Transform) {
        let transformMatrix = transformation.matrix
        let transformMatrixArray = [transformMatrix.columns.0, transformMatrix.columns.1, transformMatrix.columns.2, transformMatrix.columns.3]
        // As the row w is always unchanged, we only send x, y, z rows to shorten latency.
        let flatteneddMatrix = transformMatrixArray.flatMap { column in
            [column.x, column.y, column.z].map { ($0 * 100).rounded() / 100 }
        }
        let matrixString = flatteneddMatrix.map { String($0) }.joined(separator: ",")

        message = [
            "PrimPath": primPath,
            "Value": matrixString
        ]
    }
}

/// A struct holding the prim bounding box w, h, d, center x, y, z, world position x, y, z.
struct PrimShapeInfoStruct {
    var boundingBoxSize: simd_float3  // x = width, y = height, z = depth
    var boundingBoxCenter: simd_float3
    var worldPosition: simd_float3

    init(boundingBoxSize: simd_float3 = .init(x: 0, y: 0, z: 0),
         boundingBoxCenter: simd_float3 = .init(x: 0, y: 0, z: 0),
         worldPosition: simd_float3 = .init(x: 0, y: 0, z: 0)) {
        self.boundingBoxSize = boundingBoxSize
        self.boundingBoxCenter = boundingBoxCenter
        self.worldPosition = worldPosition
    }
}

/// Omniverse Prim information and entities .
class OmniversePrimComponent: Component {
    static let query = EntityQuery(where: .has(OmniversePrimComponent.self))

    var representativeBoxCreated = false
    var shapeInfoRequested = false

    var primPath: String
    var shapeInfo = PrimShapeInfoStruct()

    // The prim remote omniverse transform before the current update in gestures
    var remoteOmniversePrimTransform: Transform = .identity
    
    // Local transform and camera transform matrices are used to handle OV camera/anchor changes.
    var localOmniversePrimTransform: Transform = .identity
    var latestCameraTransform: Transform = .identity

    public init(primPath: String) {
        self.primPath = primPath
    }

    /// Returns all Entities in the given Scene that contains a OmniversePrimComponent.
    static func findEntitiesIn(_ context: SceneUpdateContext) -> [Entity]? {
        let queriedEntities = context.entities(
            matching: OmniversePrimComponent.query,
            updatingSystemWhen: SystemUpdateCondition.rendering
        )
        let entities = Array(queriedEntities)
        return entities
    }
}

class OmniversePrimSystem: System, ServerMessageListener {
    // swiftlint:disable:previous type_body_length
    private static let logger = Logger(
        subsystem: Bundle(for: OmniversePrimSystem.self).bundleIdentifier ?? "[Unknown bundle identifier]",
        category: String(describing: OmniversePrimSystem.self)
    )
    var objectNameAnchorEntities: [String: Entity] = [:]  // List of objects' paths and anchor entities.
    var omniversePrimEntities: [Entity] = []

    var sendOVTransformationTask: Task<Void, Never>?
    
    // Origin tracking
    var currentCameraTransform: Transform = .identity

    required init(scene: RealityKit.Scene) {
        attachOmniverseMessageDispatcher(dispatcher: ConfiguratorAppModel.omniverseMessageDispatcher)
    }

    @AppStorage("usdInteractionVisualizationEnabled") private var usdInteractionVisualizationEnabled: Bool = true

    func update(context: SceneUpdateContext) {

        guard
            let omniversePrimEntitiesFound = OmniversePrimComponent.findEntitiesIn(context),
            let sessionEntity = CloudXRSessionComponent.findEntityIn(context),
            let cloudXRSessionComponent = sessionEntity.components[CloudXRSessionComponent.self],
            cloudXRSessionComponent.session.state == SessionState.connected
        else { return }
        omniversePrimEntities = omniversePrimEntitiesFound
        let session = cloudXRSessionComponent.session

        if !omniversePrimEntities.isEmpty {
            sendPrimPath(session: session)

            for entity in omniversePrimEntities {
                guard let component = entity.components[OmniversePrimComponent.self] else {
                    Self.logger.error("Missing omniverse prim componenent")
                    return
                }
                defer { entity.components[OmniversePrimComponent.self] = component }
                if !component.representativeBoxCreated &&
                    component.shapeInfo.boundingBoxSize != simd_float3(0, 0, 0) {
                    // Draw the bounding box and assign the parent-child relationship
                    component.representativeBoxCreated = true
                    let primPath = component.primPath
                    entity.name = primPath
                    sessionEntity.addChild(entity)
                    objectNameAnchorEntities[primPath] = entity

                    drawPrimBoundingBox(
                        omniversePrimEntity: entity,
                        usdInteractionVisualizationEnabled: usdInteractionVisualizationEnabled,
                        sessionEntity: sessionEntity
                    )
                    Self.assignParentChild(omniversePrimEntity: entity, objectNameAnchorEntities: objectNameAnchorEntities)
                } else {
                    // Check transformation update and send transformation events
                    guard
                        component.representativeBoxCreated,
                        sendOVTransformationTask == nil
                    else { return }
                    
                    // Handle the camera transform update if it has changed since the last frame.
                    if component.latestCameraTransform != currentCameraTransform {
                        // Undo the camera transform first.
                        entity.transform.matrix = component.latestCameraTransform.matrix * entity.transform.matrix
                        component.latestCameraTransform = currentCameraTransform
                        // Apply the camera transform after the update.
                        entity.transform.matrix = component.latestCameraTransform.matrix.inverse * entity.transform.matrix
                    }

                    component.localOmniversePrimTransform.matrix = component.latestCameraTransform.matrix * entity.transform.matrix

                    // Send an update to OV if we are not in sync.
                    if component.remoteOmniversePrimTransform != component.localOmniversePrimTransform {
                        sendOVTransformationTask = Task {
                            let lastSentTime = CACurrentMediaTime()
                            sendOVTransformation(
                                omniversePrimEntity: entity,
                                omniversePrimComponent: component,
                                session: session
                            )
                            component.remoteOmniversePrimTransform = component.localOmniversePrimTransform

                            await Self.rateLimiterWait(frequency: session.stats.frameReceiveRate ?? Double(10.0), lastSentTime: lastSentTime)
                            sendOVTransformationTask = nil
                        }
                    }
                }

            }
        }
    }

    private func sendPrimPath(session: Session) {
        for entity in omniversePrimEntities {
            guard let component = entity.components[OmniversePrimComponent.self] else {
                Self.logger.error("Missing omniverse prim componenent.")
                return
            }
            defer { entity.components[OmniversePrimComponent.self] = component }
            if !component.shapeInfoRequested {
                session.sendServerMessage(encodeJSON(RequestPrimInfoInputEvent(component.primPath)))
                component.shapeInfoRequested = true
            }
        }
    }

    func attachOmniverseMessageDispatcher(dispatcher: ServerMessageDispatcher) {
        dispatcher.attach(self)
    }

    public func onMessageReceived(message: Data) {
        if let decodedMessage = try? JSONSerialization.jsonObject(with: message, options: .mutableContainers) as? [String: Any] {
            let type = decodedMessage["Type"] as? String
            if type == "initial_prims_setup" {
                guard
                    let boundingBoxMessage = decodedMessage["BoundingBox"] as? String,
                    !boundingBoxMessage.isEmpty
                else {
                    return
                }
                let boundingBoxString = boundingBoxMessage.split(separator: ";").map { String($0) }
                let (primPath, primBoundingBox) = OmniversePrimSystem.processBoxShapeInfo(boundingBoxString: boundingBoxString)
                assignBoxShapeInfo(
                    primPath: primPath,
                    primBoundingBox: primBoundingBox
                )
            }
            if type == "pp_camera_transform",
               let cameraTransform = decodedMessage["Transform"] as? [Double] {
                let floats = cameraTransform.map { Float($0) }
                var matrix = simd_float4x4(
                    simd_float4(floats[0], floats[1], floats[2], floats[3]),
                    simd_float4(floats[4], floats[5], floats[6], floats[7]),
                    simd_float4(floats[8], floats[9], floats[10], floats[11]),
                    simd_float4(floats[12], floats[13], floats[14], floats[15])
                )
                currentCameraTransform = .init(matrix: matrix)
            }
        }
    }

    static func processBoxShapeInfo(boundingBoxString: [String]) -> (String, PrimShapeInfoStruct) {
        let objectInfo = boundingBoxString[0].split(separator: ", ").map { String($0) }
        let primPath = objectInfo[0]
        var primBoundingBox = PrimShapeInfoStruct()
        guard
            let boundingBoxSizeX = Float(objectInfo[1]),
            let boundingBoxSizeY = Float(objectInfo[2]),
            let boundingBoxSizeZ = Float(objectInfo[3]),
            let boundingBoxCenterX = Float(objectInfo[4]),
            let boundingBoxCenterY = Float(objectInfo[5]),
            let boundingBoxCenterZ = Float(objectInfo[6]),
            let worldPositionX = Float(objectInfo[7]),
            let worldPositionY = Float(objectInfo[8]),
            let worldPositionZ = Float(objectInfo[9])
        else {
            Self.logger.error("""
                Omniverse's requested shape information is not valid, \
                cannot get bounding box size, bounding box center and world position from Omniverse!
            """)
            return (primPath, primBoundingBox)
        }
        primBoundingBox.boundingBoxSize = simd_float3(
            x: boundingBoxSizeX,
            y: boundingBoxSizeY,
            z: boundingBoxSizeZ
        )
        primBoundingBox.boundingBoxCenter = simd_float3(
            x: boundingBoxCenterX,
            y: boundingBoxCenterY,
            z: boundingBoxCenterZ
        )
        primBoundingBox.worldPosition = simd_float3(
            x: worldPositionX,
            y: worldPositionY,
            z: worldPositionZ
        )
        return (primPath, primBoundingBox)
    }

    private func assignBoxShapeInfo(primPath: String, primBoundingBox: PrimShapeInfoStruct) {
        for entity in omniversePrimEntities {
            guard let component = entity.components[OmniversePrimComponent.self] else {
                Self.logger.error("[assignBoxShapeInfo] Could not find omniverse prim componenent in the entity")
                continue
            }
            defer { entity.components[OmniversePrimComponent.self] = component }
            if primPath == component.primPath {
                component.shapeInfo = primBoundingBox
            }
        }
    }

    private func drawPrimBoundingBox(omniversePrimEntity: Entity, usdInteractionVisualizationEnabled: Bool, sessionEntity: Entity) {
        guard let component = omniversePrimEntity.components[OmniversePrimComponent.self] else {
            Self.logger.error("[drawPrimBoundingBox] Could not find omniverse prim componenent in the entity")
            return
        }
        defer { omniversePrimEntity.components[OmniversePrimComponent.self] = component }
        let primPath = component.primPath

        omniversePrimEntity.position = component.shapeInfo.worldPosition

        component.remoteOmniversePrimTransform = omniversePrimEntity.transform
        component.localOmniversePrimTransform = omniversePrimEntity.transform

        var objectBoundingBoxEntity = Entity()
        if usdInteractionVisualizationEnabled {
            var transparentMaterial = SimpleMaterial()
            transparentMaterial.triangleFillMode = .lines
            transparentMaterial.color = SimpleMaterial.BaseColor(tint: .white)
            objectBoundingBoxEntity = ModelEntity(
                mesh: .generateBox(
                    width: component.shapeInfo.boundingBoxSize.x,
                    height: component.shapeInfo.boundingBoxSize.y,
                    depth: component.shapeInfo.boundingBoxSize.z
                ),
                materials: [transparentMaterial],
                collisionShape: .generateBox(
                    width: component.shapeInfo.boundingBoxSize.x,
                    height: component.shapeInfo.boundingBoxSize.y,
                    depth: component.shapeInfo.boundingBoxSize.z
                ),
                mass: 0.0)
        } else {
            let invisibleBoundingBoxSize = Float(0.000000001)
            objectBoundingBoxEntity = ModelEntity(
                mesh: .generateBox(
                    width: invisibleBoundingBoxSize,
                    height: invisibleBoundingBoxSize,
                    depth: invisibleBoundingBoxSize
                ),
                materials: [SimpleMaterial(color: .clear, isMetallic: true)],
                collisionShape: .generateBox(
                    width: component.shapeInfo.boundingBoxSize.x,
                    height: component.shapeInfo.boundingBoxSize.y,
                    depth: component.shapeInfo.boundingBoxSize.z
                ),
                mass: 0.0)
        }

        objectBoundingBoxEntity.name = primPath

        // Convert the world position of the box entity to the local coordinate system relative to the anchor
        // As the anchor entity is directly attached to the sessionEntity,
        // so the relative world position of anchor antity and box entity can not be directly matched.
        // Therefore, we need to get the world position of box entity after it is attached to sessionEntity first,
        // then covert the world position of box entity to the local coordinate system relative to the anchor
        sessionEntity.addChild(objectBoundingBoxEntity)
        objectBoundingBoxEntity.position = component.shapeInfo.boundingBoxCenter
        let inverseTransform = omniversePrimEntity.transformMatrix(relativeTo: nil).inverse
        let worldPosition = SIMD4<Float>(
            simd_float3(
                objectBoundingBoxEntity.position(relativeTo: nil).x,
                objectBoundingBoxEntity.position(relativeTo: nil).y,
                objectBoundingBoxEntity.position(relativeTo: nil).z
            ),
            1.0
        )
        let localPosition = inverseTransform * worldPosition
        omniversePrimEntity.addChild(objectBoundingBoxEntity)
        objectBoundingBoxEntity.position = simd_float3(localPosition.x, localPosition.y, localPosition.z)
        objectBoundingBoxEntity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    }

    /// Send the transformation matrix to the server.
    private func sendOVTransformation(omniversePrimEntity: Entity, omniversePrimComponent: OmniversePrimComponent, session: Session) {
        var localTransformMatrix = omniversePrimComponent.localOmniversePrimTransform
        var primOVPosition = omniversePrimComponent.shapeInfo.worldPosition

        // If this is a root prim, we need to covert its position to align with OV position
        guard let primParent = omniversePrimEntity.parent else { return }
        if primParent.name != "Session" {
            primOVPosition = simd_float3(0, 0, 0)
        }
        
        // For multiplying 100,  the unit position in Omniverse is 100 times smaller than in Xcode.
        // For subtracting by primOVPosition: In omniverse, if a prim is a root parent, it will set the initial position of the local
        // transform to be zero. But in xcode, the position of the local transform is relative to the sessionEntity, which is the
        // initial world position measured by OV. Therefore, we need to do the subtraction here to align it.
        let eventPositionX = (
            localTransformMatrix.translation.x
            - primOVPosition.x
        ) * 100.0
        let eventPositionY = (
            localTransformMatrix.translation.y
            - primOVPosition.y
        ) * 100.0
        let eventPositionZ = (
            localTransformMatrix.translation.z
            - primOVPosition.z
        ) * 100.0

        localTransformMatrix.translation = simd_float3(eventPositionX, eventPositionY, eventPositionZ)
        session.sendServerMessage(encodeJSON(SetPrimTransformationInputEvent(
            omniversePrimComponent.primPath,
            transformation: localTransformMatrix
        )))
    }

    // TODO: This is internal for tests, but we should not test private methods and test the actual exposed APIs of this class.
    // Make this private when tests are fixed.
    static func assignParentChild(omniversePrimEntity: Entity, objectNameAnchorEntities: [String: Entity]) {
        guard let component = omniversePrimEntity.components[OmniversePrimComponent.self] else {
            Self.logger.error("[assignParentChild] Could not find omniverse prim componenent in the entity")
            return
        }

        // Find the parent if it exists
        let parentPath = findParent(primPath: component.primPath, objectNameAnchorEntities: objectNameAnchorEntities)
        if !parentPath.isEmpty {
            guard let primParent = objectNameAnchorEntities[parentPath] else { return }
            attachToParent(primChild: omniversePrimEntity, primParent: primParent)
        }

        // If the current prim is a root prim, we need to see whether it has children
        let childPaths = findChildren(primPath: component.primPath, objectNameAnchorEntities: objectNameAnchorEntities)
        if !childPaths.isEmpty {
            for childPath in childPaths {
                guard let primChild = objectNameAnchorEntities[childPath] else { return }
                attachToParent(primChild: primChild, primParent: omniversePrimEntity)
            }
        }
    }

    static func findParent(primPath: String, objectNameAnchorEntities: [String: Entity]) -> String {
        var parentPath = ""
        // Sort from long to short, since longer path is closer to the current prim path than the shorter path.
        // For example: Longer path "/car/door/handle" would be the parent of "/car/door/handle/screw" instead of the shorter path "/car/door/".
        let descendingSortedKeys = objectNameAnchorEntities.keys.sorted { $0.count > $1.count }
        for potentialParentName in descendingSortedKeys {
            if primPath.contains(potentialParentName) && primPath != potentialParentName {
                parentPath = potentialParentName
                break
            }
        }
        return parentPath
    }

    static func findChildren(primPath: String, objectNameAnchorEntities: [String: Entity]) -> [String] {
        var childPaths: [String]
        childPaths = []
        // Short to Long. Reason is the same as the "func findParent()".
        let ascendingSortedKeys = objectNameAnchorEntities.keys.sorted { $0.count < $1.count }
        for potentialChildName in ascendingSortedKeys {
            if potentialChildName.contains(primPath) && primPath != potentialChildName {
                var directChild = true
                for path in childPaths where potentialChildName.contains(path) {
                    directChild = false
                    break
                }
                if directChild {
                    childPaths.append(potentialChildName)
                }
            }
        }
        return childPaths
    }

    private static func attachToParent(primChild: Entity, primParent: Entity) {
        // Convert the world position of the child entity to the local coordinate system relative to its parent
        let primPosition = primChild.position(relativeTo: nil)
        let inverseTransform = primParent.transformMatrix(relativeTo: nil).inverse
        let worldPosition = simd_float4(simd_float3(primPosition[0], primPosition[1], primPosition[2]), 1.0)
        let localPosition = inverseTransform * worldPosition
        primChild.position = simd_float3(
            localPosition.x,
            localPosition.y,
            localPosition.z
        )
        guard let component = primChild.components[OmniversePrimComponent.self] else {
            Self.logger.error("[attachToParent] Could not find omniverse prim componenent in the entity")
            return
        }
        defer { primChild.components[OmniversePrimComponent.self] = component }
        component.remoteOmniversePrimTransform = primChild.transform
        primParent.addChild(primChild)
    }

    private static func rateLimiterWait(frequency: Double, lastSentTime: CFTimeInterval) async {
        let targetTime = lastSentTime + 1.0 / frequency
        // Wait enough time if task gets cancelled prematurely.
        while CACurrentMediaTime() < targetTime {
            do {
                try await Task.sleep(for: .nanoseconds(UInt64(max(0, (targetTime - CACurrentMediaTime()) * 1e9))))
            } catch {}
        }
    }
}
