//
//  ContentView.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 30.04.2025.
//

import SwiftUI
import AVFoundation
import StoreKit

// MARK: - App State Machine

enum AppState {
    case frontScanning              // Phase 1: Front-facing detection
    case frontResult(FrontScore)    // Show front results, prompt for side if needed
    case sideScanning               // Phase 2: Side profile detection (optional)
    case finalResult(FinalScore)    // Combined score
    case paywall

    var isScanning: Bool {
        switch self {
        case .frontScanning, .sideScanning: return true
        default: return false
        }
    }
}

struct FrontScore {
    let shoulderTilt: Double    // ° asymmetry
    let headTilt: Double        // ° offset
    let score: Int              // 0-100
    let needsSideScan: Bool     // Forward head suspected?
}

struct FinalScore {
    let frontScore: FrontScore
    let cva: Double?                // Craniovertebral Angle (nil if skipped)
    let forwardHeadAngle: Double?   // Legacy: nil if side scan skipped
    let combinedScore: Int
}

// MARK: - Main Content View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = PostureEngine()
    @State private var appState: AppState = .frontScanning
    @State private var scanDuration: Double = 0.0
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()
    @State private var lastSpeechTime: Date = .distantPast
    @State private var showJournal = false
    @State private var showCameraPermissionAlert = false
    @State private var frontScore: FrontScore? = nil
    @State private var showPostureTips = false
    @State private var frontSnapshot: UIImage?
    @State private var sideSnapshot: UIImage?

    let scanTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            // LAYER 1: The Camera Feed (Always visible in background)
            CameraPreview(session: engine.captureSession)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(appState.isScanning ? 0.2 : 0.8))
                .blur(radius: appState.isScanning ? 0 : 10)
                .overlay(alignment: .topLeading) {
                    if appState.isScanning {
                        Button(action: { showJournal = true }) {
                            Image(systemName: "book.closed.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Material.thinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        .padding(.top, 60)
                    }
                }

            // LAYER 2: Scanning Effects
            if case .frontScanning = appState, engine.isFrontLocked, let points = engine.frontPoints {
                FrontScanningEffectsView(
                    points: points,
                    isLocked: engine.isFrontLocked,
                    showDebug: PostureConstants.showDebugOverlay
                )
            }
            
            if case .sideScanning = appState, engine.isSideLocked, let points = engine.sidePoints {
                ScanningEffectsView(
                    points: points,
                    isLocked: engine.isSideLocked,
                    showDebug: PostureConstants.showDebugOverlay
                )
            }

            // LAYER 3: The UI Overlay
            VStack {
                // Top Bar
                TopBarView(appState: appState, engine: engine)

                Spacer()

                // Bottom Area Changes based on State
                switch appState {
                case .frontScanning:
                    FrontScanningView(
                        shoulderTilt: engine.shoulderTilt,
                        headTilt: engine.headTilt,
                        isLocked: engine.isFrontLocked
                    )
                    
                case .frontResult(let score):
                    FrontResultView(score: score) {
                        // User wants side scan - restart camera and switch mode
                        engine.switchToSideMode()
                        engine.start()
                        scanDuration = 0
                        withAnimation { appState = .sideScanning }
                    } onSkip: {
                        // Skip side scan, go to final result
                        let final = FinalScore(
                            frontScore: score,
                            cva: nil,
                            forwardHeadAngle: nil,
                            combinedScore: score.score
                        )
                        withAnimation { appState = .finalResult(final) }
                    }
                    
                case .sideScanning:
                    SideScanningView(
                        cva: engine.cva,
                        isLocked: engine.isSideLocked
                    )
                    
                case .finalResult(let score):
                    FinalResultView(score: score, onRestart: {
                        engine.reset()
                        scanDuration = 0
                        appState = .frontScanning
                        engine.start()
                    }, onContinue: {
                        showPostureTips = true
                    }, onSave: { didExercise in
                        let id = UUID().uuidString
                        var sidePath: String?
                        var frontPath: String?
                        
                        // Optimize & Save Side Snapshot
                        if let sideImage = sideSnapshot?.resized(toMaxDimension: 1024),
                           let data = sideImage.jpegData(compressionQuality: 0.7) {
                            let filename = "\(id)_side.jpg"
                            if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename) {
                                try? data.write(to: url)
                                sidePath = filename
                            }
                        }
                        
                        // Optimize & Save Front Snapshot
                        if let frontImage = frontSnapshot?.resized(toMaxDimension: 1024),
                           let data = frontImage.jpegData(compressionQuality: 0.7) {
                            let filename = "\(id)_front.jpg"
                            if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename) {
                                try? data.write(to: url)
                                frontPath = filename
                            }
                        }
                        
                        // Encode Points Data (Schema)
                        let frontData = try? JSONEncoder().encode(engine.frontPoints)
                        let sideData = try? JSONEncoder().encode(engine.sidePoints)
                        
                        // Create Entry
                        let entry = DailyEntry(
                            type: .scan,
                            note: "Posture Scan Result",
                            photoPath: sidePath,
                            frontPhotoPath: frontPath,
                            exercisesCompleted: didExercise,
                            cvaScore: score.cva,
                            frontPointsData: frontData,
                            sidePointsData: sideData
                        )
                        modelContext.insert(entry)
                    })
                    .transition(.opacity)
                case .paywall:
                    PaywallView {
                        engine.reset()
                        scanDuration = 0
                        appState = .frontScanning
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
        .sheet(isPresented: $showPostureTips) {
            PostureTipView()
        }
        .sheet(isPresented: $showJournal) {
            JournalView(showJournal: $showJournal)
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
        switch appState {
        case .frontScanning:
            handleFrontScan()
        case .sideScanning:
            handleSideScan()
        default:
            break
        }
    }
    
    private func handleFrontScan() {
        if engine.isFrontLocked {
            scanDuration += 1
            
            if scanDuration == 1 {
                speakDebounced("Hold still.")
            }
            
            if scanDuration >= PostureConstants.scanLockDuration {
                finishFrontScan()
            }
        }
    }
    
    private func handleSideScan() {
        if engine.isSideLocked {
            scanDuration += 1
            
            if scanDuration == 1 {
                speakDebounced("Hold still.")
            }
            
            if scanDuration >= PostureConstants.scanLockDuration {
                finishSideScan()
            }
        } else {
            speakDebounced("Turn sideways to the camera.")
        }
    }

    private func finishFrontScan() {
        frontSnapshot = engine.captureSnapshot(for: .front)
        // Calculate front score
        let shoulderScore = max(0, 100 - abs(engine.shoulderTilt) * 5) // -5 per degree
        let headScore = max(0, 100 - abs(engine.headTilt) * 3)         // -3 per degree offset
        let combinedFrontScore = Int((shoulderScore + headScore) / 2)
        
        // Determine if side scan is needed (if front posture is reasonably good)
        // Only suggest side scan if front is okay but we want more precision
        let needsSide = combinedFrontScore > 60 // Good front posture, check for forward head
        
        let score = FrontScore(
            shoulderTilt: engine.shoulderTilt,
            headTilt: engine.headTilt,
            score: combinedFrontScore,
            needsSideScan: needsSide
        )
        
        frontScore = score
        feedbackGenerator.notificationOccurred(.success)
        engine.stop()
        
        withAnimation {
            appState = .frontResult(score)
        }
    }
    
    private func finishSideScan() {
        sideSnapshot = engine.captureSnapshot(for: .side)
        guard let front = frontScore else { return }
        
        // Use CVA-based scoring (clinical methodology)
        let cvaScore = PostureConstants.cvaScore(for: engine.cva)
        let combinedScore = (front.score + cvaScore) / 2
        
        let final = FinalScore(
            frontScore: front,
            cva: engine.cva,
            forwardHeadAngle: engine.forwardHeadAngle,
            combinedScore: combinedScore
        )
        
        feedbackGenerator.notificationOccurred(.success)
        engine.stop()
        
        withAnimation {
            appState = .finalResult(final)
        }
    }
}

// MARK: - Top Bar View

struct TopBarView: View {
    let appState: AppState
    let engine: PostureEngine
    
    var body: some View {
        HStack {
            Image(systemName: "figure.mind.and.body")
                .foregroundColor(.white)
            Text("DeskWellness")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            
            if appState.isScanning {
                Text(statusText)
                    .font(.caption)
                    .padding(6)
                    .background(statusColor)
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
    
    private var statusText: String {
        switch appState {
        case .frontScanning:
            return engine.isFrontLocked ? "LOCKED" : "SCANNING..."
        case .sideScanning:
            return engine.isSideLocked ? "LOCKED" : "TURN SIDEWAYS"
        default:
            return ""
        }
    }
    
    private var statusColor: Color {
        switch appState {
        case .frontScanning:
            return engine.isFrontLocked ? .green : .gray
        case .sideScanning:
            return engine.isSideLocked ? .green : .orange
        default:
            return .gray
        }
    }
}

// MARK: - Front Scanning View

struct FrontScanningView: View {
    let shoulderTilt: Double
    let headTilt: Double
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 16) {
            if isLocked {
                // Show live metrics
                VStack(spacing: 8) {
                    HStack(spacing: 30) {
                        MetricView(
                            label: "SHOULDERS",
                            value: String(format: "%.0f°", abs(shoulderTilt)),
                            icon: shoulderTilt > 0 ? "arrow.up.right" : "arrow.up.left",
                            isGood: abs(shoulderTilt) < 5
                        )
                        MetricView(
                            label: "HEAD",
                            value: String(format: "%.0f°", abs(headTilt)),
                            icon: headTilt > 0 ? "arrow.right" : "arrow.left",
                            isGood: abs(headTilt) < 3
                        )
                    }
                    
                    Text("Hold still...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.6)))
                .transition(.scale)
            } else {
                // Guidance to face camera
                FrontGuidanceView()
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 40)
    }
}

struct MetricView: View {
    let label: String
    let value: String
    let icon: String
    let isGood: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            .foregroundColor(isGood ? .cyan : .orange)
        }
    }
}

struct FrontGuidanceView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Image(systemName: "viewfinder")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.cyan)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.cyan)
            }
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 6) {
                Text("Face the camera")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                
                Text("Stand naturally and look straight ahead")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.6)))
        .onAppear { isAnimating = true }
    }
}

// MARK: - Side Scanning View

struct SideScanningView: View {
    let cva: Double          // Craniovertebral Angle
    let isLocked: Bool
    @State private var isAnimating = false

    var body: some View {
        if isLocked {
            VStack(spacing: 4) {
                Text(String(format: "%.0f°", cva))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(PostureConstants.cvaStatus(for: cva))
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(cva >= PostureConstants.cvaNormal ? Color.green : (cva >= PostureConstants.cvaMildFHP ? Color.cyan : Color.orange))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                Text("Neck Angle")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
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
            HStack(spacing: 24) {
                // Front-facing person (faded)
                ZStack {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Arrow
                Image(systemName: "arrow.turn.right.up")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.cyan)
                    .rotationEffect(.degrees(isAnimating ? 0 : -10))
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)

                // Side profile
                ZStack {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.cyan)
                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)
                        .rotation3DEffect(.degrees(50), axis: (x: 0, y: 1, z: 0))
                }
            }

            VStack(spacing: 6) {
                Text("Turn sideways to the camera")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                Text("Show your side profile for forward head check")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.6)))
        .padding(.horizontal, 20)
    }
}

// MARK: - Front Result View

struct FrontResultView: View {
    let score: FrontScore
    let onSideScan: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Front Posture")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                
                // Score circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 100)
                    Text("\(score.score)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Metrics
                HStack(spacing: 20) {
                    VStack {
                        Text("Shoulders")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.0f°", abs(score.shoulderTilt)))
                            .font(.title3.bold())
                            .foregroundColor(abs(score.shoulderTilt) < 5 ? .green : .orange)
                    }
                    VStack {
                        Text("Head Tilt")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.0f°", abs(score.headTilt)))
                            .font(.title3.bold())
                            .foregroundColor(abs(score.headTilt) < 3 ? .green : .orange)
                    }
                }
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            
            if score.needsSideScan {
                Button(action: onSideScan) {
                    HStack {
                        Image(systemName: "arrow.turn.up.right")
                        Text("Check Forward Head")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Button("Skip", action: onSkip)
                    .foregroundColor(.gray)
            } else {
                Button(action: onSkip) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
        }
        .padding(.bottom, 40)

    }
    
    private var scoreColor: Color {
        if score.score > 80 { return .green }
        if score.score > 60 { return .orange }
        return .red
    }
}

// MARK: - Final Result View

struct FinalResultView: View {
    let score: FinalScore
    let onRestart: () -> Void
    let onContinue: () -> Void
    let onSave: (Bool) -> Void
    
    @State private var hasSaved = false
    @State private var exercisesCompleted = false


    @AppStorage("hasCompletedFirstScan") private var hasCompletedFirstScan = false

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
                        .trim(from: 0, to: CGFloat(score.combinedScore) / 100)
                        .stroke(score.combinedScore > 80 ? Color.green : Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                    Text("\(score.combinedScore)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(score.combinedScore > 80 ? "Great Posture" : "Needs Improvement")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Breakdown
                VStack(spacing: 8) {
                    HStack {
                        Text("Shoulder Alignment")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(abs(score.frontScore.shoulderTilt) < 5 ? "✓ Good" : "⚠ Tilted")
                            .foregroundColor(abs(score.frontScore.shoulderTilt) < 5 ? .green : .orange)
                    }
                    HStack {
                        Text("Head Position")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(abs(score.frontScore.headTilt) < 3 ? "✓ Centered" : "⚠ Tilted")
                            .foregroundColor(abs(score.frontScore.headTilt) < 3 ? .green : .orange)
                    }
                    if let cva = score.cva {
                        HStack {
                            Text("Head Alignment")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(PostureConstants.cvaStatus(for: cva))
                                .foregroundColor(cva >= PostureConstants.cvaNormal ? .green : (cva >= PostureConstants.cvaMildFHP ? .cyan : .orange))
                        }
                    }
                }
                .font(.subheadline)
                .padding(.top, 10)
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)

            Button(action: onContinue) {
                Text("Get Posture Tips")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
            }
            
            if !hasSaved {
                Toggle("I completed the quick fix exercises", isOn: $exercisesCompleted)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
                    
                Button(action: {
                    onSave(exercisesCompleted)
                    hasSaved = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save to Journal")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Saved to Journal")
                }
                .font(.headline)
                .foregroundColor(.green)
                .padding()
            }
            
            // Disclaimer for EU/Medical Device Compliance
            Text("For wellness purposes only. Not a medical device.")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 10)
                .padding(.horizontal, 40)
                .padding(.bottom, 10)
            
            Button("Restart Scan") {
                onRestart()
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.bottom, 10)
        }
        .padding(.bottom, 40)
        .transition(.move(edge: .bottom))
        .onAppear {
            if !hasCompletedFirstScan {
                hasCompletedFirstScan = true
                // Request review after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                }
            }

    }
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
