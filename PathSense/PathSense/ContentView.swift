//
//  ContentView.swift
//  SmartCane
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var caneController: PathSenseController
    @ObservedObject var espBluetooth: ESPBluetoothManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var showNavigationSheet = false

    var isLandscape: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    private var glassCard: Color { Color.white.opacity(0.06) }
    private var glassBorder: Color { Color.white.opacity(0.10) }
    private var secondary: Color { Color.white.opacity(0.45) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.13), Color(red: 0.02, green: 0.03, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection
                    statusRow

                    obstacleSection

                    if let nav = caneController.navigationManager, nav.state.isActive {
                        compassSection(nav: nav)
                    }

                    steeringSection

                    if caneController.showDepthVisualization { depthMapSection }
                    if caneController.showCameraPreview { cameraPreviewSection }
                    if caneController.terrainDebugMode { terrainDebugSection }

                    if let object = caneController.detectedObject {
                        detectedObjectSection(object: object)
                    }

                    controlsSection
                    vapiSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .overlay(alignment: .top) {
            if let navManager = caneController.navigationManager, navManager.state != .idle {
                NavigationHUD(navigationManager: navManager)
            }
        }
        .sheet(isPresented: $showNavigationSheet) {
            if let navManager = caneController.navigationManager {
                NavigationInputSheet(navigationManager: navManager, isPresented: $showNavigationSheet)
            }
        }
        .onAppear {
            print("[ContentView] View appeared")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .blur(radius: 14)
                Image(systemName: "wand.and.rays")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
            Text("PathSense")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("AI-Powered Navigation Assistant")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(secondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 10) {
            statusPill(label: "BLE", value: caneController.isConnected ? "Connected" : "Searching", active: caneController.isConnected)
            statusPill(label: "LiDAR", value: caneController.isARRunning ? "Active" : "Inactive", active: caneController.isARRunning)
            Spacer()
            if caneController.isSystemActive {
                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Running")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.green.opacity(0.12)))
                .overlay(Capsule().stroke(Color.green.opacity(0.25), lineWidth: 0.5))
            }
        }
    }

    @ViewBuilder
    private func statusPill(label: String, value: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.red.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondary)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? .green : .red.opacity(0.9))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(glassCard))
        .overlay(Capsule().stroke(glassBorder, lineWidth: 0.5))
    }

    // MARK: - Obstacle Detection

    private var obstacleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Obstacle Detection", icon: "sensor.fill", color: .cyan)
            HStack(spacing: 10) {
                zoneCard(label: "Left",   icon: "arrow.left",  distance: caneController.leftDistance)
                zoneCard(label: "Center", icon: "arrow.up",    distance: caneController.centerDistance)
                zoneCard(label: "Right",  icon: "arrow.right", distance: caneController.rightDistance)
            }
        }
        .padding(16)
        .background(glassCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(glassBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func zoneCard(label: String, icon: String, distance: Float?) -> some View {
        let color = getDistanceColor(distance)
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondary)
            Text(formatDistance(distance))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let dist = distance {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color)
                                .frame(width: geo.size.width * CGFloat(min(dist / 4.0, 1.0)))
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color.opacity(0.22), lineWidth: 1))
    }

    // MARK: - Steering Section

    @ViewBuilder
    private var steeringSection: some View {
        let cmd = caneController.steeringCommand
        let leftScale  = CGFloat(1.0 + abs(min(cmd, 0)) * 0.3)
        let rightScale = CGFloat(1.0 + max(cmd, 0) * 0.3)
        let dotOffset  = CGFloat(cmd) * 30
        let leftColor: Color  = cmd < -0.1 ? .blue   : Color.gray.opacity(0.3)
        let rightColor: Color = cmd >  0.1 ? .purple : Color.gray.opacity(0.3)

        VStack(spacing: 12) {
            sectionLabel("Steering Command", icon: "location.north.fill", color: .cyan)

            HStack(spacing: 20) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(leftColor)
                    .scaleEffect(leftScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cmd)

                VStack(spacing: 8) {
                    Text(caneController.steeringCommandText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(caneController.steeringColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("Power: \(Int(caneController.motorIntensity))/255")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(caneController.motorIntensity > 0 ? .orange : secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Capsule())

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 76, height: 76)
                            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        Circle()
                            .fill(caneController.steeringColor)
                            .frame(width: 56, height: 56)
                            .offset(x: dotOffset)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cmd)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geometry.size.width * CGFloat(caneController.motorIntensity / 255.0), height: 5)
                                .animation(.easeOut(duration: 0.2), value: caneController.motorIntensity)
                        }
                    }
                    .frame(height: 5)
                    .padding(.horizontal, 4)
                }

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(rightColor)
                    .scaleEffect(rightScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cmd)
            }
            .padding(16)
            .background(glassCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(caneController.steeringColor.opacity(0.4), lineWidth: 1))
        }
        .padding(16)
        .background(glassCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(glassBorder, lineWidth: 1))
    }

    // MARK: - Navigation Compass

    @ViewBuilder
    private func compassSection(nav: NavigationManager) -> some View {
        let heading = nav.caneHeadingDegrees
        let bearing = nav.bearingToWaypointDegrees
        let error   = nav.headingErrorDegrees
        let bias    = nav.navBiasValue

        VStack(spacing: 14) {
            sectionLabel("Navigation Compass", icon: "location.north.circle.fill", color: .cyan)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1.5)
                    .frame(width: 130, height: 130)

                Group {
                    ForEach(0..<12, id: \.self) { i in
                        let angle = Double(i) * 30.0
                        let isMajor = i % 3 == 0
                        Rectangle()
                            .fill(isMajor ? Color.white.opacity(0.8) : Color.white.opacity(0.25))
                            .frame(width: isMajor ? 2 : 1, height: isMajor ? 12 : 8)
                            .offset(y: -55)
                            .rotationEffect(.degrees(angle))
                    }
                    Text("N").font(.system(size: 11, weight: .bold)).foregroundColor(.red).offset(y: -42)
                    Text("E").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.5)).offset(x: 42)
                    Text("S").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.5)).offset(y: 42)
                    Text("W").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.5)).offset(x: -42)
                }
                .rotationEffect(.degrees(-heading))

                Path { path in
                    let center = CGPoint(x: 65, y: 65)
                    let radius: CGFloat = 50
                    path.addArc(center: center, radius: radius,
                                startAngle: .degrees(-90), endAngle: .degrees(-90 + error),
                                clockwise: error < 0)
                }
                .stroke(Color.orange.opacity(0.5), lineWidth: 5)
                .frame(width: 130, height: 130)

                let arrowAngle = bearing - heading
                VStack(spacing: 0) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)
                    Rectangle().fill(Color.cyan).frame(width: 2, height: 20)
                }
                .offset(y: -22)
                .rotationEffect(.degrees(arrowAngle))

                Circle().fill(Color.white).frame(width: 8, height: 8)
            }
            .frame(width: 130, height: 130)

            HStack(spacing: 0) {
                compassStat(label: "Heading",    value: "\(Int(heading))°",             color: .white)
                statDivider
                compassStat(label: "WP Bearing", value: "\(Int(bearing))°",             color: .cyan)
                statDivider
                compassStat(label: "Error",      value: String(format: "%+.0f°", error), color: abs(error) > 45 ? .orange : .green)
                statDivider
                compassStat(label: "Bias",       value: String(format: "%+.2f", bias),   color: bias < -0.1 ? .blue : bias > 0.1 ? .purple : .green)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(glassCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(glassBorder, lineWidth: 1))
    }

    private var statDivider: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 28).padding(.horizontal, 8)
    }

    @ViewBuilder
    private func compassStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Depth Map

    private var depthMapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Depth Map", icon: "chart.bar.fill", color: .cyan)

            if let depthImage = caneController.depthVisualization {
                GeometryReader { containerGeometry in
                    ZStack {
                        Image(uiImage: depthImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: containerGeometry.size.width, height: isLandscape ? 280 : 240)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        zoneOverlay(width: containerGeometry.size.width, height: isLandscape ? 280 : 240)
                    }
                }
                .frame(height: isLandscape ? 280 : 240)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.cyan.opacity(0.4), lineWidth: 1.5))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: isLandscape ? 280 : 240)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }

            HStack(spacing: 6) {
                Text("0.2m").font(.system(size: 10, weight: .medium)).foregroundStyle(secondary)
                LinearGradient(gradient: Gradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue]),
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 6).clipShape(Capsule())
                Text("3.0m").font(.system(size: 10, weight: .medium)).foregroundStyle(secondary)
            }
        }
        .padding(16)
        .background(glassCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(glassBorder, lineWidth: 1))
    }

    // MARK: - Camera Preview

    private var cameraPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Live Camera + Detection", icon: "camera.fill", color: .yellow)

            if let cameraImage = caneController.cameraPreview {
                GeometryReader { containerGeometry in
                    ZStack {
                        Image(uiImage: cameraImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: containerGeometry.size.width, height: isLandscape ? 280 : 240)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        zoneOverlay(width: containerGeometry.size.width, height: isLandscape ? 280 : 240)
                    }
                }
                .frame(height: isLandscape ? 280 : 240)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.yellow.opacity(0.4), lineWidth: 1.5))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: isLandscape ? 280 : 240)
                    VStack(spacing: 8) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Initializing camera...")
                            .font(.caption)
                            .foregroundStyle(secondary)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill").font(.caption).foregroundStyle(.yellow.opacity(0.7))
                Text("Yellow box shows detected person").font(.system(size: 11)).foregroundStyle(secondary)
            }
        }
        .padding(16)
        .background(glassCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(glassBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func zoneOverlay(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Color.yellow.opacity(0.8)).frame(width: 2, height: height)
                .position(x: width * 0.33, y: height / 2)
            Rectangle().fill(Color.yellow.opacity(0.8)).frame(width: 2, height: height)
                .position(x: width * 0.67, y: height / 2)
            Text("L").font(.system(size: 20, weight: .bold)).foregroundColor(.white).shadow(color: .black, radius: 2)
                .position(x: width * 0.165, y: 25)
            VStack(spacing: 2) {
                Text("C").font(.system(size: 20, weight: .bold)).foregroundColor(.white).shadow(color: .black, radius: 2)
                Text("~0.5m").font(.system(size: 12, weight: .semibold)).foregroundColor(.yellow).shadow(color: .black, radius: 2)
            }
            .position(x: width * 0.5, y: 30)
            Text("R").font(.system(size: 20, weight: .bold)).foregroundColor(.white).shadow(color: .black, radius: 2)
                .position(x: width * 0.835, y: 25)
        }
    }

    // MARK: - Terrain Debug

    private var terrainDebugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Terrain Debug", icon: "leaf.fill", color: .green)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(caneController.terrainDetected ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                    Text(caneController.terrainDetected ? caneController.detectedTerrainType.capitalized : "Clear")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(caneController.terrainDetected ? .orange : .green)
                }
            }

            HStack(spacing: 12) {
                terrainZoneBar(label: "L", coverage: caneController.terrainLeftCoverage)
                terrainZoneBar(label: "C", coverage: caneController.terrainCenterCoverage)
                terrainZoneBar(label: "R", coverage: caneController.terrainRightCoverage)
            }
            .frame(height: 80)

            if let overlayImage = caneController.terrainDebugImage {
                ZStack {
                    if let cameraImage = caneController.cameraPreview {
                        Image(uiImage: cameraImage)
                            .resizable().scaledToFill().frame(height: 200).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    Image(uiImage: overlayImage)
                        .resizable().scaledToFill().frame(height: 200).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.green.opacity(0.4), lineWidth: 1))

                HStack(spacing: 14) {
                    terrainLegend(.green, "Vegetation")
                    terrainLegend(.brown,  "Dirt")
                    terrainLegend(.gray,   "Road")
                    terrainLegend(.blue,   "Sidewalk")
                }
            } else {
                Text("Enable camera preview to see segmentation overlay")
                    .font(.caption).foregroundStyle(secondary)
            }
        }
        .padding(16)
        .background(glassCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.green.opacity(0.28), lineWidth: 1))
    }

    @ViewBuilder
    private func terrainLegend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
        }
    }

    @ViewBuilder
    private func terrainZoneBar(label: String, coverage: Float) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.7))
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: geometry.size.width, height: 60)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(coverage > 0.15 ? Color.orange : Color.green)
                        .frame(width: geometry.size.width, height: 60 * CGFloat(coverage))
                }
            }
            .frame(height: 60)
            Text("\(Int(coverage * 100))%").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Detected Object

    @ViewBuilder
    private func detectedObjectSection(object: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "person.fill").foregroundStyle(.yellow).font(.caption)
                    Text("Detected Object").font(.system(size: 11, weight: .semibold)).foregroundStyle(secondary)
                }
                Text(object.capitalized)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                if let distance = caneController.detectedObjectDistance {
                    HStack(spacing: 6) {
                        Image(systemName: "ruler").font(.caption).foregroundStyle(.cyan)
                        Text(String(format: "%.2f meters away", distance)).font(.subheadline).foregroundStyle(.cyan)
                    }
                }
            }
            Spacer()
            if let distance = caneController.detectedObjectDistance {
                ZStack {
                    Circle().stroke(Color.yellow.opacity(0.2), lineWidth: 3).frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(3.0 / max(distance, 0.1)), 1.0))
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    Text(String(format: "%.1f", distance))
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [Color.yellow.opacity(0.12), Color.orange.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.yellow.opacity(0.32), lineWidth: 1))
        .shadow(color: Color.yellow.opacity(0.12), radius: 12)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: caneController.detectedObject)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 12) {
            Button(action: { caneController.toggleSystem() }) {
                HStack(spacing: 10) {
                    Image(systemName: caneController.isSystemActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title3)
                    Text(caneController.isSystemActive ? "Stop System" : "Start System")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: caneController.isSystemActive
                            ? [Color.red, Color.red.opacity(0.75)]
                            : [Color(red: 0.1, green: 0.75, blue: 0.4), Color(red: 0.05, green: 0.6, blue: 0.3)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: (caneController.isSystemActive ? Color.red : Color.green).opacity(0.3), radius: 10, y: 4)
            }

            HStack(spacing: 10) {
                iconToggle(icon: caneController.showDepthVisualization ? "eye.slash.fill" : "eye.fill",
                           label: caneController.showDepthVisualization ? "Hide Depth" : "Show Depth",
                           color: caneController.showDepthVisualization ? .orange : .indigo) {
                    caneController.toggleDepthVisualization()
                }
                iconToggle(icon: caneController.showCameraPreview ? "video.slash.fill" : "video.fill",
                           label: caneController.showCameraPreview ? "Hide Camera" : "Show Camera",
                           color: caneController.showCameraPreview ? .purple : .teal) {
                    caneController.toggleCameraPreview()
                }
                iconToggle(icon: caneController.terrainDebugMode ? "leaf.circle.fill" : "leaf.circle",
                           label: caneController.terrainDebugMode ? "Debug ON" : "Terrain",
                           color: caneController.terrainDebugMode ? .green : .gray) {
                    caneController.toggleTerrainDebugMode()
                }
            }

            HStack(spacing: 10) {
                actionBtn(icon: "speaker.wave.2.fill", label: "Test Voice", color: .blue) { caneController.testVoice() }
                actionBtn(icon: "map.fill",            label: "Navigate",   color: .cyan) { showNavigationSheet = true }
            }
        }
    }

    @ViewBuilder
    private func iconToggle(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(color.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func actionBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label).font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(color.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Vapi

    @ViewBuilder
    private var vapiSection: some View {
        VStack(spacing: 12) {
            HStack {
                sectionLabel("Voice Assistant", icon: "waveform.circle.fill", color: .mint)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(caneController.isVapiCallActive ? Color.green : Color.white.opacity(0.25))
                        .frame(width: 7, height: 7)
                    Text(caneController.isVapiCallActive ? "Active" : "Inactive")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(caneController.isVapiCallActive ? .green : secondary)
                }
            }

            HStack(spacing: 10) {
                Button(action: {
                    if caneController.isVapiCallActive { caneController.stopVapiCall() }
                    else { caneController.startVapiCall() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: caneController.isVapiCallActive ? "phone.down.fill" : "phone.fill").font(.title3)
                        Text(caneController.isVapiCallActive ? "End Call" : "Start Call")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(caneController.isVapiCallActive ? Color.red.opacity(0.8) : Color.mint.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if caneController.isVapiCallActive {
                    Button(action: { caneController.toggleVapiMute() }) {
                        let muted = caneController.vapiManager?.isMuted == true
                        VStack(spacing: 4) {
                            Image(systemName: muted ? "mic.slash.fill" : "mic.fill").font(.title3)
                            Text(muted ? "Unmute" : "Mute").font(.system(size: 10, weight: .medium))
                        }
                        .frame(width: 68)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(muted ? Color.orange.opacity(0.75) : Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            if let transcript = caneController.vapiTranscript {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.bubble.fill").font(.caption).foregroundStyle(.mint)
                    Text(transcript).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8)).lineLimit(3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let error = caneController.vapiError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
                    Text(error).font(.system(size: 12)).foregroundStyle(.red.opacity(0.85)).lineLimit(2)
                }
            }
        }
        .padding(16)
        .background(glassCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(caneController.isVapiCallActive ? Color.mint.opacity(0.45) : glassBorder, lineWidth: 1))
    }

    // MARK: - Shared Helpers

    @ViewBuilder
    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(secondary)
        }
    }

    private func formatDistance(_ distance: Float?) -> String {
        guard let dist = distance else { return "Clear" }
        if dist > 4.0 { return "Clear" }
        return String(format: "%.2fm", dist)
    }

    private func getDistanceColor(_ distance: Float?) -> Color {
        guard let dist = distance else { return .green }
        if dist < 0.5 { return .red }
        else if dist < 1.0 { return .orange }
        else if dist < 2.0 { return .yellow }
        else { return .green }
    }
}

#Preview {
    let espBT = ESPBluetoothManager()
    let controller = PathSenseController()
    controller.initialize(espBluetooth: espBT)
    return ContentView(caneController: controller, espBluetooth: espBT)
}
