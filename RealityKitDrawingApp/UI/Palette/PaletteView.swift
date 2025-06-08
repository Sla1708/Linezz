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

    @State private var isDrawing:   Bool = false
    @State private var isSettingsPopoverPresented: Bool = false

    var body: some View {
        VStack {
            HStack {
                Text("Palette")
                    .font(.title)
                    .padding()
                Spacer()
            }

            Divider()
                .padding(.horizontal, 20)

            BrushTypeView(brushState: $brushState)
                .padding(.horizontal, 20)

            Spacer()

            Divider()
                .padding(.horizontal, 20)

            PresetBrushSelectorView(brushState: $brushState)
                .frame(minHeight: 125)

            Spacer()

            // Undo button
            Button {
                NotificationCenter.default.post(name: .undoStroke, object: nil)
            } label: {
                Label("Undo", systemImage: "arrow.uturn.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()

            // Restore button
            Button {
                NotificationCenter.default.post(name: .restoreStroke, object: nil)
            } label: {
                Label("Restore", systemImage: "arrow.uturn.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()

            // Clear all strokes/canvas
            Button {
                NotificationCenter.default.post(name: .clearCanvas, object: nil)
            } label: {
                Label("Clear", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding(.vertical, 20)
    }
}

