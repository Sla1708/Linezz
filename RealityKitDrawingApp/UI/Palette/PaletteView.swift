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

    @State private var isDrawing: Bool = false
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
                    NotificationCenter.default.post(name: .undoStroke, object: nil)
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Redo
                Button {
                    NotificationCenter.default.post(name: .restoreStroke, object: nil)
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Clear (wide)
                Button {
                    NotificationCenter.default.post(name: .clearCanvas, object: nil)
                } label: {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
    }
}

struct PaletteView_Previews: PreviewProvider {
    @State static var brushState = BrushState()

    static var previews: some View {
        PaletteView(brushState: $brushState)
    }
}

