//
//  PaletteView.swift
//  Linezz
//
//  Created by Sayan on 16.05.2025.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Foundation   // for NotificationCenter

struct PaletteView: View {
    @Binding var brushState: BrushState

    /// Temporarily track when a UI button is being pressed
    @State private var isClickingButton: Bool = false
    @State private var isSettingsPopoverPresented: Bool = false

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
                    Label("Redo", systemImage: "arrow.uturn.right")
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
            // Broadcast pause/resume when interacting with UI
            .onChange(of: isClickingButton) { clicking in
                NotificationCenter.default.post(name: clicking ? .pauseDrawing : .resumeDrawing, object: nil)
            }
        }
        .padding(.vertical, 20)
    }
}
