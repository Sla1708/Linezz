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
        // 1. Get up-to-date hand tracking data. We need both hands to proceed.
        let hands = context.entities(matching: Self.handQuery, updatingSystemWhen: .rendering)
        guard let leftHand = hands.first(where: { $0.components[HandComponent.self]?.chirality == .left }),
              let rightHand = hands.first(where: { $0.components[HandComponent.self]?.chirality == .right }) else {
            return
        }
        
        let leftHandComp = leftHand.components[HandComponent.self]!
        let rightHandComp = rightHand.components[HandComponent.self]!
        
        // 2. Determine the gesture state based on hand pinching.
        // A "pinch" is defined as the index finger and thumb being very close.
        let pinchThreshold: Float = 0.03 // 3cm
        let isLeftPinched = distance(leftHandComp.indexFingerTip.position, leftHandComp.thumbTip.position) < pinchThreshold
        let isRightPinched = distance(rightHandComp.indexFingerTip.position, rightHandComp.thumbTip.position) < pinchThreshold
        
        let isGrabbingNow = isLeftPinched && isRightPinched
        
        // The center point between the user's hands.
        let handsMidpoint = (leftHandComp.indexFingerTip.position + rightHandComp.indexFingerTip.position) / 2
        
        // 3. Iterate through all moveable entities and update their state.
        for entity in context.entities(matching: Self.moveableQuery, updatingSystemWhen: .rendering) {
            
            // The entity must have our custom components and must not be locked.
            guard var moveable = entity.components[TwoHandMoveableComponent.self],
                  let lockable = entity.components[LockableComponent.self],
                  !lockable.isLocked else { continue }
            
            if !moveable.isGrabbed && isGrabbingNow {
                // --- Condition to INITIATE a grab ---
                // The user is pinching with both hands, and the object isn't already grabbed.
                // Check if the hands are close enough to the object to grab it.
                let grabDistanceThreshold: Float = 0.4 // Grab from up to 40cm away
                if distance(handsMidpoint, entity.position) < grabDistanceThreshold {
                    moveable.isGrabbed = true
                    moveable.initialGrabOffset = entity.position - handsMidpoint
                }
                
            } else if moveable.isGrabbed && isGrabbingNow {
                // --- Condition to CONTINUE a grab ---
                // The user continues to pinch, so we move the object.
                if let offset = moveable.initialGrabOffset {
                    let newPosition = handsMidpoint + offset
                    // Smoothly move the entity to its new position.
                    entity.move(to: Transform(translation: newPosition), relativeTo: nil, duration: 0.05)
                }
                
            } else if moveable.isGrabbed && !isGrabbingNow {
                // --- Condition to RELEASE a grab ---
                // The user has stopped pinching, so release the object.
                moveable.isGrabbed = false
                moveable.initialGrabOffset = nil
            }
            
            // Update the component on the entity with the new state.
            entity.components.set(moveable)
        }
    }
}