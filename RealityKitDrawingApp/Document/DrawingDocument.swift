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

    // MARK: – Undo/Redo stacks
    private var strokeStack: [(entity: Entity, chirality: Chirality)] = []
    private var undoneStack: [(entity: Entity, chirality: Chirality)] = []

    // Track previous drawing state & child counts to detect stroke boundaries
    private var wasDrawing: [Chirality: Bool] = [.left: false, .right: false]
    private var previousChildCount: [Chirality: Int] = [.left: 0, .right: 0]

    init(rootEntity: Entity, brushState: BrushState, canvas: DrawingCanvasSettings) async {
        self.canvas = canvas
        self.brushState = brushState
        self.startDate = .now

        // Set up left/right containers
        self.leftRootEntity = Entity()
        self.rightRootEntity = Entity()
        rootEntity.addChild(leftRootEntity)
        rootEntity.addChild(rightRootEntity)

        // Load materials...
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

        // Create the two DrawingSource instances
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

        // Initialize our tracking dictionaries
        wasDrawing[.left] = false
        wasDrawing[.right] = false
        previousChildCount[.left] = leftRootEntity.children.count
        previousChildCount[.right] = rightRootEntity.children.count
    }

    func receive(input: InputData?, chirality: Chirality) {
        // 1. Detect whether the brush-tip left the canvas
        var safeInput = input
        if let tip = input?.brushTip, !canvas.isInsideCanvas(tip) {
            safeInput = nil
        }

        // 2. Call through to the real drawing logic
        let elapsed = startDate.distance(to: .now)
        switch chirality {
        case .left:
            leftSource.receive(input: safeInput, time: elapsed, state: brushState)
        case .right:
            rightSource.receive(input: safeInput, time: elapsed, state: brushState)
        }

        // 3. Check for stroke boundaries
        let currentlyDrawing = safeInput?.isDrawing == true
        let previouslyDrawing = wasDrawing[chirality] ?? false

        // If we just lifted (true→false), record new stroke(s)
        if previouslyDrawing && !currentlyDrawing {
            // grab any new child-entities as this stroke
            let root = (chirality == .left ? leftRootEntity : rightRootEntity)
            let prevCount = previousChildCount[chirality] ?? 0
            let allChildren = root.children
            if allChildren.count > prevCount {
                let newEntities = allChildren[prevCount...]
                for entity in newEntities {
                    strokeStack.append((entity: entity, chirality: chirality))
                }
                // any time you draw something new, you clear the redo history
                undoneStack.removeAll()
            }
            previousChildCount[chirality] = allChildren.count
        }

        // 4. Update tracking
        wasDrawing[chirality] = currentlyDrawing
    }

    /// Deletes the most recently completed stroke.
    func undoLastStroke() async {
        guard let last = strokeStack.popLast() else { return }
        let (entity, hand) = last

        // remove it from its parent
        switch hand {
        case .left: leftRootEntity.removeChild(entity)
        case .right: rightRootEntity.removeChild(entity)
        }

        // push onto redo stack
        undoneStack.append(last)
    }

    /// Re‑adds whatever stroke was most recently undone.
    func redoLastStroke() async {
        guard let lastUndone = undoneStack.popLast() else { return }
        let (entity, hand) = lastUndone

        // re-add to the correct root
        switch hand {
        case .left: leftRootEntity.addChild(entity)
        case .right: rightRootEntity.addChild(entity)
        }

        // move back onto the done stack
        strokeStack.append(lastUndone)
    }

    /// Clears everything (and resets undo/redo history).
    func clearAllStrokes() async {
        // remove all children
        leftRootEntity.children.forEach { leftRootEntity.removeChild($0) }
        rightRootEntity.children.forEach { rightRootEntity.removeChild($0) }

        // rebuild sources
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

        // reset stacks and trackers
        strokeStack.removeAll()
        undoneStack.removeAll()
        previousChildCount[.left] = 0
        previousChildCount[.right] = 0
        wasDrawing[.left] = false
        wasDrawing[.right] = false
    }
}
