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

/// Which hand the input came from.
enum Chirality: Equatable {
    case left, right
}

/// Data about the current user input.
struct InputData {
    /// Location of the thumb tip `AnchorEntity`.
    var thumbTip: SIMD3<Float>
    /// Location of the index finger tip `AnchorEntity`.
    var indexFingerTip: SIMD3<Float>
    /// The point between thumb and index finger—where the “brush” is.
    var brushTip: SIMD3<Float> { (thumbTip + indexFingerTip) / 2 }
    /// True if the tip is pinched close enough to draw.
    var isDrawing: Bool { distance(thumbTip, indexFingerTip) < 0.015 }
}

/// Manages the state of the drawing (brushes, canvas, and RealityKit entities).
@MainActor
class DrawingDocument {
    // ── Publicly consumed by views ─────────────────────────────────────────────
    /// The user’s chosen canvas (size + placement).
    let canvas: DrawingCanvasSettings

    // ── Internal state ────────────────────────────────────────────────────────
    private let brushState: BrushState
    private var startDate: Date

    /// Two “buckets” for left‑ and right‑hand strokes.
    private let leftRootEntity: Entity
    private let rightRootEntity: Entity

    /// The current brush generators.
    private var leftSource: DrawingSource
    private var rightSource: DrawingSource

    /// Loaded materials, for re‑building on clear.
    private let solidMaterial: RealityKit.Material
    private let sparkleMaterial: RealityKit.Material

    // ── Initialization ───────────────────────────────────────────────────────
    init(rootEntity: Entity,
         brushState: BrushState,
         canvas: DrawingCanvasSettings) async
    {
        self.canvas = canvas
        self.brushState = brushState
        self.startDate  = .now

        // Create two empty containers for strokes
        self.leftRootEntity  = Entity()
        self.rightRootEntity = Entity()
        rootEntity.addChild(leftRootEntity)
        rootEntity.addChild(rightRootEntity)

        // Load or fall back to a simple material for solid brush
        var solidMat: RealityKit.Material = SimpleMaterial()
        if let m = try? await ShaderGraphMaterial(
            named: "/Root/Material",
            from: "SolidBrushMaterial",
            in: realityKitContentBundle
        ) {
            solidMat = m
        }

        // Load sparkle brush material
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

        self.solidMaterial   = solidMat
        self.sparkleMaterial = sparkleMat

        // Create DrawingSource instances
        self.leftSource  = await DrawingSource(
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

    // ── Feeding in per‐frame input ─────────────────────────────────────────────
    /// Called each frame with the current hand input.
    func receive(input: InputData?, chirality: Chirality) {
        var input = input
        // discard input if outside the canvas
        if let tip = input?.brushTip, !canvas.isInsideCanvas(tip) {
            input = nil
        }
        let time = startDate.distance(to: .now)
        switch chirality {
        case .left:
            leftSource.receive(input: input, time: time, state: brushState)
        case .right:
            rightSource.receive(input: input, time: time, state: brushState)
        }
    }

    // ── Clear API ─────────────────────────────────────────────────────────────
    /// Remove all existing strokes and reset both brush sources.
    func clearAllStrokes() async {
        // Remove every child under each bucket
        leftRootEntity.children.forEach  { leftRootEntity.removeChild($0) }
        rightRootEntity.children.forEach { rightRootEntity.removeChild($0) }

        // Re-create the sources into those same empty entities
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
}


