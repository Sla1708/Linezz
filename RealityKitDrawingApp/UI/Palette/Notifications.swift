//
//  Notifications.swift
//  Linezz
//
//  Created by Sayan on 07.06.2025.
//

import Foundation

extension Notification.Name {
    // Undo last stroke
    static let undoStroke = Notification.Name("undoStroke")
    
    // Restore the last undone stroke
    static let restoreStroke = Notification.Name("restoreStroke")
    
    // Clear all the strokes
    static let clearCanvas = Notification.Name("clearCanvas")
    
    // Pause drawing input (e.g. while tapping Palette buttons)
    static let pauseDrawing = Notification.Name("pauseDrawing")
    
    // Resume drawing input
    static let resumeDrawing = Notification.Name("resumeDrawing")

    // MARK: - New Notifications for File Handling
    
    /// Notification to trigger the presentation of the photo picker.
    static let presentPhotoPicker = Notification.Name("presentPhotoPicker")
    
    /// Notification to trigger the presentation of the file importer.
    static let presentFileImporter = Notification.Name("presentFileImporter")
    
    /// Notification to show an error alert with a message.
    static let showErrorAlert = Notification.Name("showErrorAlert")
}
