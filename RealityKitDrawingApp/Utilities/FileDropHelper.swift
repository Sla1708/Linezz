//
//  to.swift
//  Linezz
//
//  Created by Sayan on 16.06.2025.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  FileDropHelper.swift
//  Linezz
//
//  Created by Sayan on 16.06.2025.
//

import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import PhotosUI
import PDFKit

/// A helper class to handle file loading, processing, and entity creation for various file types.
@MainActor
class FileDropHelper {

    /// Processes items from a file importer result.
    static func handleFileImporter(result: Result<URL, Error>) async -> (ModelEntity?, String?) {
        switch result {
        case .success(let url):
            // Ensure we can access the file, especially if it's outside the app's sandbox.
            guard url.startAccessingSecurityScopedResource() else {
                return (nil, "Permission denied for file access.")
            }
            let model = await processItem(url)
            url.stopAccessingSecurityScopedResource()
            return model
        case .failure(let error):
            return (nil, "Error picking file: \(error.localizedDescription)")
        }
    }

    /// Processes an item from the Photos picker.
    static func handlePhotoPicker(item: PhotosPickerItem?) async -> (ModelEntity?, String?) {
        guard let item = item else { return (nil, nil) }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                return await processItem(data)
            }
            return (nil, "Could not load image data.")
        } catch {
            return (nil, "Error loading image: \(error.localizedDescription)")
        }
    }

    /// The core processing function that identifies the item type and calls the appropriate entity creation method.
    static func processItem(_ item: Any) async -> (ModelEntity?, String?) {
        if let data = item as? Data, let uiImage = UIImage(data: data) {
            // Handle raw image data
            return (await createTextureEntity(from: uiImage), nil)
        } else if let url = item as? URL {
            // Handle file URLs
            let type = UTType(filenameExtension: url.pathExtension.lowercased())
            
            if type?.conforms(to: .image) ?? false, let uiImage = UIImage(contentsOfFile: url.path) {
                return (await createTextureEntity(from: uiImage), nil)
            } else if type == .usdz || type?.conforms(to: .threeDContent) ?? false {
                return await createUSDZEntity(from: url)
            } else if type?.conforms(to: .pdf) ?? false {
                return (await createPDFEntity(from: url), nil)
            }
        }
        return (nil, "Unsupported file type.")
    }

    /// Creates a `ModelEntity` with a texture from a `UIImage`. Used for images and PDFs.
    private static func createTextureEntity(from uiImage: UIImage) async -> ModelEntity? {
        guard let cgImage = uiImage.cgImage else { return nil }
        do {
            let texture = try await TextureResource.generate(from: cgImage, options: .init(semantic: .color))
            var material = UnlitMaterial()
            material.color = .init(texture: .init(texture))
            
            // Create a plane with an aspect ratio matching the image, scaled to a reasonable size.
            let aspectRatio = Float(uiImage.size.width / uiImage.size.height)
            let planeMesh = MeshResource.generatePlane(width: 0.5 * aspectRatio, height: 0.5, cornerRadius: 0.02)
            
            let modelEntity = ModelEntity(mesh: planeMesh, materials: [material])
            addManipulationComponents(to: modelEntity)
            return modelEntity
        } catch {
            print("Error creating texture entity: \(error)")
            return nil
        }
    }

    /// Creates a `ModelEntity` by rendering the first page of a PDF file.
    private static func createPDFEntity(from url: URL) async -> ModelEntity? {
        guard let pdfDocument = PDFDocument(url: url),
              let page = pdfDocument.page(at: 0) else { return nil }
        
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let uiImage = renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)
            context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return await createTextureEntity(from: uiImage)
    }

    /// Creates a `ModelEntity` from a USDZ file.
    private static func createUSDZEntity(from url: URL) async -> (ModelEntity?, String?) {
        do {
            let modelEntity = try await ModelEntity(contentsOf: url)
            addManipulationComponents(to: modelEntity)
            return (modelEntity, nil)
        } catch {
            return (nil, "Failed to load USDZ model: \(error.localizedDescription)")
        }
    }

    /// Adds the necessary components to an entity to make it interactive.
    private static func addManipulationComponents(to entity: ModelEntity) {
        // Generate collision shapes for gesture targeting.
        entity.generateCollisionShapes(recursive: true)
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())
    }
}

// Add a specific UTType for USDZ files.
extension UTType {
    public static var usdz: UTType { UTType(filenameExtension: "usdz")! }
}