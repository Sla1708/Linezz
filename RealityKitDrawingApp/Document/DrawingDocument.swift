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
import UniformTypeIdentifiers
import Combine

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
    // MARK: - Properties
    let canvas: DrawingCanvasSettings
    private let brushState: BrushState
    private var startDate: Date

    // Interaction State
    var interactionMode: InteractionMode = .drawing
    private var drawingIsPaused = false
    private var cancellables = Set<AnyCancellable>()

    // Entity Containers
    private let leftRootEntity: Entity
    private let rightRootEntity: Entity
    private let importedContentRootEntity: Entity

    // Drawing Sources & Materials
    private var leftSource: DrawingSource
    private var rightSource: DrawingSource
    private let solidMaterial: RealityKit.Material
    private let sparkleMaterial: RealityKit.Material

    // MARK: - History Management
    
    private enum HistoryItem {
        case stroke(entity: Entity, chirality: Chirality)
        case imported(entity: Entity)
    }
    
    private var historyStack: [HistoryItem] = []
    private var undoneStack: [HistoryItem] = []

    // Track previous drawing state & child counts to detect stroke boundaries
    private var wasDrawing: [Chirality: Bool] = [.left: false, .right: false]
    private var previousChildCount: [Chirality: Int] = [.left: 0, .right: 0]

    // MARK: - Initialization
    init(rootEntity: Entity, brushState: BrushState, canvas: DrawingCanvasSettings) async {
        self.canvas = canvas
        self.brushState = brushState
        self.startDate = .now

        // Set up containers for left/right hands and imported content
        self.leftRootEntity = Entity()
        self.rightRootEntity = Entity()
        self.importedContentRootEntity = Entity()
        rootEntity.addChild(leftRootEntity)
        rootEntity.addChild(rightRootEntity)
        rootEntity.addChild(importedContentRootEntity)
        
        // Load materials...
        var solidMat: RealityKit.Material = SimpleMaterial()
        if let m = try? await ShaderGraphMaterial(named: "/Root/Material", from: "SolidBrushMaterial", in: realityKitContentBundle) {
            solidMat = m
        }

        var sparkleMat: RealityKit.Material = SimpleMaterial()
        if var m = try? await ShaderGraphMaterial(named: "/Root/SparkleBrushMaterial", from: "SparkleBrushMaterial", in: realityKitContentBundle) {
            m.writesDepth = false
            try? m.setParameter(name: "ParticleUVScale", value: .float(8))
            sparkleMat = m
        }

        self.solidMaterial = solidMat
        self.sparkleMaterial = sparkleMat

        // Create the two DrawingSource instances
        self.leftSource = await DrawingSource(rootEntity: leftRootEntity, solidMaterial: solidMat, sparkleMaterial: sparkleMat)
        self.rightSource = await DrawingSource(rootEntity: rightRootEntity, solidMaterial: solidMat, sparkleMaterial: sparkleMat)
        
        // Initialize trackers and notification listeners
        self.wasDrawing = [.left: false, .right: false]
        self.previousChildCount = [.left: leftRootEntity.children.count, .right: rightRootEntity.children.count]
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        NotificationCenter.default.publisher(for: .pauseDrawing)
            .sink { [weak self] _ in self?.drawingIsPaused = true }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .resumeDrawing)
            .sink { [weak self] _ in self?.drawingIsPaused = false }
            .store(in: &cancellables)
    }

    // MARK: - Drawing Input
    func receive(input: InputData?, chirality: Chirality) {
        // Only process drawing if in the correct mode and not paused.
        guard interactionMode == .drawing, !drawingIsPaused else {
            // Finalize any active strokes if mode is changed while drawing.
            leftSource.receive(input: nil, time: 0, state: brushState)
            rightSource.receive(input: nil, time: 0, state: brushState)
            return
        }

        var safeInput = input
        if let tip = input?.brushTip, !canvas.isInsideCanvas(tip) {
            safeInput = nil
        }
        
        let elapsed = startDate.distance(to: .now)
        switch chirality {
        case .left: leftSource.receive(input: safeInput, time: elapsed, state: brushState)
        case .right: rightSource.receive(input: safeInput, time: elapsed, state: brushState)
        }
        
        // Check for stroke boundaries to manage history
        let currentlyDrawing = safeInput?.isDrawing == true
        if (wasDrawing[chirality] == true) && !currentlyDrawing {
            let root = (chirality == .left ? leftRootEntity : rightRootEntity)
            let prevCount = previousChildCount[chirality] ?? 0
            if root.children.count > prevCount {
                root.children[prevCount...].forEach {
                    historyStack.append(.stroke(entity: $0, chirality: chirality))
                }
                undoneStack.removeAll() // New action clears redo history
            }
            previousChildCount[chirality] = root.children.count
        }
        wasDrawing[chirality] = currentlyDrawing
    }
    
    // MARK: - Content Import

    /// Creates an entity directly from image data (for PhotosPicker).
    func addEntity(from imageData: Data) async {
        do {
            let entity = try await createEntityFromImageData(imageData)
            addImportedEntityToScene(entity, sourceURL: nil)
        } catch {
            postError("Error creating entity from image data: \(error.localizedDescription)")
        }
    }
    
    /// Creates an entity from a file URL (for FileImporter and Drag & Drop).
    func addEntity(from url: URL) async {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        
        guard let localURL = copyToLocalStorage(from: url) else {
            postError("Could not copy file to app storage.")
            return
        }

        do {
            let entity: Entity
            if url.pathExtension.lowercased() == "usdz" || url.pathExtension.lowercased() == "usda" || url.pathExtension.lowercased() == "usd" {
                entity = try await Entity(contentsOf: localURL)
                entity.generateCollisionShapes(recursive: true, static: false)
            } else {
                let data = try Data(contentsOf: localURL)
                entity = try await createEntityFromImageData(data)
            }
            addImportedEntityToScene(entity, sourceURL: localURL)
        } catch {
            var detailedMessage = "Error creating entity: \(error.localizedDescription)"
            if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
                detailedMessage += "\n\nUnderlying reason: \((underlyingError as NSError).localizedDescription)"
            }
            postError(detailedMessage)
        }
    }

    private func createEntityFromImageData(_ data: Data) async throws -> Entity {
        guard let uiImage = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
        let texture = try await TextureResource.generate(from: uiImage.cgImage!, options: .init(semantic: .color))
        var material = UnlitMaterial()
        material.color = .init(texture: .init(texture))
        let aspectRatio = uiImage.size.height > 0 ? Float(uiImage.size.width / uiImage.size.height) : 1.0
        return ModelEntity(mesh: .generatePlane(width: 0.5 * aspectRatio, height: 0.5), materials: [material])
    }
    
    private func addImportedEntityToScene(_ entity: Entity, sourceURL: URL?) {
        entity.name = "Imported Content"
        entity.components.set(ImportedContentComponent(sourceURL: sourceURL))
        entity.components.set(InputTargetComponent(allowedInputTypes: .all))
        if entity.components[CollisionComponent.self] == nil {
             entity.components.set(CollisionComponent(shapes: [entity.visualBounds(relativeTo: entity).toShapeResource()], mode: .trigger, filter: .default))
        }
        entity.components.set(HoverEffectComponent())
        entity.position = canvas.placementPosition + [0, 1.5, -1]
        
        importedContentRootEntity.addChild(entity)
        historyStack.append(.imported(entity: entity))
        undoneStack.removeAll()
        
        NotificationCenter.default.post(name: .fileAdded, object: entity)
    }
    
    // MARK: - Actions & Helpers

    func undo() {
        guard let lastItem = historyStack.popLast() else { return }
        
        switch lastItem {
        case .stroke(let entity, _):
            entity.isEnabled = false
        case .imported(let entity):
            entity.isEnabled = false
        }
        undoneStack.append(lastItem)
    }
    
    func redo() {
        guard let lastUndone = undoneStack.popLast() else { return }

        switch lastUndone {
        case .stroke(let entity, _):
            entity.isEnabled = true
        case .imported(let entity):
            entity.isEnabled = true
        }
        historyStack.append(lastUndone)
    }
    
    func clear() async {
        leftRootEntity.children.forEach { $0.removeFromParent() }
        rightRootEntity.children.forEach { $0.removeFromParent() }
        importedContentRootEntity.children.forEach { $0.removeFromParent() }

        historyStack.removeAll()
        undoneStack.removeAll()

        leftSource = await DrawingSource(rootEntity: leftRootEntity, solidMaterial: solidMaterial, sparkleMaterial: sparkleMaterial)
        rightSource = await DrawingSource(rootEntity: rightRootEntity, solidMaterial: solidMaterial, sparkleMaterial: sparkleMaterial)
        
        previousChildCount = [.left: 0, .right: 0]
        wasDrawing = [.left: false, .right: false]
    }
    
    private func copyToLocalStorage(from sourceURL: URL) -> URL? {
        do {
            let fileManager = FileManager.default
            let docsDir = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let destinationURL = docsDir.appendingPathComponent(UUID().uuidString + "-" + sourceURL.lastPathComponent)
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("[DrawingDocument] Error copying file to local storage: \(error)")
            return nil
        }
    }

    private func postError(_ message: String) {
        NotificationCenter.default.post(name: .fileImportError, object: message)
    }
}

private extension BoundingBox {
    func toShapeResource() -> ShapeResource {
        return .generateBox(size: self.extents)
    }
}
