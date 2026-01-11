//
//  ContentView.swift
//  DeskWellness
//
//  Created by P Dev on 30.04.2025.
//
//
//  ContentView.swift
//  DeskWellness
//
//  P Dev on 30.04.2025.
//
import SwiftUI
import AVFoundation

// 1. App State Machine
enum AppState {
    case scanning
    case result(score: Int, image: Image?)
    case paywall

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

struct ContentView: View {
    @StateObject private var engine = PostureEngine()
    @State private var appState: AppState = .scanning
    @State private var scanDuration: Double = 0.0
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()

    // Timer for the "Scan" phase
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
                        // Action: Go to Paywall
                        withAnimation { appState = .paywall }
                    }
                case .paywall:
                    PaywallView {
                        // Action: Reset
                        appState = .scanning
                        scanDuration = 0
                        engine.start()
                    }
                }
            }
        }
        .onAppear { engine.start() }
        .onReceive(scanTimer) { _ in
            if case .scanning = appState, engine.isLocked {
                scanDuration += 1
                // Auto-finish scan after 5 seconds of good data
                if scanDuration >= 5 {
                    finishScan()
                }
            }
            
            if engine.isLocked {
                if scanDuration == 0 { speak("Hold still.") }
                if scanDuration == 3 { speak("Done.") }
            } else {
                // Debounce this so it doesn't spam
                if Int(Date().timeIntervalSince1970) % 3 == 0 {
                    speak("I can't see your side profile.")
                }
            }
        }
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    func finishScan() {
        // Calculate Score (0-100) based on angle
        // Angle > 30 is bad (Score 40). Angle < 10 is perfect (Score 100).
        let angle = engine.headAngle
        // If angle is 0 (Perfect), Score = 100.
        // If angle is 45 (Bad), Score = 100 - 90 = 10.

        let score = Int(max(0, min(100, 100 - (angle * 2))))

        feedbackGenerator.notificationOccurred(.success)
        withAnimation {
            appState = .result(score: score, image: nil)
        }
        engine.stop() // Freeze camera
    }
}

// MARK: - Subviews for the "Wow" Effect

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
                    gradient: Gradient(colors: getColors(angle: angle)),
                    startPoint: .bottom, endPoint: .top
                ),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            .shadow(color: getColors(angle: angle).last!, radius: 15) // MAXIMUM GLOW

            // The Joints
            Circle().fill(.white).frame(width: 12).position(ear).shadow(radius: 5)
            Circle().fill(.white).frame(width: 12).position(shoulder)
        }
    }

    func getColors(angle: Double) -> [Color] {
        if angle > 25 { return [.red, .orange] }
        return [.cyan, .blue] // "Wow" Colors
    }
}

struct ScanningView: View {
    let angle: Double
    let isLocked: Bool

    var body: some View {
        if isLocked {
            VStack(spacing: 4) {
                Text(String(format: "%.0f°", angle))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(angle > 25 ? "HEAD FORWARD" : "GOOD ALIGNMENT")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(angle > 25 ? Color.red : Color.blue)
                    .cornerRadius(20)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 60)
            .transition(.scale)
        } else {
            Text("Turn side-on to camera")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 60)
                .transition(.opacity)
        }
    }
}

struct ResultView: View {
    let score: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // The "Score Card"
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
            .background(Color.black.opacity(0.8)) // Glass effect
            .cornerRadius(20)

            // The "Sell" Button
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

            Button(action: { /* Integrate RevenueCat Here */ }) {
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
