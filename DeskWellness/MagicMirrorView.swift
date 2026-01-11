//
//  MagicMirrorView.swift
//  DeskWellness
//
//  Created by P Dev on 1/11/26.
//

import SwiftUI
import AVFoundation

struct MagicMirrorView: View {
    @StateObject private var engine = PostureEngine()
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            // 1. Camera Layer (You'll need a standard CameraPreview view wrapping the session)
            // For code brevity, assume CameraPreview(session: engine.captureSession) exists
            CameraPreview(session: engine.captureSession)
                .ignoresSafeArea()

            // 2. Dimming Overlay (Makes the UI pop)
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // 3. The "Wow" Visualization Layer
            if let points = engine.normalizedPoints, engine.isLocked {
                GeometryReader { geo in
                    let ear = CGPoint(x: points.ear.x * geo.size.width, y: points.ear.y * geo.size.height)
                    let shoulder = CGPoint(x: points.shoulder.x * geo.size.width, y: points.shoulder.y * geo.size.height)

                    // The Glowing Line
                    Path { path in
                        path.move(to: shoulder)
                        path.addLine(to: ear)
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: getStatusColor(angle: engine.headAngle)),
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .shadow(color: getStatusColor(angle: engine.headAngle).last!, radius: 10) // GLOW EFFECT

                    // The Joints (Premium Polish)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .position(ear)
                        .shadow(radius: 5)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .position(shoulder)
                }
            }

            // 4. The HUD
            VStack {
                Spacer()

                if engine.isLocked {
                    VStack(spacing: 8) {
                        Text(String(format: "%.0f°", engine.headAngle))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(getFeedbackText(angle: engine.headAngle))
                            .font(.headline)
                            .foregroundColor(getStatusColor(angle: engine.headAngle).last!)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                    }
                    .padding(.bottom, 50)
                    .transition(.opacity.animation(.easeInOut))
                    .onChange(of: engine.headAngle) { newAngle in
                        triggerHaptic(angle: newAngle)
                    }
                } else {
                    // Scanning State
                    Text("Align side profile...")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            checkPermissions()
            engine.start()

        }
        .onDisappear { engine.stop() }
    }

    // MARK: - Logic Helpers

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { engine.start() }
            }
        default:
            print("Camera permission denied")
        }
    }


    // Returns Gradient Colors based on posture quality
    func getStatusColor(angle: Double) -> [Color] {
        if angle > 25 { return [.red, .orange] } // Bad
        if angle > 10 { return [.yellow, .orange] } // Okay
        return [.blue, .cyan] // Perfect (The "Wow" Green/Blue)
    }

    func getFeedbackText(angle: Double) -> String {
        if angle > 25 { return "HEAD FORWARD" }
        if angle > 10 { return "ALMOST THERE" }
        return "PERFECT ALIGNMENT"
    }

    func triggerHaptic(angle: Double) {
        // Trigger a HEAVY thud if user crosses the "Bad" threshold
        if angle > 25 && angle < 26 {
            feedbackGenerator.notificationOccurred(.warning)
        }
        // Trigger a PLEASANT ping if user hits "Perfect"
        if angle < 10 && angle > 9 {
            feedbackGenerator.notificationOccurred(.success)
        }
    }
}
