//
//  DrawingMeshView.swift
//  Linezz
//
//  Created by Sayan on 15.05.2025.
//

import SwiftUI
import RealityKit
import Foundation
import PhotosUI
import UniformTypeIdentifiers

struct DrawingMeshView: View {
    let canvas: DrawingCanvasSettings
    @Binding var brushState: BrushState

    @State private var anchorEntityInput: AnchorEntityInputProvider?

    // The root for all drawn content, including strokes and added files.
    private let rootEntity  = Entity()
    private let inputEntity = Entity()

    // MARK: - State for File & Lock Handling

    /// This array serves as the log/history of all user-added files.
    @State private var userAddedEntities: [Entity] = []

    // State for file pickers
    @State private var isShowingPhotoPicker = false
    @State private var isShowingFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    // State for error alerts
    @State private var errorMessage: String?
    @State private var isShowingErrorAlert = false

    // State for entity selection and the lock/delete popover
    @State private var selectedEntity: Entity?
    @State private var isLockPopoverPresented = false

    /// A tap gesture to select an entity and show the action popover.
    private var tapToSelectGesture: some Gesture {
        TapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                // Ensure the tapped entity is a user-added, lockable object.
                guard value.entity.components.has(LockableComponent.self) else { return }

                self.selectedEntity = value.entity
                self.isLockPopoverPresented = true
            }
    }

    var body: some View {
        RealityView { content in
            // Register all necessary systems.
            SolidBrushSystem.registerSystem()
            SparkleBrushSystem.registerSystem()
            TwoHandManipulationSystem.registerSystem()

            // Register all necessary components.
            SolidBrushComponent.registerComponent()
            SparkleBrushComponent.registerComponent()
            LockableComponent.registerComponent()
            TwoHandMoveableComponent.registerComponent()

            rootEntity.position = .zero
            content.add(rootEntity)

            // Add any entities that might already be in our log.
            for entity in userAddedEntities {
                content.add(entity)
            }

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
        // The single-finger drag gesture has been removed.
        // We only need the tap gesture for selection now.
        .gesture(tapToSelectGesture)

        // MARK: - Modifiers for File Handling and Locking

        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                let (entity, error) = await FileDropHelper.handlePhotoPicker(item: newItem)
                handleEntityCreation(entity: entity, error: error)
            }
        }

        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.image, .usdz, .pdf],
            allowsMultipleSelection: false
        ) { result in
            Task {
                // Map Result<[URL], Error> -> Result<URL, Error>
                let singleResult: Result<URL, Error> = {
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            return .success(url)
                        } else {
                            return .failure(NSError(domain: "FileImporter",
                                                    code: -1,
                                                    userInfo: [NSLocalizedDescriptionKey: "No file selected."]))
                        }
                    case .failure(let err):
                        return .failure(err)
                    }
                }()
                let (entity, error) = await FileDropHelper.handleFileImporter(result: singleResult)
                handleEntityCreation(entity: entity, error: error)
            }
        }

        .dropDestination(for: URL.self) { items, location in
            guard let url = items.first else { return false }
            Task {
                let (entity, error) = await FileDropHelper.processItem(url)
                handleEntityCreation(entity: entity, error: error)
            }
            return true
        }
        .dropDestination(for: Data.self) { items, location in
            guard let data = items.first else { return false }
            Task {
                let (entity, error) = await FileDropHelper.processItem(data)
                handleEntityCreation(entity: entity, error: error)
            }
            return true
        }

        .popover(isPresented: $isLockPopoverPresented) {
            if let entity = selectedEntity {
                VStack(spacing: 12) {
                    Button(entity.components[LockableComponent.self]?.isLocked == true ? "Unlock" : "Lock") {
                        toggleLock(for: entity)
                        isLockPopoverPresented = false
                    }

                    Divider()

                    Button("Delete", role: .destructive) {
                        deleteEntity(entity)
                        isLockPopoverPresented = false
                    }
                }
                .padding()
                .frame(minWidth: 150)
                .glassBackgroundEffect()
            }
        }

        .alert(isPresented: $isShowingErrorAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? "An unknown error occurred."), dismissButton: .default(Text("OK")))
        }

        // MARK: - Notification Receivers

        .onReceive(NotificationCenter.default.publisher(for: .presentPhotoPicker)) { _ in isShowingPhotoPicker = true }
        .onReceive(NotificationCenter.default.publisher(for: .presentFileImporter)) { _ in isShowingFileImporter = true }
        .onReceive(NotificationCenter.default.publisher(for: .showErrorAlert)) { notification in
            if let message = notification.object as? String {
                self.errorMessage = message
                self.isShowingErrorAlert = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoStroke)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await anchorEntityInput?.document.undoLastStroke()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .restoreStroke)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await anchorEntityInput?.document.redoLastStroke()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearCanvas)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await anchorEntityInput?.document.clearAllStrokes()
                // Also remove all user-added files and clear selection.
                for entity in userAddedEntities {
                    entity.removeFromParent()
                }
                userAddedEntities.removeAll()
                selectedEntity = nil
            }
        }
    }

    // MARK: - Helper Functions

    /// Handles the result from a file helper, adding the entity to the scene or showing an error.
    private func handleEntityCreation(entity: Entity?, error: String?) {
        if let entity = entity {
            addEntityToScene(entity)
        } else if let error = error {
            errorMessage = error
            isShowingErrorAlert = true
        }
    }

    /// Adds a new entity to the scene and the history log.
    private func addEntityToScene(_ entity: Entity) {
        // Position the new entity in a default location in front of the user.
        entity.position = [0, 1, -1.5]

        // Add to our log and to the main scene graph.
        userAddedEntities.append(entity)
        rootEntity.addChild(entity)
    }

    /// Toggles the lock state of the given entity.
    private func toggleLock(for entity: Entity) {
        guard var lockable = entity.components[LockableComponent.self] else { return }

        lockable.isLocked.toggle()

        // Provide visual feedback for the locked state.
        if lockable.isLocked {
            // Remove the hover effect to indicate it's not interactive for movement.
            entity.components.remove(HoverEffectComponent.self)
        } else {
            // Add the hover effect back.
            entity.components.set(HoverEffectComponent())
        }

        // Update the component on the entity.
        entity.components.set(lockable)
    }

    /// Deletes an entity from the scene and our tracking array.
    private func deleteEntity(_ entity: Entity) {
        entity.removeFromParent()
        userAddedEntities.removeAll { $0.id == entity.id }
        selectedEntity = nil
    }
}
