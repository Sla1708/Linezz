//
//  DrawingMeshView.swift
//  Linezz
//
//  Created by Sayan on 15.05.2025.
//

import Foundation
import SwiftUI
import Combine
import RealityKit
import RealityKitContent

struct DrawingMeshView: View {
    let canvas: DrawingCanvasSettings
    @Binding var brushState: BrushState

    @State private var anchorEntityInput: AnchorEntityInputProvider?

    private let rootEntity  = Entity()
    private let inputEntity = Entity()

    var body: some View {
        RealityView { content in
            SolidBrushSystem.registerSystem()
            SparkleBrushSystem.registerSystem()
            SolidBrushComponent.registerComponent()
            SparkleBrushComponent.registerComponent()

            rootEntity.position = .zero
            content.add(rootEntity)

            let drawingDocument = await DrawingDocument(
                rootEntity: rootEntity,
                brushState: brushState,
                canvas: canvas
            )
            content.add(inputEntity)
            anchorEntityInput = await AnchorEntityInputProvider(
                rootEntity: inputEntity,
                document: drawingDocument
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoStroke)) { _ in
            Task { await anchorEntityInput?.document.undoLastStroke() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .restoreStroke)) { _ in
            Task { await anchorEntityInput?.document.redoLastStroke() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearCanvas)) { _ in
            Task { await anchorEntityInput?.document.clearAllStrokes() }
        }
    }
}

