//
//  TwoHandManipulationSystem.swift
//  Linezz
//
//  Created by Sayan on 16.06.2025.
//

import RealityKit
import simd

/// A system that handles the two-handed movement of entities.
struct TwoHandManipulationSystem: System {
    
    // An entity query to find the user's hands.
    private static let handQuery = EntityQuery(where: .has(HandComponent.self))
    
    // An entity query to find all objects that are moveable.
    private static let moveableQuery = EntityQuery(where: .has(TwoHandMoveableComponent.self))
    
    init(scene: RealityKit.Scene) {}
    
    func update(context: SceneUpdateContext) {
        // 1. Get up-to-date hand tracking data.
        let hands = context.entities(matching: Self.handQuery, updatingSystemWhen: .rendering)
        guard let leftHand = hands.first(where: { $0.components[HandComponent.self]?.chirality == .left }),
              let rightHand = hands.first(where: { $0.components[HandComponent.self]?.chirality == .right }) else {
            return
        }
        
        let leftHandComp = leftHand.components[HandComponent.self]!
        let rightHandComp = rightHand.components[HandComponent.self]!
        
        // It can take a moment for hand tracking to initialize.
        // Ensure the anchor positions are valid (not zero) before proceeding.
        guard leftHandComp.indexFingerTip.position != .zero, rightHandComp.indexFingerTip.position != .zero else {
            return
        }
        
        // 2. Determine the gesture state based on hand pinching.
        // Get all hand anchor positions in world space for consistency.
        let leftIndexPos = leftHandComp.indexFingerTip.position(relativeTo: nil)
        let leftThumbPos = leftHandComp.thumbTip.position(relativeTo: nil)
        let rightIndexPos = rightHandComp.indexFingerTip.position(relativeTo: nil)
        let rightThumbPos = rightHandComp.thumbTip.position(relativeTo: nil)

        let pinchThreshold: Float = 0.03 // 3cm
        let isLeftPinched = distance(leftIndexPos, leftThumbPos) < pinchThreshold
        let isRightPinched = distance(rightIndexPos, rightThumbPos) < pinchThreshold
        
        let isGrabbingNow = isLeftPinched && isRightPinched
        
        // The center point between the user's hands, in world space.
        let handsMidpoint = (leftIndexPos + rightIndexPos) / 2
        
        // 3. Iterate through all moveable entities and update their state.
        for entity in context.entities(matching: Self.moveableQuery, updatingSystemWhen: .rendering) {
            
            guard var moveable = entity.components[TwoHandMoveableComponent.self],
                  let lockable = entity.components[LockableComponent.self],
                  !lockable.isLocked else { continue }
            
            // --- FIX: Get the entity's position in WORLD space for all calculations. ---
            let entityWorldPosition = entity.position(relativeTo: nil)
            
            if !moveable.isGrabbed && isGrabbingNow {
                // --- INITIATE grab ---
                let grabDistanceThreshold: Float = 0.4 // Grab from up to 40cm away
                if distance(handsMidpoint, entityWorldPosition) < grabDistanceThreshold {
                    moveable.isGrabbed = true
                    // --- FIX: Calculate offset in WORLD space. ---
                    moveable.initialGrabOffset = entityWorldPosition - handsMidpoint
                }
                
            } else if moveable.isGrabbed && isGrabbingNow {
                // --- CONTINUE grab ---
                if let offset = moveable.initialGrabOffset {
                    let newWorldPosition = handsMidpoint + offset
                    // The move function with `relativeTo: nil` correctly handles setting the world position.
                    entity.move(to: Transform(translation: newWorldPosition), relativeTo: nil, duration: 0.05)
                }
                
            } else if moveable.isGrabbed && !isGrabbingNow {
                // --- RELEASE grab ---
                moveable.isGrabbed = false
                moveable.initialGrabOffset = nil
            }
            
            // Update the component on the entity with the new state.
            entity.components.set(moveable)
        }
    }
}
