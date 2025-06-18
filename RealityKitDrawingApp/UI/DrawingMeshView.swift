//
//  DrawingMeshView.swift
//  Linezz
//
//  Created by Sayan on 15.05.2025.
//

import SwiftUI
import RealityKit
import Foundation
import UniformTypeIdentifiers

struct DrawingMeshView: View {
    let canvas: DrawingCanvasSettings
    @Binding var brushState: BrushState
    @Binding var interactionMode: InteractionMode
    @Binding var document: DrawingDocument?

    @State private var anchorEntityInput: AnchorEntityInputProvider?

    private let rootEntity = Entity()
    private let inputEntity = Entity()
    
    @State private var isDropTargeted = false
    
    @State private var initialRotation: simd_quatf? = nil
    @State private var initialScale: SIMD3<Float>? = nil

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
            self.document = drawingDocument
            
            content.add(inputEntity)
            anchorEntityInput = await AnchorEntityInputProvider(
                rootEntity: inputEntity,
                document: drawingDocument
            )
        } update: { content in
            document?.interactionMode = interactionMode
            if let anchorEntityInput {
                anchorEntityInput.document.interactionMode = interactionMode
            }
        }
        .gesture(placementGestures)
        .dropDestination(for: URL.self) { urls, location in
            guard let url = urls.first else { return false }
            Task {
                await document?.addEntity(from: url)
            }
            return true
        } isTargeted: {
            isDropTargeted = $0
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoStroke)) { _ in
            document?.undo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .restoreStroke)) { _ in
            document?.redo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearCanvas)) { _ in
            Task { await document?.clear() }
        }
    }
    
    @MainActor
    private var placementGestures: some Gesture {
        let drag = DragGesture(coordinateSpace: .global)
            .targetedToEntity(where: .has(ImportedContentComponent.self))
            .onChanged { value in
                guard interactionMode == .placement else { return }
                value.entity.position = value.convert(value.location3D, from: .global, to: .scene)
            }
        
        let magnify = MagnifyGesture()
            .targetedToEntity(where: .has(ImportedContentComponent.self))
            .onChanged { value in
                guard interactionMode == .placement else { return }
                if initialScale == nil { initialScale = value.entity.scale }
                if let initialScale = initialScale {
                    value.entity.scale = initialScale * Float(value.magnification)
                }
            }
            .onEnded { _ in initialScale = nil }
        
        let rotate = RotateGesture3D()
            .targetedToEntity(where: .has(ImportedContentComponent.self))
            .onChanged { value in
                guard interactionMode == .placement else { return }
                if initialRotation == nil { initialRotation = value.entity.orientation }
                if let initialRotation = initialRotation {
                    let newRotationQuaternion = simd_quatf(value.rotation)
                    value.entity.orientation = newRotationQuaternion * initialRotation
                }
            }
            .onEnded { _ in initialRotation = nil }
            
        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
    }
}

