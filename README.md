# Linezz

Linezz for Apple Vision Pro

## Overview

Linezz is a drawing application designed specifically for Apple Vision Pro (visionOS). It allows users to draw in 3D space using ARKit hand tracking, creating smooth, dynamic strokes with multiple brush styles.

## Features

* Real-time AR hand tracking–based drawing in 3D space
* Multiple brush types (Solid, Sparkle, Calligraphic)
* Smooth stroke generation with curve sampling and extrusion
* Dynamic brush styling (thickness, sparkle effects) based on movement
* Immersive multi-window workflow with configuration and canvas views
* Splash screen with custom Metal shaders

**Features in Developement / Comming Soon**
* Multi-user collaboration
* SharePlay & FaceTime integration
* Ability to undo the latest drawings
* Automatic zone delimitation
* UI is still in developement
* More coming soon


## Prerequisites

* An Apple Vision Pro device running visionOS 2.0 or later
* Xcode 16 or later
* A Mac running macOS 15.0 or later
* Developing for visionOS requires a Mac with Apple silicon 

> **Note:** Because Linezz uses ARKit hand tracking, the drawing features are not available in the visionOS Simulator.

## Project Configuration

1. **Clone the repository**

   ```bash
   git clone https://github.com/Sla1708/Linezz.git
   cd Linezz
   ```
2. **Open the Xcode workspace**

   * Launch Xcode and open `Linezz.xcodeproj`.
3. **Select the app ("Linezz") target**

   * In Xcode’s Scheme selector, choose `Linezz (visionOS)`.
4. **Connect your Apple Vision Pro**

   * Ensure your device (Apple Vision Pro) is paired/connected. Select it as the build destination.
5. **Build and Run**

   * Press `⌘R` to build and launch the app on the Vision Pro device.

## License

This project ("Linezz") is licensed under a specific license. See the [LICENSE](LICENSE.txt) file for details.

**Please Note:**
This app is also part of the Neigboorhood SF program.