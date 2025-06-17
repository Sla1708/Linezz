//
//  ImportedContentComponent.swift
//  Linezz
//
//  Created by Sayan on 17.06.2025.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  ImportedContent.swift
//  Linezz
//
//  Created by Sayan on 17.06.2025.
//

import RealityKit
import Foundation

/// A component that identifies an entity as user-imported content,
/// making it manipulable in placement mode.
struct ImportedContentComponent: Component {
    /// A unique identifier for the imported entity.
    var id: UUID = UUID()
    
    /// The original URL of the imported file, for reference.
    var sourceURL: URL?
}

/// A system to manage gestures for imported content.
/// Although gestures are handled in SwiftUI, this system ensures
/// the component is registered and can be used for future per-frame updates.
class ImportedContentSystem: System {
    private static let query = EntityQuery(where: .has(ImportedContentComponent.self))
    
    required init(scene: RealityKit.Scene) {
        ImportedContentComponent.registerComponent()
    }
    
    func update(context: SceneUpdateContext) {
        // Future per-frame logic for imported content can be added here.
    }
}
