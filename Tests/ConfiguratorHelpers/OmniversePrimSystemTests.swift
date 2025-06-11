import XCTest
import RealityKit
import simd
@testable import Configurator

final class OmniversePrimSystemTests: XCTestCase {
    // MARK: - Parent-Child Relationship Tests
    
    func testFindParent() {
        // Create test entities
        let entities: [String: Entity] = [
            "/car": Entity(),
            "/car/door": Entity(),
            "/car/door/handle": Entity(),
            "/car/door/handle/screw": Entity()
        ]
        
        // Test finding parent for different paths
        XCTAssertEqual(
            OmniversePrimSystem.findParent(primPath: "/car/door/handle/screw", objectNameAnchorEntities: entities),
            "/car/door/handle",
            "Should find immediate parent"
        )
        
        XCTAssertEqual(
            OmniversePrimSystem.findParent(primPath: "/car/door", objectNameAnchorEntities: entities),
            "/car",
            "Should find parent for middle-level entity"
        )
        
        XCTAssertEqual(
            OmniversePrimSystem.findParent(primPath: "/car", objectNameAnchorEntities: entities),
            "",
            "Root entity should have no parent"
        )
    }
    
    func testFindChildren() {
        // Create test entities
        let entities: [String: Entity] = [
            "/car": Entity(),
            "/car/door": Entity(),
            "/car/engine": Entity(),
            "/car/door/handle": Entity(),
            "/car/door/window": Entity()
        ]
        
        // Test finding children for different paths
        let carChildren = OmniversePrimSystem.findChildren(primPath: "/car", objectNameAnchorEntities: entities)
        XCTAssertEqual(carChildren.count, 2)
        XCTAssertTrue(carChildren.contains("/car/door"))
        XCTAssertTrue(carChildren.contains("/car/engine"))
        
        let doorChildren = OmniversePrimSystem.findChildren(primPath: "/car/door", objectNameAnchorEntities: entities)
        XCTAssertEqual(doorChildren.count, 2)
        XCTAssertTrue(doorChildren.contains("/car/door/handle"))
        XCTAssertTrue(doorChildren.contains("/car/door/window"))
        
        let handleChildren = OmniversePrimSystem.findChildren(primPath: "/car/door/handle", objectNameAnchorEntities: entities)
        XCTAssertTrue(handleChildren.isEmpty, "Leaf node should have no children")
    }
    
    // MARK: - Shape Info Tests
    
    func testProcessBoxShapeInfo() {
        let boundingBoxString = [
            "/car/door, 1.0, 2.0, 3.0, 0.5, 1.0, 1.5, 10.0, 20.0, 30.0"
        ]
        
        let (primPath, shapeInfo) = OmniversePrimSystem.processBoxShapeInfo(boundingBoxString: boundingBoxString)
        
        XCTAssertEqual(primPath, "/car/door")
        XCTAssertEqual(shapeInfo.boundingBoxSize, simd_float3(1.0, 2.0, 3.0))
        XCTAssertEqual(shapeInfo.boundingBoxCenter, simd_float3(0.5, 1.0, 1.5))
        XCTAssertEqual(shapeInfo.worldPosition, simd_float3(10.0, 20.0, 30.0))
    }
    
    func testProcessBoxShapeInfoWithInvalidData() {
        let boundingBoxString = [
            "/car/door, invalid, 2.0, 3.0, 0.5, 1.0, 1.5, 10.0, 20.0, 30.0"
        ]
        
        let (primPath, shapeInfo) = OmniversePrimSystem.processBoxShapeInfo(boundingBoxString: boundingBoxString)
        
        XCTAssertEqual(primPath, "/car/door")
        XCTAssertEqual(shapeInfo.boundingBoxSize, simd_float3(0, 0, 0))
        XCTAssertEqual(shapeInfo.boundingBoxCenter, simd_float3(0, 0, 0))
        XCTAssertEqual(shapeInfo.worldPosition, simd_float3(0, 0, 0))
    }
} 
