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
import ARKit

extension GeometrySource {
    func asArray<T>(ofType: T.Type) -> [T] {
        assert(
            MemoryLayout<T>.stride == stride,
            "Invalid stride \(MemoryLayout<T>.stride); expected \(stride)"
        )
        return (0..<count).map {
            buffer.contents().advanced(
                by: offset + stride * Int($0)
            ).assumingMemoryBound(to: T.self).pointee
        }
    }

    func asSIMD3<T>(ofType: T.Type) -> [SIMD3<T>] {
        asArray(ofType: (T, T, T).self).map { .init($0.0, $0.1, $0.2) }
    }

    subscript(_ index: Int32) -> (Float, Float, Float) {
        precondition(
            format == .float3,
            "This subscript operator can only be used on GeometrySource instances with format .float3"
        )
        return buffer.contents().advanced(
            by: offset + (stride * Int(index))
        )
        .assumingMemoryBound(to: (Float, Float, Float).self).pointee
    }
}

extension GeometryElement {
    subscript(_ index: Int) -> [Int32] {
        precondition(
            bytesPerIndex == MemoryLayout<Int32>.size,
            """
This subscript operator can only be used on GeometryElement instances
with bytesPerIndex == \(MemoryLayout<Int32>.size). This GeometryElement
has bytesPerIndex == \(bytesPerIndex)
"""
        )
        var data = [Int32]()
        data.reserveCapacity(primitive.indexCount)
        for indexOffset in 0 ..< primitive.indexCount {
            data.append(
                buffer
                .contents()
                .advanced(by: (Int(index) * primitive.indexCount + indexOffset) * MemoryLayout<Int32>.size)
                .assumingMemoryBound(to: Int32.self)
                .pointee
            )
        }
        return data
    }

    func asInt32Array() -> [Int32] {
        var data = [Int32]()
        let totalNumberOfInt32 = count * primitive.indexCount
        data.reserveCapacity(totalNumberOfInt32)
        for indexOffset in 0 ..< totalNumberOfInt32 {
            data.append(
                buffer
                    .contents()
                    .advanced(by: indexOffset * MemoryLayout<Int32>.size)
                    .assumingMemoryBound(to: Int32.self)
                    .pointee
            )
        }
        return data
    }

    func asUInt16Array() -> [UInt16] { asInt32Array().map { UInt16($0) } }

    public func asUInt32Array() -> [UInt32] { asInt32Array().map { UInt32($0) } }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}

extension simd_float4x4 {
    init(translation vector: simd_float3) {
        self.init(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(vector.x, vector.y, vector.z, 1)
        )
    }

    var translation: simd_float3 {
        get { columns.3.xyz }
        set { columns.3 = [newValue.x, newValue.y, newValue.z, 1] }
    }

    var rotation: simd_quatf { simd_quatf(rotationMatrix) }
    var xAxis: simd_float3 { columns.0.xyz }
    var yAxis: simd_float3 { columns.1.xyz }
    var zAxis: simd_float3 { columns.2.xyz }
    var rotationMatrix: simd_float3x3 { simd_float3x3(xAxis, yAxis, zAxis) }

    /// Get a gravity-aligned copy of this 4x4 matrix.
    var gravityAligned: simd_float4x4 {
        // Project the z-axis onto the horizontal plane and normalize to length 1.
        let projectedZAxis: simd_float3 = [zAxis.x, 0.0, zAxis.z]
        let normalizedZAxis = normalize(projectedZAxis)

        // Hardcode y-axis to point upward.
        let gravityAlignedYAxis: simd_float3 = [0, 1, 0]

        let resultingXAxis = normalize(cross(gravityAlignedYAxis, normalizedZAxis))

        return simd_matrix(
            simd_float4(resultingXAxis.x, resultingXAxis.y, resultingXAxis.z, 0),
            simd_float4(gravityAlignedYAxis.x, gravityAlignedYAxis.y, gravityAlignedYAxis.z, 0),
            simd_float4(normalizedZAxis.x, normalizedZAxis.y, normalizedZAxis.z, 0),
            columns.3
        )
    }
}

extension simd_float2 {
    /// Checks whether this point is inside a given triangle defined by three vertices.
    func isInsideOf(_ vertex1: simd_float2, _ vertex2: simd_float2, _ vertex3: simd_float2) -> Bool {
        // This point lies within the triangle given by v1, v2 & v3
        // if its barycentric coordinates are in range [0, 1].
        let coords = barycentricCoordinatesInTriangle(vertex1, vertex2, vertex3)
        let unitRange = Float(0)...Float(1)
        return unitRange.contains(coords.x) && unitRange.contains(coords.y) && unitRange.contains(coords.z)
    }

    /// Computes the barycentric coordinates of this point relative to a given triangle defined by three vertices.
    func barycentricCoordinatesInTriangle(
        _ vertex1: simd_float2,
        _ vertex2: simd_float2,
        _ vertex3: simd_float2
    ) -> simd_float3 {
        // Compute vectors between the vertices.
        let v2FromV1 = vertex2 - vertex1
        let v3FromV1 = vertex3 - vertex1
        let selfFromV1 = self - vertex1

        // Compute the area of:
        // 1. the passed in triangle,
        // 2. triangle "u" (v1, v3, self) &
        // 3. triangle "v" (v1, v2, self).
        // Note: The area of a triangle is the length of the cross product
        // of the two vectors that span the triangle.
        let areaOverallTriangle = cross(v2FromV1, v3FromV1).z
        let areaU = cross(selfFromV1, v3FromV1).z
        let areaV = cross(v2FromV1, selfFromV1).z

        // The barycentric coordinates of point self are vertices v1, v2 & v3 weighted by (u, v, w).
        // Compute these weights by dividing the triangle’s areas by the overall area.
        let u = areaU / areaOverallTriangle
        let v = areaV / areaOverallTriangle
        let w = 1.0 - v - u
        return [u, v, w]
    }
}

extension PlaneAnchor {
    static let horizontalCollisionGroup = CollisionGroup(rawValue: 1 << 31)
    static let verticalCollisionGroup = CollisionGroup(rawValue: 1 << 30)
    static let allPlanesCollisionGroup: CollisionGroup = [Self.horizontalCollisionGroup, Self.verticalCollisionGroup]
}
