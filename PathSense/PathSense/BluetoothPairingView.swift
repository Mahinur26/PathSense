//
//  BluetoothPairingView.swift
//  SmartCane
//

import SwiftUI

struct BluetoothPairingView: View {
    @ObservedObject var ble: ESPBluetoothManager
    @ObservedObject var controller: PathSenseController

    private var glass: Color { Color.white.opacity(0.06) }
    private var border: Color { Color.white.opacity(0.10) }
    private var dim: Color   { Color.white.opacity(0.45) }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.07, blue: 0.13), Color(red: 0.02, green: 0.03, blue: 0.08)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        bleSection
                        motorControlSection
                        steeringTuningSection
                        steeringDebugSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("ESP32 Bluetooth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Bluetooth

    private var bleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Bluetooth", icon: "antenna.radiowaves.left.and.right", color: .cyan)

            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(ble.isBluetoothReady ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(ble.isBluetoothReady ? "Powered On" : "Unavailable")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(ble.isScanning ? "Stop Scan" : "Scan") {
                    ble.toggleScan()
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(ble.isScanning ? Color.orange.opacity(0.8) : Color.cyan.opacity(0.75))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }

            if let connectedName = ble.connectedName {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.caption)
                        Text("Connected: \(connectedName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button("Disconnect", role: .destructive) { ble.disconnect() }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.75))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            if let statusMessage = ble.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

            if ble.discoveredPeripherals.isEmpty {
                Text("No ESP32 devices found yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                ForEach(ble.discoveredPeripherals) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(device.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Text("RSSI: \(device.rssi)")
                                .font(.system(size: 11))
                                .foregroundStyle(dim)
                        }
                        Spacer()
                        Button("Pair") { ble.connect(device.peripheral) }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.75))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(glass)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(border, lineWidth: 1))
    }

    // MARK: - Motor Control

    private var motorControlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Motor Control (10 Hz)", icon: "gearshape.fill", color: .orange)
            sliderRow("Angle",    value: String(format: "%.2f", ble.angle),             binding: $ble.angle,    range: -180...180)
            sliderRow("Distance", value: String(format: "%.2f", ble.distance),          binding: $ble.distance, range: 0...100)
            sliderRow("Mode",     value: "\(Int(ble.mode.rounded()))",                  binding: $ble.mode,     range: 0...10, step: 1)
        }
        .padding(16)
        .background(glass)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(border, lineWidth: 1))
    }

    // MARK: - Steering Tuning

    private var steeringTuningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Steering Tuning", icon: "slider.horizontal.3", color: .purple)
            sliderRow("Sensitivity",        value: "\(String(format: "%.1f", ble.steeringSensitivity))m",
                      hint: "Start steering when obstacle closer than this",
                      binding: $ble.steeringSensitivity, range: 0.5...4.0)
            sliderRow("Motor Base Scale",   value: String(format: "%.0f", ble.motorBaseScale),
                      hint: "Raw speed sent to ESP32 (÷255 on device). Higher = stronger motor.",
                      binding: $ble.motorBaseScale, range: 10...255)
            sliderRow("Magnitude",          value: "\(String(format: "%.1f", ble.steeringMagnitude))×",
                      hint: "Extra multiplier on base scale",
                      binding: $ble.steeringMagnitude, range: 0.1...3.0)
            sliderRow("Proximity Exponent", value: String(format: "%.2f", ble.proximityExponent),
                      hint: "Lower = ramps up faster with distance. 1.0 = linear.",
                      binding: $ble.proximityExponent, range: 0.2...1.5)
            sliderRow("Close Floor",        value: String(format: "%.2f", ble.closeFloor),
                      hint: "Min |command| when obstacle < 1m. 0 = disabled.",
                      binding: $ble.closeFloor, range: 0.0...1.0)
        }
        .padding(16)
        .background(glass)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(border, lineWidth: 1))
    }

    // MARK: - Steering Debug

    private var steeringDebugSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Steering Debug (Live)", icon: "waveform.path.ecg", color: .mint)
            debugRow(label: "Gap Direction",
                     value: String(format: "%.2f", controller.gapDirection),
                     hint: "Where the clearest path is: -1 = left, 0 = center, +1 = right",
                     color: controller.gapDirection < -0.1 ? .blue : controller.gapDirection > 0.1 ? .purple : .green)
            debugRow(label: "Steering Command",
                     value: String(format: "%.2f", controller.steeringCommand),
                     hint: "gap × proximity — sent to ESP32 as command × magnitude",
                     color: controller.steeringCommand < -0.1 ? .blue : controller.steeringCommand > 0.1 ? .purple : .green)
            debugRow(label: "Motor Power",
                     value: "\(Int(controller.motorIntensity))/255",
                     hint: "Estimated steady-state PWM on ESP32",
                     color: controller.motorIntensity > 0 ? .orange : Color.white.opacity(0.4))
        }
        .padding(16)
        .background(glass)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(border, lineWidth: 1))
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private func sliderRow(
        _ label: String,
        value: String,
        hint: String? = nil,
        binding: Binding<Float>,
        range: ClosedRange<Float>,
        step: Float? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            if let s = step {
                Slider(value: binding, in: range, step: s).tint(.cyan)
            } else {
                Slider(value: binding, in: range).tint(.cyan)
            }
            if let hint = hint {
                Text(hint).font(.system(size: 10)).foregroundStyle(dim)
            }
        }
    }

    @ViewBuilder
    private func debugRow(label: String, value: String, hint: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            Text(hint).font(.system(size: 10)).foregroundStyle(dim)
        }
    }
}

#Preview {
    let espBT = ESPBluetoothManager()
    let controller = PathSenseController()
    return BluetoothPairingView(ble: espBT, controller: controller)
}
