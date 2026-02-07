//
//  MagicMirrorView.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 1/11/26.
//
//  NOTE: This view is currently unused but provides an alternative real-time
//  posture monitoring experience. Consider integrating or removing.
//

import SwiftUI
import AVFoundation

struct MagicMirrorView: View {
    @StateObject private var engine = PostureEngine()
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()
    @State private var showCameraPermissionAlert = false
    @State private var previousAngle: Double = 0

    var body: some View {
        ZStack {
            // 1. Camera Layer
            CameraPreview(session: engine.captureSession)
                .ignoresSafeArea()

            // 2. Dimming Overlay
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
                            gradient: Gradient(colors: PostureConstants.colors(for: engine.headAngle)),
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .shadow(color: PostureConstants.colors(for: engine.headAngle).last!, radius: 10)

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

                        Text(PostureConstants.feedbackText(for: engine.headAngle))
                            .font(.headline)
                            .foregroundColor(PostureConstants.colors(for: engine.headAngle).last!)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                    }
                    .padding(.bottom, 50)
                    .transition(.opacity.animation(.easeInOut))
                    .onChange(of: engine.headAngle) { oldAngle, newAngle in
                        triggerHaptic(oldAngle: oldAngle, newAngle: newAngle)
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
            checkCameraPermission()
        }
        .onDisappear {
            engine.stop()
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

    // MARK: - Haptic Feedback

    private func triggerHaptic(oldAngle: Double, newAngle: Double) {
        // Trigger warning when crossing into "bad" threshold
        if oldAngle <= PostureConstants.badAngleThreshold && newAngle > PostureConstants.badAngleThreshold {
            feedbackGenerator.notificationOccurred(.warning)
        }
        // Trigger success when crossing into "perfect" threshold
        if oldAngle >= PostureConstants.perfectAngleThreshold && newAngle < PostureConstants.perfectAngleThreshold {
            feedbackGenerator.notificationOccurred(.success)
        }
    }
}
