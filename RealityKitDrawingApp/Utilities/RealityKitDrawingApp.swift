//
//  RealityKitDrawingApp.swift
//  Linezz
//
//  Created by Sayan on 13.05.2025.
//

import SwiftUI

@main
struct RealityKitDrawingApp: App {
    private static let paletteWindowId: String = "Palette"
    private static let configureCanvasWindowId: String = "ConfigureCanvas"
    private static let splashScreenWindowId: String = "SplashScreen"
    private static let immersiveSpaceWindowId: String = "ImmersiveSpace"
    
    /// The mode of the app determines which windows and immersive spaces should be open.
    enum AppMode: Equatable {
        case splashScreen
        case chooseWorkVolume
        case drawing
        
        var needsImmersiveSpace: Bool { self != .splashScreen }
        var needsSpatialTracking: Bool { self != .splashScreen }
        
        fileprivate var windowId: String {
            switch self {
            case .splashScreen: return RealityKitDrawingApp.splashScreenWindowId
            case .chooseWorkVolume: return RealityKitDrawingApp.configureCanvasWindowId
            case .drawing: return RealityKitDrawingApp.paletteWindowId
            }
        }
    }
    
    @State private var appMode: AppMode = .splashScreen
    @State private var canvas = DrawingCanvasSettings()
    @State private var brushState = BrushState()
    @State private var interactionMode: InteractionMode = .drawing
    @State private var document: DrawingDocument?
    
    @State private var immersiveSpacePresented: Bool = false
    @State private var immersionStyle: ImmersionStyle = .mixed
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @MainActor private func setMode(_ newMode: AppMode) async {
        let oldMode = appMode
        guard newMode != oldMode else { return }
        appMode = newMode
        
        if !immersiveSpacePresented && newMode.needsImmersiveSpace {
            immersiveSpacePresented = true
            await openImmersiveSpace(id: Self.immersiveSpaceWindowId)
        } else if immersiveSpacePresented && !newMode.needsImmersiveSpace {
            immersiveSpacePresented = false
            await dismissImmersiveSpace()
        }
        
        openWindow(id: newMode.windowId)
        // Avoid closing the configure window when starting to draw.
        if oldMode.windowId != newMode.windowId {
            dismissWindow(id: oldMode.windowId)
        }
    }

    var body: some Scene {
        Group {
            WindowGroup(id: Self.splashScreenWindowId) {
                SplashScreenView()
                    .environment(\.setMode, setMode)
                    .frame(width: 1000, height: 700)
                    .fixedSize()
            }
            .windowResizability(.contentSize)
            .windowStyle(.plain)
            
            WindowGroup(id: Self.configureCanvasWindowId) {
                DrawingCanvasConfigurationView(settings: canvas)
                    .environment(\.setMode, setMode)
                    .frame(width: 300, height: 300)
                    .fixedSize()
            }
            .windowResizability(.contentSize)
            
            WindowGroup(id: Self.paletteWindowId) {
                PaletteView(brushState: $brushState, interactionMode: $interactionMode, document: document)
                    .frame(width: 450, height: 750, alignment: .top)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .windowResizability(.contentSize)

            ImmersiveSpace(id: Self.immersiveSpaceWindowId) {
                ZStack {
                    if appMode == .chooseWorkVolume || appMode == .drawing {
                        DrawingCanvasVisualizationView(settings: canvas)
                    }
                    
                    if appMode == .chooseWorkVolume {
                        DrawingCanvasPlacementView(settings: canvas)
                    } else if appMode == .drawing {
                        // This view creates and owns the document, binding it back to the app state
                        DrawingMeshView(
                            canvas: canvas,
                            brushState: $brushState,
                            interactionMode: $interactionMode,
                            document: $document
                        )
                    }
                }
                .frame(width: 0, height: 0).frame(depth: 0)
            }
            .immersionStyle(selection: $immersionStyle, in: .mixed)
        }
    }
}

struct SetModeKey: EnvironmentKey {
    typealias Value = (RealityKitDrawingApp.AppMode) async -> Void
    static let defaultValue: Value = { _ in }
}

extension EnvironmentValues {
    var setMode: SetModeKey.Value {
        get { self[SetModeKey.self] }
        set { self[SetModeKey.self] = newValue }
    }
}
