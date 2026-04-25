//
//  SmartCaneApp.swift
//  SmartCane
//
//  Hackathon MVP - Lateral Steering Smart Cane
//

import SwiftUI

@main
struct PathSenseApp: App {
    @StateObject private var espBluetooth = ESPBluetoothManager()
    @StateObject private var caneController = PathSenseController()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView(caneController: caneController, espBluetooth: espBluetooth)
                    .tabItem {
                        Label("Navigation", systemImage: "location.fill")
                    }

                if let navManager = caneController.navigationManager {
                    RouteMapView(navigationManager: navManager)
                        .tabItem {
                            Label("Route", systemImage: "map.fill")
                        }
                }

                BluetoothPairingView(ble: espBluetooth, controller: caneController)
                    .tabItem {
                        Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                    }
            }
            .onAppear {
                // Initialize after views are ready
                caneController.initialize(espBluetooth: espBluetooth)
            }
        }
    }
}
