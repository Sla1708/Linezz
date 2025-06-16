//
//  FileAttachment.swift
//  Linezz
//
//  Created by Assistant on 12.11.2025.
//

import RealityKit
import SwiftUI
import UniformTypeIdentifiers
import QuickLook

/// Represents different types of files that can be attached to the drawing
enum AttachmentType: Equatable {
    case image(UIImage)
    case model3D(URL)
    case document(URL)
    case unsupported
}

/// A component that represents a file attachment in the drawing space
struct FileAttachmentComponent: Component {
    let id: UUID = UUID()
    let fileName: String
    let fileType: AttachmentType
    let addedDate: Date
    var transform: Transform
    var isSelected: Bool = false
    
    init(fileName: String, fileType: AttachmentType, transform: Transform = Transform()) {
        self.fileName = fileName
        self.fileType = fileType
        self.transform = transform
        self.addedDate = Date()
    }
}

/// Manages file attachments in the drawing space
@MainActor
class FileAttachmentManager: ObservableObject {
    @Published var attachments: [FileAttachmentComponent] = []
    @Published var selectedAttachment: UUID? = nil
    
    private let rootEntity: Entity
    private let canvas: DrawingCanvasSettings
    
    init(rootEntity: Entity, canvas: DrawingCanvasSettings) {
        self.rootEntity = rootEntity
        self.canvas = canvas
    }
    
    /// Adds an image to the drawing space
    func addImage(image: UIImage, fileName: String, at position: SIMD3<Float>) async throws -> Entity {
        let attachment = FileAttachmentComponent(
            fileName: fileName,
            fileType: .image(image),
            transform: Transform(translation: position)
        )
        
        let entity = try await createImageEntity(image: image, attachment: attachment)
        rootEntity.addChild(entity)
        attachments.append(attachment)
        
        return entity
    }
    
    /// Adds a 3D model to the drawing space
    func add3DModel(url: URL, at position: SIMD3<Float>) async throws -> Entity {
        let attachment = FileAttachmentComponent(
            fileName: url.lastPathComponent,
            fileType: .model3D(url),
            transform: Transform(translation: position)
        )
        
        let entity = try await create3DModelEntity(url: url, attachment: attachment)
        rootEntity.addChild(entity)
        attachments.append(attachment)
        
        return entity
    }
    
    /// Adds a document to the drawing space (shows as a preview icon)
    func addDocument(url: URL, at position: SIMD3<Float>) async throws -> Entity {
        let attachment = FileAttachmentComponent(
            fileName: url.lastPathComponent,
            fileType: .document(url),
            transform: Transform(translation: position)
        )
        
        let entity = try await createDocumentEntity(url: url, attachment: attachment)
        rootEntity.addChild(entity)
        attachments.append(attachment)
        
        return entity
    }
    
    /// Creates an entity for displaying an image
    private func createImageEntity(image: UIImage, attachment: FileAttachmentComponent) async throws -> Entity {
        let entity = Entity()
        entity.name = "Image_\(attachment.id)"
        
        // Create a plane mesh for the image
        let aspectRatio = image.size.width / image.size.height
        let width: Float = 0.3 // Default width in meters
        let height = width / Float(aspectRatio)
        
        let mesh = MeshResource.generatePlane(width: width, height: height)
        
        // Create texture from UIImage
        guard let cgImage = image.cgImage else {
            throw AttachmentError.invalidImage
        }
        
        let texture = try await TextureResource(image: cgImage, options: .init(semantic: .color))
        
        var material = SimpleMaterial()
        material.color = .init(texture: .init(texture))
        material.metallic = 0.0
        material.roughness = 1.0
        
        let modelComponent = ModelComponent(mesh: mesh, materials: [material])
        entity.components.set(modelComponent)
        entity.components.set(attachment)
        entity.transform = attachment.transform
        
        // Add collision and input components for manipulation
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: [width, height, 0.01])]))
        entity.components.set(InputTargetComponent())
        
        return entity
    }
    
    /// Creates an entity for displaying a 3D model
    private func create3DModelEntity(url: URL, attachment: FileAttachmentComponent) async throws -> Entity {
        let entity = try await Entity(contentsOf: url)
        entity.name = "Model3D_\(attachment.id)"
        
        entity.components.set(attachment)
        entity.transform = attachment.transform
        
        // Scale the model to fit within reasonable bounds
        let bounds = entity.visualBounds(relativeTo: nil)
        let maxDimension = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        if maxDimension > 0.5 {
            let scale = 0.5 / maxDimension
            entity.scale *= scale
        }
        
        // Add input component for manipulation
        entity.components.set(InputTargetComponent())
        
        return entity
    }
    
    /// Creates an entity for displaying a document preview
    private func createDocumentEntity(url: URL, attachment: FileAttachmentComponent) async throws -> Entity {
        let entity = Entity()
        entity.name = "Document_\(attachment.id)"
        
        // Create a simple box with document icon
        let mesh = MeshResource.generateBox(size: 0.15)
        
        var material = SimpleMaterial()
        material.color = .init(tint: .systemBlue)
        
        let modelComponent = ModelComponent(mesh: mesh, materials: [material])
        entity.components.set(modelComponent)
        entity.components.set(attachment)
        entity.transform = attachment.transform
        
        // Add collision and input components
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: [0.15, 0.15, 0.15])]))
        entity.components.set(InputTargetComponent())
        
        return entity
    }
    
    /// Removes an attachment
    func removeAttachment(id: UUID) {
        attachments.removeAll { $0.id == id }
        
        // Find and remove the entity
        if let entity = rootEntity.children.first(where: { $0.name?.contains(id.uuidString) ?? false }) {
            entity.removeFromParent()
        }
    }
    
    /// Updates the transform of an attachment
    func updateAttachmentTransform(id: UUID, transform: Transform) {
        if let index = attachments.firstIndex(where: { $0.id == id }) {
            attachments[index].transform = transform
            
            // Update the entity transform
            if let entity = rootEntity.children.first(where: { $0.name?.contains(id.uuidString) ?? false }) {
                entity.transform = transform
            }
        }
    }
}

enum AttachmentError: Error {
    case invalidImage
    case unsupportedFileType
    case fileLoadFailed
} 