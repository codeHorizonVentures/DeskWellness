//
//  ContentView.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 30.04.2025.
//

import SwiftUI
import AVFoundation

// MARK: - App State Machine

enum AppState {
    case scanning
    case result(score: Int, image: Image?)
    case paywall

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var engine = PostureEngine()
    @State private var appState: AppState = .scanning
    @State private var scanDuration: Double = 0.0
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()
    @State private var lastSpeechTime: Date = .distantPast
    @State private var showCameraPermissionAlert = false

    let scanTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            // LAYER 1: The Camera Feed (Always visible in background)
            CameraPreview(session: engine.captureSession)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(appState.isScanning ? 0.2 : 0.8))
                .blur(radius: appState.isScanning ? 0 : 10)

            // LAYER 2: The "Magic" Lines (Only during scanning)
            if case .scanning = appState, engine.isLocked, let points = engine.normalizedPoints {
                PostureOverlay(points: points, angle: engine.headAngle)
            }

            // LAYER 3: The UI Overlay
            VStack {
                // Top Bar
                HStack {
                    Image(systemName: "figure.mind.and.body")
                        .foregroundColor(.white)
                    Text("DeskWellness")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if case .scanning = appState {
                        Text(engine.isLocked ? "LOCKED" : "SCANNING...")
                            .font(.caption)
                            .padding(6)
                            .background(engine.isLocked ? Color.green : Color.gray)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                }
                .padding()

                Spacer()

                // Bottom Area Changes based on State
                switch appState {
                case .scanning:
                    ScanningView(angle: engine.headAngle, isLocked: engine.isLocked)
                case .result(let score, _):
                    ResultView(score: score) {
                        withAnimation { appState = .paywall }
                    }
                case .paywall:
                    PaywallView {
                        appState = .scanning
                        scanDuration = 0
                        engine.start()
                    }
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .onReceive(scanTimer) { _ in
            handleScanTimer()
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("DeskWellness needs camera access to analyze your posture. Please enable it in Settings.")
        }
    }

    // MARK: - Camera Permission

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            engine.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        engine.start()
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            showCameraPermissionAlert = true
        }
    }

    // MARK: - Speech with Debounce

    private func speakDebounced(_ text: String) {
        let now = Date()
        guard now.timeIntervalSince(lastSpeechTime) >= PostureConstants.speechDebounceInterval else { return }
        lastSpeechTime = now

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    // MARK: - Scan Timer Logic

    private func handleScanTimer() {
        guard case .scanning = appState else { return }

        if engine.isLocked {
            scanDuration += 1

            if scanDuration == 1 {
                speakDebounced("Hold still.")
            } else if scanDuration == 3 {
                speakDebounced("Done.")
            }

            if scanDuration >= PostureConstants.scanLockDuration {
                finishScan()
            }
        } else {
            speakDebounced("I can't see your side profile.")
        }
    }

    private func finishScan() {
        let score = PostureConstants.score(for: engine.headAngle)

        feedbackGenerator.notificationOccurred(.success)
        withAnimation {
            appState = .result(score: score, image: nil)
        }
        engine.stop()
    }
}

// MARK: - Posture Overlay

struct PostureOverlay: View {
    let points: (ear: CGPoint, shoulder: CGPoint)
    let angle: Double

    var body: some View {
        GeometryReader { geo in
            let ear = CGPoint(x: points.ear.x * geo.size.width, y: points.ear.y * geo.size.height)
            let shoulder = CGPoint(x: points.shoulder.x * geo.size.width, y: points.shoulder.y * geo.size.height)

            // The "Lightsaber" Line
            Path { path in
                path.move(to: shoulder)
                path.addLine(to: ear)
            }
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: PostureConstants.colors(for: angle)),
                    startPoint: .bottom, endPoint: .top
                ),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            .shadow(color: PostureConstants.colors(for: angle).last!, radius: 15)

            // The Joints
            Circle().fill(.white).frame(width: 12).position(ear).shadow(radius: 5)
            Circle().fill(.white).frame(width: 12).position(shoulder)
        }
    }
}

// MARK: - Scanning View

struct ScanningView: View {
    let angle: Double
    let isLocked: Bool
    @State private var isAnimating = false

    var body: some View {
        if isLocked {
            VStack(spacing: 4) {
                Text(String(format: "%.0f°", angle))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(PostureConstants.statusText(for: angle))
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(angle > PostureConstants.badAngleThreshold ? Color.red : Color.blue)
                    .cornerRadius(20)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 60)
            .transition(.scale)
        } else {
            SideProfileGuidanceView(isAnimating: $isAnimating)
                .padding(.bottom, 40)
                .transition(.opacity)
                .onAppear { isAnimating = true }
        }
    }
}

// MARK: - Side Profile Guidance View

struct SideProfileGuidanceView: View {
    @Binding var isAnimating: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Visual instruction with animated icons
            HStack(spacing: 24) {
                // Front-facing person (current position - faded)
                ZStack {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Animated turning arrow
                Image(systemName: "arrow.turn.right.up")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.cyan)
                    .rotationEffect(.degrees(isAnimating ? 0 : -10))
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                // Side profile person in viewfinder (target position - highlighted)
                ZStack {
                    // Viewfinder frame
                    Image(systemName: "viewfinder")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.cyan)

                    // 3D rotated person to suggest side view
                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)
                        .rotation3DEffect(.degrees(50), axis: (x: 0, y: 1, z: 0))
                }
                .overlay(
                    // Pulsing highlight
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan, lineWidth: 2)
                        .frame(width: 70, height: 70)
                        .scaleEffect(isAnimating ? 1.15 : 1.0)
                        .opacity(isAnimating ? 0 : 0.8)
                        .animation(
                            .easeOut(duration: 1.2)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                )
            }

            // Text instructions
            VStack(spacing: 6) {
                Text("Turn sideways to the camera")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                Text("Show your side profile so we can measure your posture")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.6))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Result View

struct ResultView: View {
    let score: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Text("Your Desk Score")
                    .textCase(.uppercase)
                    .font(.caption)
                    .foregroundColor(.gray)

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(score > 80 ? Color.green : Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                    Text("\(score)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(score > 80 ? "Great Posture" : "Requires Correction")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)

            Button(action: onContinue) {
                Text("See How to Fix This")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 40)
        .transition(.move(edge: .bottom))
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Unlock the 12-Week Clinic")
                .font(.title)
                .bold()
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "checkmark.circle.fill", text: "Daily 5-min Correction Plan")
                FeatureRow(icon: "checkmark.circle.fill", text: "Real-time AI Posture Alerts")
                FeatureRow(icon: "checkmark.circle.fill", text: "Pain Relief Tracking")
            }
            .padding()

            Button(action: {
                // TODO: Integrate RevenueCat Here
            }) {
                Text("Start 7-Day Free Trial")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Button("Retake Scan", action: onReset)
                .foregroundColor(.gray)
                .padding(.top)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .transition(.move(edge: .bottom))
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.green)
            Text(text).foregroundColor(.primary)
        }
    }
}
