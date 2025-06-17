//
//  FilePickerView.swift
//  Linezz
//
//  Created by Assistant on 12.11.2025.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct FilePickerView: View {
    @Binding var isPresented: Bool
    let onSelection: (URL?, UIImage?, String) -> Void
    
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var showDocumentPicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select a file to add to your drawing")
                    .font(.headline)
                    .padding(.top)
                
                // Image Picker
                PhotosPicker(
                    selection: $selectedImage,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Choose Image", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .onChange(of: selectedImage) { newItem in
                    Task {
                        await loadImage(from: newItem)
                    }
                }
                
                // 3D Model Picker
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Choose 3D Model", systemImage: "cube")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Document Picker
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Choose Document", systemImage: "doc")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Add File")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(
                allowedContentTypes: [.usdz, .pdf, .image, .text],
                onPick: { url in
                    handleFileSelection(url: url)
                }
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    let fileName = item.itemIdentifier ?? "Image_\(UUID().uuidString)"
                    DispatchQueue.main.async {
                        onSelection(nil, uiImage, fileName)
                        isPresented = false
                    }
                }
            }
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func handleFileSelection(url: URL) {
        let fileName = url.lastPathComponent
        
        // Check file type
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "usdz", "usda", "usdc":
            // 3D Model
            onSelection(url, nil, fileName)
            isPresented = false
            
        case "jpg", "jpeg", "png", "gif", "heic":
            // Image
            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    onSelection(nil, image, fileName)
                    isPresented = false
                }
            } catch {
                errorMessage = "Failed to load image: \(error.localizedDescription)"
                showError = true
            }
            
        case "pdf", "txt", "doc", "docx":
            // Document
            onSelection(url, nil, fileName)
            isPresented = false
            
        default:
            errorMessage = "Unsupported file type: .\(fileExtension)"
            showError = true
        }
    }
}

// Document picker wrapper
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
} 