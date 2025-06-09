//
//  DrawingMeshView.swift
//  Linezz
//
//  Created by Sayan on 15.05.2025.
//

import SwiftUI
import RealityKit
import Foundation

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

            // Initialize the DrawingDocument and input provider
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
        // Undo
        .onReceive(NotificationCenter.default.publisher(for: .undoStroke)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await anchorEntityInput?.document.undoLastStroke()
            }
        }
        // Redo
        .onReceive(NotificationCenter.default.publisher(for: .restoreStroke)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await anchorEntityInput?.document.redoLastStroke()
            }
        }
        // Clear
        .onReceive(NotificationCenter.default.publisher(for: .clearCanvas)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await anchorEntityInput?.document.clearAllStrokes()
            }
        }
    }
}

struct DrawingMeshView_Previews: PreviewProvider {
    @State static var brushState = BrushState()
    static var previews: some View {
        DrawingMeshView(
            canvas: DrawingCanvasSettings(),
            brushState: $brushState
        )
    }
}
