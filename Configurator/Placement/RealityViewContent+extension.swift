//
//  RealityViewContent+extension.swift
//  Configurator
//
//  Created by Reid Ellis on 2024-08-20.
//
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
