//
//  Placement+Extensions.swift
//  CloudXRViewer
//
//  Created by Reid Ellis on 2024-07-16.
//

import simd
import Spatial
import RealityKit

public extension simd_float3 {
    static var xAxis: simd_float3 { [1, 0, 0] }
    static var yAxis: simd_float3 { [0, 1, 0] }
    static var zAxis: simd_float3 { [0, 0, 1] }
}

public extension simd_float4x4 {
    static var identity: simd_float4x4 { matrix_identity_float4x4 }
    static var zero: simd_float4x4 { simd_float4x4() }

    init(radians: Float, axis: simd_float3) {
        let quat = simd_quatf(angle: radians, axis: axis)
        self.init(quat)
    }

    static func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
        var matrix: simd_float4x4 = .identity
        matrix[3] = [x, y, z, 1.0]
        return matrix
    }
}

public extension simd_quatf {
    static var identity = simd_quatf.init(matrix_float4x4.identity)
}
