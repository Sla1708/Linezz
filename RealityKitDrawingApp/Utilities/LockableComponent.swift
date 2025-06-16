//
//  LockableComponent.swift
//  Linezz
//
//  Created by Sayan on 16.06.2025.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  LockableComponent.swift
//  Linezz
//
//  Created by Sayan on 16.06.2025.
//

import RealityKit

/// A component that adds a lockable state to an entity.
/// When `isLocked` is true, the entity should not be movable.
struct LockableComponent: Component {
    var isLocked: Bool = false
}