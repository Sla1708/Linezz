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
    
    // New: Add an image into the drawing zone
    static let addImage = Notification.Name("addImage")
    
    // New: Add a file into the drawing zone
    static let addFile = Notification.Name("addFile")
}

