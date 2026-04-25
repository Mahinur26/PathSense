//
//  RouteMapView.swift
//  SmartCane
//

import SwiftUI
import MapKit

struct RouteMapView: View {
    @ObservedObject var navigationManager: NavigationManager
    @State private var showMicroWaypoints = false

    private var glass: Color { Color.white.opacity(0.06) }
    private var border: Color { Color.white.opacity(0.10) }
    private var dim: Color   { Color.white.opacity(0.45) }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()

            if let route = navigationManager.currentRoute {
                activeRouteMap(route: route)
            } else {
                noRouteView
            }
        }
    }

    // MARK: - No Route

    private var noRouteView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "map")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            Text("No Active Route")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Start navigation from the main tab to see the route here")
                .font(.system(size: 13))
                .foregroundStyle(dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
    }

    // MARK: - Active Route Map

    private func activeRouteMap(route: PedestrianRoute) -> some View {
        let polylineCoords = route.overviewPolyline
        let region = Self.regionForCoordinates(polylineCoords, userLocation: navigationManager.userLocation)

        return VStack(spacing: 0) {
            routeHeader(route: route)

            Map(initialPosition: .region(region)) {
                if polylineCoords.count >= 2 {
                    MapPolyline(coordinates: polylineCoords)
                        .stroke(.cyan, lineWidth: 5)
                }

                Annotation("Start", coordinate: route.origin) {
                    ZStack {
                        Circle().fill(.green).frame(width: 24, height: 24)
                        Image(systemName: "figure.walk").font(.system(size: 12)).foregroundColor(.white)
                    }
                }

                Annotation(route.destinationName.components(separatedBy: ",").first ?? "End", coordinate: route.destination) {
                    ZStack {
                        Circle().fill(.red).frame(width: 24, height: 24)
                        Image(systemName: "flag.fill").font(.system(size: 12)).foregroundColor(.white)
                    }
                }

                ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                    if step.maneuver != .depart && step.maneuver != .unknown {
                        Annotation("", coordinate: step.startLocation) {
                            stepMarker(index: index, step: step, isCurrentStep: index == navigationManager.currentStepIndex)
                        }
                    }
                }

                ForEach(allInfrastructure(from: route)) { feature in
                    Annotation("", coordinate: feature.coordinate) {
                        infrastructureMarker(feature: feature)
                    }
                }

                if showMicroWaypoints {
                    let waypoints = navigationManager.waypointTracker.waypoints
                    let currentIdx = navigationManager.waypointTracker.currentIndex
                    ForEach(Array(waypoints.enumerated()), id: \.offset) { index, wp in
                        Annotation("", coordinate: wp.coordinate) {
                            Circle()
                                .fill(index == currentIdx ? Color.yellow : Color.mint.opacity(0.7))
                                .frame(width: index == currentIdx ? 12 : 8, height: index == currentIdx ? 12 : 8)
                                .overlay(index == currentIdx ?
                                    Circle().stroke(Color.yellow, lineWidth: 2).frame(width: 18, height: 18) : nil)
                        }
                    }
                }

                if let userLoc = navigationManager.userLocation {
                    Annotation("You", coordinate: userLoc) {
                        ZStack {
                            Circle().fill(.blue.opacity(0.3)).frame(width: 32, height: 32)
                            Circle().fill(.blue).frame(width: 16, height: 16)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
            }
            .mapStyle(.standard)

            stepList(route: route)
        }
    }

    // MARK: - Route Header

    private func routeHeader(route: PedestrianRoute) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.destinationName.components(separatedBy: ",").first ?? route.destinationName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label("\(Int(route.totalDistanceMeters))m", systemImage: "figure.walk")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Label("\(Int(route.totalDurationSeconds / 60)) min", systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(dim)
                    Label("\(route.steps.count) steps", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .font(.system(size: 11))
                        .foregroundStyle(dim)
                }
            }

            Spacer()

            Button {
                showMicroWaypoints.toggle()
            } label: {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(showMicroWaypoints ? .cyan : .white.opacity(0.4))
                    .padding(8)
                    .background(
                        Circle().fill(showMicroWaypoints ? Color.cyan.opacity(0.18) : Color.white.opacity(0.07))
                    )
            }

            stateBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color(red: 0.05, green: 0.07, blue: 0.13))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }

    private var stateBadge: some View {
        Group {
            switch navigationManager.state {
            case .navigating:
                Label("Active", systemImage: "location.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.cyan.opacity(0.18)))
                    .foregroundStyle(.cyan)
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 0.5))
            case .arrived:
                Label("Arrived", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.green.opacity(0.18)))
                    .foregroundStyle(.green)
                    .overlay(Capsule().stroke(Color.green.opacity(0.3), lineWidth: 0.5))
            case .planning:
                Label("Planning", systemImage: "ellipsis")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(dim)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Step List

    private func stepList(route: PedestrianRoute) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                    stepCard(index: index, step: step)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(red: 0.05, green: 0.07, blue: 0.13))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
        .frame(height: 82)
    }

    private func stepCard(index: Int, step: RouteStep) -> some View {
        let isCurrent = index == navigationManager.currentStepIndex
        let isPast    = index < navigationManager.currentStepIndex

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: maneuverIcon(step.maneuver))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isCurrent ? .cyan : isPast ? .white.opacity(0.3) : .white.opacity(0.7))
                Text("\(Int(step.distanceMeters))m")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isCurrent ? .cyan : dim)
            }
            Text(step.instruction)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isPast ? .white.opacity(0.3) : .white.opacity(0.85))
                .lineLimit(2)

            if !step.infrastructure.isEmpty {
                HStack(spacing: 3) {
                    ForEach(Array(Set(step.infrastructure.map(\.type))), id: \.rawValue) { type in
                        Image(systemName: infraIcon(type))
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .frame(width: 136)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isCurrent ? Color.cyan.opacity(0.12) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isCurrent ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Map Markers

    private func stepMarker(index: Int, step: RouteStep, isCurrentStep: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCurrentStep ? Color.cyan : Color.white.opacity(0.9))
                .frame(width: 20, height: 20)
            Image(systemName: maneuverIcon(step.maneuver))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isCurrentStep ? .white : .black)
        }
    }

    private func infrastructureMarker(feature: InfrastructureFeature) -> some View {
        ZStack {
            Circle().fill(infraColor(feature.type)).frame(width: 18, height: 18)
            Image(systemName: infraIcon(feature.type)).font(.system(size: 9)).foregroundColor(.white)
        }
    }

    // MARK: - Helpers

    private func allInfrastructure(from route: PedestrianRoute) -> [InfrastructureFeature] {
        route.steps.flatMap(\.infrastructure)
    }

    private func maneuverIcon(_ maneuver: Maneuver) -> String {
        switch maneuver {
        case .turnLeft, .turnSharpLeft:   return "arrow.turn.up.left"
        case .turnRight, .turnSharpRight: return "arrow.turn.up.right"
        case .turnSlightLeft:             return "arrow.up.left"
        case .turnSlightRight:            return "arrow.up.right"
        case .uturnLeft, .uturnRight:     return "arrow.uturn.down"
        case .straight:                   return "arrow.up"
        case .depart:                     return "figure.walk"
        case .arrive:                     return "flag.fill"
        default:                          return "circle.fill"
        }
    }

    private func infraIcon(_ type: InfrastructureType) -> String {
        switch type {
        case .crosswalk:      return "figure.walk"
        case .trafficSignal:  return "light.beacon.max"
        case .stopSign:       return "hand.raised.fill"
        }
    }

    private func infraColor(_ type: InfrastructureType) -> Color {
        switch type {
        case .crosswalk:     return .yellow
        case .trafficSignal: return .orange
        case .stopSign:      return .red
        }
    }

    private static func regionForCoordinates(_ coords: [CLLocationCoordinate2D], userLocation: CLLocationCoordinate2D?) -> MKCoordinateRegion {
        var allCoords = coords
        if let user = userLocation { allCoords.append(user) }
        guard !allCoords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.4275, longitude: -122.1697),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        var minLat = allCoords[0].latitude, maxLat = allCoords[0].latitude
        var minLng = allCoords[0].longitude, maxLng = allCoords[0].longitude
        for c in allCoords {
            minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.4 + 0.002,
                                   longitudeDelta: (maxLng - minLng) * 1.4 + 0.002)
        )
    }
}
