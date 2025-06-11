// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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

extension RealityViewContentProtocol {
    func printHierarchy() {
        dprint("RealityViewContent[\(entities.count)]")
        for entity in entities {
            entity.printHierarchy(depth: 1)
        }
    }
}

extension Entity {
    func printHierarchy(depth: Int) {
        dprint("\(String.init(repeating: "\t", count: depth))\(name)[\(children.count)]")
        for child in children {
            child.printHierarchy(depth: depth + 1)
        }
    }
}
