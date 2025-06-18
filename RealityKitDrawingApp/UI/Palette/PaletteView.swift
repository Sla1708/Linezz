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

/// Defines the interaction mode for the immersive space.
enum InteractionMode: String, CaseIterable, Identifiable {
    case drawing = "Drawing"
    case placement = "Placement"
    
    var id: Self { self }
    
    var systemImage: String {
        switch self {
        case .drawing: return "pencil.and.scribble"
        case .placement: return "move.3d"
        }
    }
}

struct PaletteView: View {
    @Binding var brushState: BrushState
    @Binding var interactionMode: InteractionMode
    var document: DrawingDocument?

    @State private var isClickingButton: Bool = false
    
    // For file pickers
    @State private var showImagePicker = false
    @State private var showFilePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // For error alerts
    @State private var importError: String?
    @State private var showImportErrorAlert = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Palette")
                .font(.largeTitle)
                .padding(.top, 10)
            
            // Interaction Mode Picker
            Picker("Mode", selection: $interactionMode) {
                ForEach(InteractionMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            
            Divider().padding(.horizontal, 20)
            
            // Show brush controls only in drawing mode
            if interactionMode == .drawing {
                BrushTypeView(brushState: $brushState)
                    .padding(.horizontal, 20)

                Divider()

                PresetBrushSelectorView(brushState: $brushState)
                    .frame(minHeight: 125)
                    .padding(.horizontal, 2)
            } else {
                VStack(spacing: 15) {
                    Text("Placement Mode")
                        .font(.title2)
                    Text("Drag to move, or use two hands to scale and rotate imported objects.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .frame(minHeight: 125 + 24 + 160) // Match height of drawing controls area
            }
            
            // File import buttons
            VStack {
                 Divider().padding(.horizontal, 20)
                 Text("Import Content").font(.headline).padding(.top)
                 HStack(spacing: 15) {
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Add Image", systemImage: "photo")
                    }
                    .controlSize(.large)
                    
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Add File", systemImage: "doc.badge.plus")
                    }
                    .controlSize(.large)
                }
            }
            .padding(.bottom)

            Divider().padding(.horizontal, 20)
            
            // Action buttons (Undo, Redo, Clear)
            HStack(spacing: 5) {
                Button {
                    isClickingButton = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        document?.undo()
                        isClickingButton = false
                    }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    isClickingButton = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        document?.redo()
                        isClickingButton = false
                    }
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    isClickingButton = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        Task { await document?.clear() }
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
            .padding([.horizontal, .bottom], 20)
            .onChange(of: isClickingButton) { _, clicking in
                NotificationCenter.default.post(
                    name: clicking ? .pauseDrawing : .resumeDrawing,
                    object: nil
                )
            }
        }
        .glassBackgroundEffect()
        // Photos Picker for images
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) {
            guard let newItem = selectedPhotoItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await document?.addEntity(from: data)
                }
            }
        }
        // File picker for other documents
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.usdz, UTType.usd, UTType.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await document?.addEntity(from: url)
                }
            case .failure(let error):
                importError = "Failed to import file: \(error.localizedDescription)"
                showImportErrorAlert = true
            }
        }
        .alert("Import Error", isPresented: $showImportErrorAlert, presenting: importError) { _ in
            Button("OK") {}
        } message: { error in
            Text(error)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileImportError)) { notification in
            if let errorMessage = notification.object as? String {
                self.importError = errorMessage
                self.showImportErrorAlert = true
            }
        }
    }
}

