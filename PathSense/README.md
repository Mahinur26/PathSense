# PathSense

An iOS app for a lateral-steering smart cane. Built at a hackathon, the goal was to give a white cane real-time obstacle awareness and GPS navigation through haptic motor feedback — no screen-reading required.

---

## What it does

The phone's LiDAR sensor feeds depth data into a three-zone detector (left / center / right). When the path ahead isn't clear, it calculates which direction has the most space and sends a motor command over BLE to an ESP32 sitting in the cane handle. The ESP32 drives vibration motors on each side, steering the user away from obstacles without them needing to look at the screen.

On top of that there's GPS turn-by-turn navigation, a Vapi voice assistant you can talk to during a walk, surface classification using a DeepLab V3 model (to catch grass or uneven terrain), and a game controller mode for testing steering without walking.

---

## Hardware

- iPhone with LiDAR (iPhone 12 Pro or newer)
- ESP32 microcontroller in the cane handle
- Two vibration motors wired to the ESP32

The app pairs to the ESP32 over BLE using custom service/characteristic UUIDs. Once connected it streams a continuous steering value (`-1.0` to `+1.0`) and a motor intensity byte.

---

## Stack

- **SwiftUI** — UI, tab navigation
- **ARKit** — LiDAR depth capture
- **CoreML** — on-device DeepLab V3 Int8 for surface segmentation
- **CoreLocation / MapKit** — GPS route planning and turn-by-turn
- **CoreBluetooth** — BLE connection to the ESP32
- **Vapi iOS SDK** — voice assistant during navigation
- **GameController** — joystick input for testing

---

## Project structure

```
PathSense/
├── Core/
│   └── SmartCaneController.swift   # central coordinator, owns all subsystems
├── Communication/
│   └── ESPBluetoothManager.swift   # BLE scan, pair, stream motor commands
├── Feedback/
│   ├── HapticManager.swift         # Core Haptics patterns
│   └── VoiceManager.swift          # AVSpeechSynthesizer wrapper
├── Navigation/
│   ├── NavigationManager.swift     # GPS routing + step-by-step guidance
│   ├── SteeringEngine.swift        # combines obstacle + nav bias → final motor value
│   ├── ObstacleDetector.swift      # depth map → left/center/right zone distances
│   ├── SurfaceClassifier.swift     # DeepLab inference → terrain type
│   ├── NavigationSteering.swift    # heading error → nav bias
│   ├── RouteService.swift          # fetches pedestrian routes
│   └── WaypointModels.swift        # route/step/waypoint data types
├── Sensors/
│   └── DepthSensor.swift           # ARKit session, delivers depth + camera frames
├── Vision/
│   ├── ObjectRecognizer.swift      # Vision framework person/object detection
│   └── DepthVisualizer.swift       # renders depth map as a color overlay
└── Voice/
    └── VapiManager.swift           # Vapi call lifecycle + live sensor injection
```

---

## Getting started

1. Clone the repo and open `PathSense.xcodeproj`
2. Add your API keys — copy `Core/Secrets.swift.example` to `Core/Secrets.swift` and fill in your Vapi public key and any route service keys (`Secrets.swift` is gitignored)
3. Select your device (LiDAR required, simulator won't work)
4. Build and run

You don't need the ESP32 to test — the app runs without BLE connected, and you can use a MFi game controller to drive the steering manually.

---

## How the steering works

Every ARKit frame:
1. `DepthSensor` delivers a `CVPixelBuffer` depth map
2. `ObstacleDetector` scans the pixel columns and finds the closest obstacle in each zone; the gap direction is a smoothed average across 5 frames
3. `SteeringEngine` blends the obstacle gap signal with a navigation heading bias (if a route is active) and clamps to `[-1.0, +1.0]`
4. The final value is sent to `ESPBluetoothManager` which packs it into bytes and writes to the ESP32 characteristic

The surface classifier runs in parallel — if it detects grass or rough terrain in a zone it injects a synthetic wall into that zone, nudging the user back onto paved surface.

---

## Notes

- `Secrets.swift` is gitignored — the app will fail to build without it
- The backup of the project file (`project.pbxproj.backup`) is also gitignored
- `xcuserdata` and `UserInterfaceState.xcuserstate` are gitignored; you'll see them appear locally after first open in Xcode
