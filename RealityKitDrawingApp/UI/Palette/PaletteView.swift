//
//  PaletteView.swift
//  Linezz
//
//  Created by Sayan on 16.05.2025.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Foundation
import PhotosUI
import UniformTypeIdentifiers

struct PaletteView: View {
    @Binding var brushState: BrushState

    // Track when a UI button is being pressed
    @State private var isClickingButton: Bool = false

    // MARK: – New state for image + file pickers
    @State private var showingImagePicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFileImporter: Bool = false
    @State private var selectedFileURL: URL?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Palette")
                    .font(.title)
                    .padding(.leading, 20)
            }

            Divider()
                .padding(.horizontal, 20)

            // Brush types
            BrushTypeView(brushState: $brushState)
                .padding(.horizontal, 20)

            Divider()

            // Preset brushes
            PresetBrushSelectorView(brushState: $brushState)
                .frame(minHeight: 125)
                .padding(.horizontal, 2)

            // Action buttons (Undo, Redo, Clear)
            HStack(spacing: 5) {
                // Undo
                Button {
                    isClickingButton = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .undoStroke, object: nil)
                        isClickingButton = false
                    }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Redo
                Button {
                    isClickingButton = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .restoreStroke, object: nil)
                        isClickingButton = false
                    }
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Clear (wide)
                Button {
                    isClickingButton = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .clearCanvas, object: nil)
                        isClickingButton = false
                    }
                } label: {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
            }
            .padding(.horizontal, 20)
            // Pause/resume drawing input around button-taps
            .onChange(of: isClickingButton) { clicking in
                NotificationCenter.default.post(
                    name: clicking ? .pauseDrawing : .resumeDrawing,
                    object: nil
                )
            }

            // MARK: – New row: Add Image / Add File
            HStack(spacing: 5) {
                Button {
                    showingImagePicker = true
                } label: {
                    Label("Add Image", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showingFileImporter = true
                } label: {
                    Label("Add File", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        // MARK: – Image picker sheet
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    NotificationCenter.default.post(name: .addImage, object: uiImage)
                }
            }
        }
        // MARK: – File importer sheet
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    NotificationCenter.default.post(name: .addFile, object: url)
                }
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
    }
}

struct PaletteView_Previews: PreviewProvider {
    @State static var brushState = BrushState()
    static var previews: some View {
        PaletteView(brushState: $brushState)
            .frame(width: 450, height: 690, alignment: .top)
    }
}
