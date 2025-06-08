//
//  DrawingDocument.swift
//  Linezz
//
//  Created by Sayan on 25.05.2025.
//

import Collections
import RealityKit
import RealityKitContent
import SwiftUI

enum Chirality: Equatable {
    case left, right
}

struct InputData {
    var thumbTip: SIMD3<Float>
    var indexFingerTip: SIMD3<Float>
    var brushTip: SIMD3<Float> { (thumbTip + indexFingerTip) / 2 }
    var isDrawing: Bool { distance(thumbTip, indexFingerTip) < 0.015 }
}

@MainActor
class DrawingDocument {
    let canvas: DrawingCanvasSettings

    private let brushState: BrushState
    private var startDate: Date

    private let leftRootEntity: Entity
    private let rightRootEntity: Entity

    private var leftSource: DrawingSource
    private var rightSource: DrawingSource

    private let solidMaterial: RealityKit.Material
    private let sparkleMaterial: RealityKit.Material

    init(rootEntity: Entity, brushState: BrushState, canvas: DrawingCanvasSettings) async {
        self.canvas = canvas
        self.brushState = brushState
        self.startDate = .now

        self.leftRootEntity = Entity()
        self.rightRootEntity = Entity()
        rootEntity.addChild(leftRootEntity)
        rootEntity.addChild(rightRootEntity)

        var solidMat: RealityKit.Material = SimpleMaterial()
        if let m = try? await ShaderGraphMaterial(
            named: "/Root/Material",
            from: "SolidBrushMaterial",
            in: realityKitContentBundle
        ) {
            solidMat = m
        }

        var sparkleMat: RealityKit.Material = SimpleMaterial()
        if var m = try? await ShaderGraphMaterial(
            named: "/Root/SparkleBrushMaterial",
            from: "SparkleBrushMaterial",
            in: realityKitContentBundle
        ) {
            m.writesDepth = false
            try? m.setParameter(name: "ParticleUVScale", value: .float(8))
            sparkleMat = m
        }

        self.solidMaterial = solidMat
        self.sparkleMaterial = sparkleMat

        self.leftSource = await DrawingSource(
            rootEntity: leftRootEntity,
            solidMaterial: solidMat,
            sparkleMaterial: sparkleMat
        )
        self.rightSource = await DrawingSource(
            rootEntity: rightRootEntity,
            solidMaterial: solidMat,
            sparkleMaterial: sparkleMat
        )
    }

    func receive(input: InputData?, chirality: Chirality) {
        var input = input
        if let tip = input?.brushTip, !canvas.isInsideCanvas(tip) {
            input = nil
        }
        let elapsed = startDate.distance(to: .now)
        switch chirality {
        case .left:
            leftSource.receive(input: input, time: elapsed, state: brushState)
        case .right:
            rightSource.receive(input: input, time: elapsed, state: brushState)
        }
    }

    func clearAllStrokes() async {
        leftRootEntity.children.forEach { leftRootEntity.removeChild($0) }
        rightRootEntity.children.forEach { rightRootEntity.removeChild($0) }

        leftSource = await DrawingSource(
            rootEntity: leftRootEntity,
            solidMaterial: solidMaterial,
            sparkleMaterial: sparkleMaterial
        )
        rightSource = await DrawingSource(
            rootEntity: rightRootEntity,
            solidMaterial: solidMaterial,
            sparkleMaterial: sparkleMaterial
        )
    }

    func undoLastStroke() async {
    }

    func redoLastStroke() async {
    }
}

