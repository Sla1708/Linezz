//
//  TwoHandMoveableComponent.swift
//  Linezz
//
//  Created by Sayan on 16.06.2025.
//

import RealityKit
import simd

/// A component that holds the state for a two-handed move interaction.
struct TwoHandMoveableComponent: Component {
    /// True if the entity is currently being grabbed and moved by the user's hands.
    var isGrabbed: Bool = false
    
    /// The initial offset from the midpoint of the hands to the entity's center when the grab began.
    /// This is stored to ensure smooth movement.
    var initialGrabOffset: SIMD3<Float>? = nil
}