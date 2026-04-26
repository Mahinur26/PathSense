//
//  DepthSensor.swift
//  SmartCane
//
//  ARKit + LiDAR depth capture at 30-60fps
//

import Foundation
import ARKit
import Combine

// Depth data structure
struct DepthFrame {
    let depthMap: CVPixelBuffer?  // nil on non-LiDAR devices
    let timestamp: TimeInterval
    let cameraTransform: simd_float4x4
    let capturedImage: CVPixelBuffer?  // RGB camera frame for object recognition
}

class DepthSensor: NSObject, ObservableObject {
    @Published var latestDepthFrame: DepthFrame?

    private var arSession: ARSession?
    private let configuration = ARWorldTrackingConfiguration()

    override init() {
        super.init()
        setupARSession()
    }

    let hasLiDAR = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)

    private func setupARSession() {
        arSession = ARSession()
        arSession?.delegate = self

        if hasLiDAR {
            configuration.frameSemantics = .sceneDepth
            print("[DepthSensor] LiDAR available — enabling sceneDepth")
        } else {
            print("[DepthSensor] No LiDAR — running camera-only mode")
        }

        configuration.planeDetection = [.horizontal, .vertical]

        // Optimize for real-time performance
        configuration.videoFormat = ARWorldTrackingConfiguration
            .supportedVideoFormats
            .first { $0.framesPerSecond == 60 } ?? ARWorldTrackingConfiguration.supportedVideoFormats[0]

        print("[DepthSensor] ARKit configured at \(configuration.videoFormat.framesPerSecond)fps")
    }

    func start() {
        print("[DepthSensor] Starting ARKit session...")
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        print("[DepthSensor] Stopping ARKit session...")
        arSession?.pause()
    }
}

// MARK: - ARSessionDelegate
extension DepthSensor: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let depthFrame = DepthFrame(
            depthMap: frame.sceneDepth?.depthMap,  // nil on non-LiDAR devices
            timestamp: frame.timestamp,
            cameraTransform: frame.camera.transform,
            capturedImage: frame.capturedImage
        )

        // Publish on main thread (SwiftUI requirement)
        DispatchQueue.main.async { [weak self] in
            self?.latestDepthFrame = depthFrame
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[DepthSensor] ERROR: \(error.localizedDescription)")
    }
}
