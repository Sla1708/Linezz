//
//  DrawingMeshView.swift
//  Linezz
//
//  Created by Sayan on 15.05.2025.
//

import SwiftUI
import RealityKit

struct DrawingMeshView: View {
    let canvas: DrawingCanvasSettings
    @Binding var brushState: BrushState

    @State private var anchorEntityInput: AnchorEntityInputProvider?
    @State private var isPaused: Bool = false

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
        // Pause drawing input when UI button is pressed
        .onReceive(NotificationCenter.default.publisher(for: .pauseDrawing)) { _ in
            isPaused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .resumeDrawing)) { _ in
            isPaused = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoStroke)) { _ in
            guard !isPaused else { return }
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                await anchorEntityInput?.document.undoLastStroke()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .restoreStroke)) { _ in
            guard !isPaused else { return }
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await anchorEntityInput?.document.redoLastStroke()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearCanvas)) { _ in
            guard !isPaused else { return }
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await anchorEntityInput?.document.clearAllStrokes()
            }
        }
    }
}
