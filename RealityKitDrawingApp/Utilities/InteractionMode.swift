//
//  InteractionMode.swift
//  Linezz
//
//  Created by Sayan on 17.06.2025.
//

import Foundation

/// Defines the user's current interaction mode within the immersive space.
enum InteractionMode: String, CaseIterable, Identifiable {
    case drawing = "Drawing"
    case placement = "Placement"
    
    var id: Self { self }
    
    /// Provides a system image name for each mode, suitable for UI buttons.
    var systemImage: String {
        switch self {
        case .drawing:
            return "hand.draw"
        case .placement:
            return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
}