//
//  NavigationView.swift
//  SmartCane
//

import SwiftUI

// MARK: - Navigation Input Sheet

struct NavigationInputSheet: View {
    @ObservedObject var navigationManager: NavigationManager
    @Binding var isPresented: Bool
    @State private var destination: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.07, blue: 0.13), Color(red: 0.02, green: 0.03, blue: 0.08)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.15))
                                .frame(width: 80, height: 80)
                                .blur(radius: 14)
                            Image(systemName: "map.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.cyan)
                        }
                        Text("Where to?")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Enter a destination for walking directions")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    TextField("e.g. Tresidder Union, Stanford", text: $destination)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .padding(14)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .foregroundStyle(.white)
                        .focused($isTextFieldFocused)
                        .submitLabel(.go)
                        .onSubmit { startNavigation() }

                    Button(action: startNavigation) {
                        HStack(spacing: 10) {
                            Image(systemName: "location.fill")
                            Text("Navigate")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Group {
                                if destination.isEmpty {
                                    Color.white.opacity(0.10)
                                } else {
                                    LinearGradient(colors: [.cyan, Color(red: 0.1, green: 0.6, blue: 0.9)],
                                                   startPoint: .leading, endPoint: .trailing)
                                }
                            }
                        )
                        .foregroundStyle(destination.isEmpty ? Color.white.opacity(0.35) : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(destination.isEmpty)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { isTextFieldFocused = true }
    }

    private func startNavigation() {
        guard !destination.isEmpty else { return }
        print("[NavigationSheet] Navigate tapped with destination: '\(destination)'")
        navigationManager.startNavigation(to: destination)
        isPresented = false
    }
}

// MARK: - Navigation HUD

struct NavigationHUD: View {
    @ObservedObject var navigationManager: NavigationManager

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                switch navigationManager.state {
                case .planning:   planningView
                case .navigating: navigatingView
                case .arriving:   arrivingView
                case .arrived:    arrivedView
                case .error(let message): errorView(message)
                default: EmptyView()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.04, green: 0.06, blue: 0.12).opacity(0.97))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(hudBorderColor.opacity(0.45), lineWidth: 1.5)
                    )
            )
            .shadow(color: hudBorderColor.opacity(0.22), radius: 14, y: 4)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: Sub-views

    private var planningView: some View {
        HStack(spacing: 12) {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            Text("Planning route...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private var navigatingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: maneuverIcon)
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(navigationManager.currentGuidance?.currentInstruction ?? "Continue")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 14) {
                        Label(formatDistance(navigationManager.distanceToNextManeuver), systemImage: "arrow.turn.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.cyan)
                        Label(formatDistance(navigationManager.distanceToDestination), systemImage: "flag.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

                Spacer()
                stopButton
            }

            if let guidance = navigationManager.currentGuidance,
               !guidance.nearbyInfrastructure.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(Set(guidance.nearbyInfrastructure.map(\.type.rawValue))), id: \.self) { type in
                        Label(type.capitalized, systemImage: infrastructureIcon(for: type))
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var arrivingView: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered").font(.title2).foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Approaching destination")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("\(Int(navigationManager.distanceToDestination))m remaining")
                    .font(.system(size: 12)).foregroundStyle(.green)
            }
            Spacer()
            stopButton
        }
    }

    private var arrivedView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
            Text("You have arrived!")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.green)
            Spacer()
            Button("Done") { navigationManager.stopNavigation() }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Color.green.opacity(0.2))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.red)
            Text(message)
                .font(.system(size: 13)).foregroundStyle(.red).lineLimit(2)
            Spacer()
            Button("Dismiss") { navigationManager.stopNavigation() }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Color.red.opacity(0.2))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        }
    }

    private var stopButton: some View {
        Button { navigationManager.stopNavigation() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.red.opacity(0.75))
        }
    }

    // MARK: Helpers

    private var hudBorderColor: Color {
        switch navigationManager.state {
        case .navigating: return .cyan
        case .arriving:   return .green
        case .arrived:    return .green
        case .error:      return .red
        default:          return .white.opacity(0.15)
        }
    }

    private var maneuverIcon: String {
        guard let route = navigationManager.currentRoute,
              navigationManager.currentStepIndex < route.steps.count else { return "arrow.up" }
        switch route.steps[navigationManager.currentStepIndex].maneuver {
        case .turnLeft, .turnSharpLeft:   return "arrow.turn.up.left"
        case .turnRight, .turnSharpRight: return "arrow.turn.up.right"
        case .turnSlightLeft:             return "arrow.up.left"
        case .turnSlightRight:            return "arrow.up.right"
        case .uturnLeft, .uturnRight:     return "arrow.uturn.down"
        default:                          return "arrow.up"
        }
    }

    private func infrastructureIcon(for type: String) -> String {
        switch type {
        case "crosswalk":      return "figure.walk"
        case "trafficSignal":  return "light.beacon.max"
        case "stopSign":       return "hand.raised.fill"
        default:               return "exclamationmark.triangle"
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters))m"
    }
}
