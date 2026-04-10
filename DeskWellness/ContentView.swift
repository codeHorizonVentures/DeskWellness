//
//  ContentView.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 30.04.2025.
//

import SwiftUI
import AVFoundation
import AudioToolbox
import StoreKit
import SwiftData

// MARK: - App State Machine

enum CameraPermissionAlertMode {
    case denied
    case restricted

    var message: String {
        switch self {
        case .denied:
            return "Camera access is off for optional check-ins. You can keep using quick resets, or open Settings to turn check-ins back on."
        case .restricted:
            return "Optional check-ins need camera access. Quick resets still work without it."
        }
    }

    var showsSettingsShortcut: Bool {
        self == .denied
    }
}

enum AppState {
    case home
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
    @Query(sort: \DailyEntry.date, order: .reverse) private var entries: [DailyEntry]
    @StateObject private var engine = PostureEngine()
    @AppStorage("hasSeenResetMinuteOnboarding") private var hasSeenOnboarding = false
    @State private var appState: AppState = .home
    @State private var scanDuration: Double = 0.0
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()
    @State private var lastSpeechTime: Date = .distantPast
    @State private var showJournal = false
    @State private var showCameraPermissionAlert = false
    @State private var showJournalSaveErrorAlert = false
    @State private var cameraPermissionAlertMode: CameraPermissionAlertMode = .restricted
    @State private var journalSaveErrorMessage = ""
    @State private var frontScore: FrontScore? = nil
    @State private var showPostureTips = false
    @State private var frontSnapshot: UIImage?
    @State private var sideSnapshot: UIImage?
    @State private var showOnboarding = false
    @State private var decidedOnboardingForThisLaunch = false
    private let launchArguments = ProcessInfo.processInfo.arguments

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
            
            // LAYER 2.5: Pose Guidance Overlays (When NOT locked)
            if case .frontScanning = appState {
                PoseGuidanceOverlay(imageName: "front-pose")
                    .transition(.opacity)
            }
            
            if case .sideScanning = appState {
                PoseGuidanceOverlay(imageName: "side-pose")
                    .transition(.opacity)
            }

            // LAYER 3: The UI Overlay
            VStack {
                // Top Bar
                TopBarView(
                    appState: appState,
                    engine: engine,
                    shouldAutoOpenReminderSettings: launchArguments.contains("-ResetMinuteOpenReminderSettings")
                )

                Spacer()

                // Bottom Area Changes based on State
                switch appState {
                case .home:
                    HomeView(
                        consistencySummary: consistencySummary,
                        onStartQuickReset: { showPostureTips = true },
                        onStartCheckIn: { beginCheckInFlow() },
                        onOpenJournal: { showJournal = true }
                    )

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
                        resetToHome()
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
                            note: "Desk Check-In",
                            photoPath: sidePath,
                            frontPhotoPath: frontPath,
                            exercisesCompleted: didExercise,
                            cvaScore: score.cva,
                            frontPointsData: frontData,
                            sidePointsData: sideData
                        )
                        persist(entry)
                    }, onShowJournal: {
                        showJournal = true
                    })
                    .transition(.opacity)
                case .paywall:
                    PaywallView {
                        resetToHome()
                    }
                }
            }
        }
        .onReceive(scanTimer) { _ in
            handleScanTimer()
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            if cameraPermissionAlertMode.showsSettingsShortcut {
                Button("Not Now", role: .cancel) { }
                Button("Open Settings") {
                    openAppSettings()
                }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            Text(cameraPermissionAlertMode.message)
        }
        .alert("Couldn't Save Journal Entry", isPresented: $showJournalSaveErrorAlert) {
            Button("OK", role: .cancel) {
                journalSaveErrorMessage = ""
            }
        } message: {
            Text(journalSaveErrorMessage)
        }
        .sheet(isPresented: $showPostureTips) {
            PostureTipView()
        }
        .sheet(isPresented: $showJournal) {
            JournalView(showJournal: $showJournal, previewEntries: previewJournalEntries)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            ResetMinuteOnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
        .task {
            clearEntriesForUITestIfNeeded()
            _ = try? await ReminderScheduler.syncFromDefaults()
            decideOnboardingPresentationIfNeeded()
        }
    }

    private var consistencySummary: ResetConsistencySummary {
        if launchArguments.contains("-ResetMinuteDemoConsistency") {
            return .screenshotDemo
        }

        return ResetConsistencySummary.build(from: entries.map(\.resetConsistencyEntry))
    }

    private var previewJournalEntries: [DailyEntry]? {
        if launchArguments.contains("-ResetMinuteDemoJournalEntries") {
            return DailyEntry.screenshotDemoEntries
        }

        return nil
    }

    private func decideOnboardingPresentationIfNeeded() {
        guard !decidedOnboardingForThisLaunch else { return }
        decidedOnboardingForThisLaunch = true

        if launchArguments.contains("-ResetMinuteSkipOnboarding") {
            if launchArguments.contains("-ResetMinuteOpenJournal") {
                showJournal = true
            }
            return
        }

        let shouldShowOnboarding = launchArguments.contains("-ResetMinuteForceOnboarding") || !hasSeenOnboarding
        if shouldShowOnboarding {
            showOnboarding = true
            return
        }

        if launchArguments.contains("-ResetMinuteOpenJournal") {
            showJournal = true
        }
    }

    private func clearEntriesForUITestIfNeeded() {
        guard launchArguments.contains("-ResetMinuteDeleteAllEntries") else { return }

        let descriptor = FetchDescriptor<DailyEntry>()
        let persistedEntries = (try? modelContext.fetch(descriptor)) ?? []

        for entry in persistedEntries {
            modelContext.delete(entry)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to clear UI test entries: \(error.localizedDescription)")
        }
    }

    // MARK: - Camera Permission

    private func beginCheckInFlow() {
        if launchArguments.contains("-ResetMinuteSimulateCameraDenied") {
            presentCameraPermissionAlert(for: .denied)
            return
        }

        if launchArguments.contains("-ResetMinuteSimulateCameraRequestDenied") {
            handleCameraAccessRequestResult(granted: false)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCheckIn()
        case .notDetermined:
            requestCameraAccess()
        case .denied:
            presentCameraPermissionAlert(for: .denied)
        case .restricted:
            presentCameraPermissionAlert(for: .restricted)
        @unknown default:
            presentCameraPermissionAlert(for: .restricted)
        }
    }

    private func resetToHome() {
        engine.reset()
        scanDuration = 0
        frontScore = nil
        frontSnapshot = nil
        sideSnapshot = nil
        withAnimation {
            appState = .home
        }
    }

    private func startCheckIn() {
        scanDuration = 0
        frontScore = nil
        engine.start()
        withAnimation {
            appState = .frontScanning
        }
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            handleCameraAccessRequestResult(granted: granted)
        }
    }

    private func handleCameraAccessRequestResult(granted: Bool) {
        DispatchQueue.main.async {
            if granted {
                startCheckIn()
            } else {
                presentCameraPermissionAlert(for: .denied)
            }
        }
    }

    private func persist(_ entry: DailyEntry) {
        modelContext.insert(entry)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(entry)
            journalSaveErrorMessage = "This check-in couldn't be saved to your journal. Please try again."
            showJournalSaveErrorAlert = true
        }
    }

    private func presentCameraPermissionAlert(for mode: CameraPermissionAlertMode) {
        cameraPermissionAlertMode = mode
        showCameraPermissionAlert = true
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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

    private func playSuccessSound() {
        // Play system sound "Tink" (ID 1057) or similar
        // 1057 = Tink, 1001 = MailSent, 1103 = Tock
        AudioServicesPlaySystemSound(1057)
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
        playSuccessSound()
        engine.stop()
        
        withAnimation {
            appState = .frontResult(score)
        }
    }
    
    private func finishSideScan() {
        sideSnapshot = engine.captureSnapshot(for: .side)
        guard let front = frontScore else { return }
        
        // Combine the front check-in with the optional side-view estimate.
        let cvaScore = PostureConstants.cvaScore(for: engine.cva)
        let combinedScore = (front.score + cvaScore) / 2
        
        let final = FinalScore(
            frontScore: front,
            cva: engine.cva,
            forwardHeadAngle: engine.forwardHeadAngle,
            combinedScore: combinedScore
        )
        
        feedbackGenerator.notificationOccurred(.success)
        playSuccessSound()
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
    let shouldAutoOpenReminderSettings: Bool
    @AppStorage(ReminderScheduler.enabledKey) private var remindersEnabled = false
    @State private var showReminderSettings = false
    @State private var didAutoOpenReminderSettings = false
    
    var body: some View {
        HStack {
            Image(systemName: "figure.mind.and.body")
                .foregroundColor(.white)
            Text("ResetMinute")
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

            Button {
                showReminderSettings = true
            } label: {
                Image(systemName: remindersEnabled ? "bell.badge.fill" : "bell.fill")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .padding(.leading, 8)
        }
        .padding()
        .sheet(isPresented: $showReminderSettings) {
            ReminderSettingsView()
        }
        .task {
            guard shouldAutoOpenReminderSettings, !didAutoOpenReminderSettings else { return }
            didAutoOpenReminderSettings = true
            showReminderSettings = true
        }
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

struct HomeView: View {
    let consistencySummary: ResetConsistencySummary
    let onStartQuickReset: () -> Void
    let onStartCheckIn: () -> Void
    let onOpenJournal: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("ResetMinute")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Short desk resets for neck, shoulders, and back during long workdays.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.86))

                Text("Camera check-ins stay optional. The daily default is a fast reset.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 32)

            HomeWeeklyProgressCard(summary: consistencySummary)
                .padding(.horizontal, 28)

            VStack(spacing: 14) {
                Button(action: onStartQuickReset) {
                    Label("Start Quick Reset", systemImage: "figure.cooldown")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .cornerRadius(16)
                }
                .accessibilityIdentifier("home_start_quick_reset")

                Button(action: onStartCheckIn) {
                    Label("Optional Check-In", systemImage: "camera.viewfinder")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .cornerRadius(16)
                }
                .accessibilityIdentifier("home_optional_check_in")

                Button(action: onOpenJournal) {
                    Label("Open Reset Journal", systemImage: "book.closed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .accessibilityIdentifier("home_open_reset_journal")
                .padding(.top, 6)
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.bottom, 40)
    }
}

struct HomeWeeklyProgressCard: View {
    let summary: ResetConsistencySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.66))
                        .textCase(.uppercase)

                    Text(summary.headline)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                Text("\(summary.completedResets)/\(summary.weeklyGoal)")
                    .font(.title3.bold())
                    .foregroundColor(.cyan)
            }

            Text(summary.supportingText)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.72))

            ProgressView(value: summary.progressFraction)
                .tint(.cyan)

            HStack(spacing: 10) {
                HomeWeeklyMetric(label: "Active Days", value: "\(summary.activeDays)")
                HomeWeeklyMetric(label: "Check-Ins", value: "\(summary.checkIns)")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home_weekly_progress")
        .accessibilityLabel("This week progress. \(summary.headline). \(summary.supportingText)")
    }
}

private struct HomeWeeklyMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            // Visuals moved to PoseGuidanceOverlay
            
            VStack(spacing: 8) {
                Text("Face the camera")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("Stand naturally and look straight ahead")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 40)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        // Ensure it sits at the bottom nicely
        .frame(maxWidth: .infinity)
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
                Text("Side Check")
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
            // Visuals moved to PoseGuidanceOverlay

            VStack(spacing: 8) {
                Text("Turn sideways")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("Show your side profile for an optional side-view check")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 40)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(maxWidth: .infinity)
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
                Text("Front Check-In")
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
                        Text("Head Position")
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
                        Text("Check Side View")
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
    let onShowJournal: () -> Void
    
    @State private var hasSaved = false
    @State private var exercisesCompleted = false
    @State private var showContent = false
    
    @AppStorage("hasCompletedFirstScan") private var hasCompletedFirstScan = false
    
    var body: some View {
        ZStack {
            // Glass background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    
                    // Header Area
                    HStack {
                        Button(action: onRestart) {
                           HStack(spacing: 6) {
                               Image(systemName: "arrow.counterclockwise")
                               Text("Restart")
                           }
                           .font(.subheadline.weight(.medium))
                           .foregroundColor(.secondary)
                           .padding(.horizontal, 12)
                           .padding(.vertical, 8)
                           .background(Color.secondary.opacity(0.1))
                           .clipShape(Capsule())
                       }

                        Spacer()
                        
                        Text("Desk Check-In")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: onShowJournal) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .padding(10)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Main Score Card
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.1), lineWidth: 15)
                                .frame(width: 180, height: 180)
                            
                            Circle()
                                .trim(from: 0, to: showContent ? CGFloat(score.combinedScore) / 100 : 0)
                                .stroke(
                                    scoreColor,
                                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 180, height: 180)
                                .animation(.easeOut(duration: 1.5).delay(0.2), value: showContent)
                            
                            VStack(spacing: 4) {
                                Text("\(Int(score.combinedScore))")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(scoreStatus)
                                    .font(.headline)
                                    .foregroundColor(scoreColor)
                            }
                        }
                        .padding(.vertical, 10)
                        
                        Divider()
                        
                        // Breakdown
                        VStack(spacing: 16) {
                            ScoreRow(label: "Shoulder Balance", isGood: abs(score.frontScore.shoulderTilt) < 5, value: abs(score.frontScore.shoulderTilt) < 5 ? "Steady" : "Uneven")
                            ScoreRow(label: "Head Position", isGood: abs(score.frontScore.headTilt) < 3, value: abs(score.frontScore.headTilt) < 3 ? "Centered" : "Leaning")

                            if let cva = score.cva {
                                ScoreRow(label: "Side Check", isGood: cva >= PostureConstants.cvaNormal, value: PostureConstants.cvaStatus(for: cva))
                            }
                        }
                        .padding(.bottom, 10)
                    }
                    .padding(24)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.6), value: showContent)
                    
                    // Actions
                    VStack(spacing: 16) {
                        Button(action: onContinue) {
                            HStack {
                                Image(systemName: "figure.mind.and.body")
                                Text("Start Quick Reset")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        
                        if !hasSaved {
                            VStack(spacing: 12) {
                                Toggle("I completed the quick reset", isOn: $exercisesCompleted)
                                    .font(.subheadline)
                                    .padding(.horizontal, 4)
                                
                                Button(action: {
                                    onSave(exercisesCompleted)
                                    withAnimation { hasSaved = true }
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Save to Journal")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(16)
                                }
                            }
                            .padding(20)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Saved to Journal")
                            }
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
                    
                    // Footer
                    Text("For wellness use only. Not medical advice.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 40)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
                }
            }
        }
        .onAppear {
            showContent = true
            if !hasCompletedFirstScan {
                hasCompletedFirstScan = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                }
            }
        }
    }
    
    private var scoreColor: Color {
        if score.combinedScore > 80 { return .green }
        if score.combinedScore > 60 { return .orange }
        return .red
    }
    
    private var scoreStatus: String {
        if score.combinedScore > 80 { return "Feeling Good" }
        if score.combinedScore > 60 { return "Solid Start" }
        return "Reset Suggested"
    }
}

struct ScoreRow: View {
    let label: String
    let isGood: Bool
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isGood ? .green : .orange)
                 Text(value)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
            }
        }
    }
}


// MARK: - Paywall View

struct PaywallView: View {
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Unlock Premium Reset Packs")
                .font(.title)
                .bold()
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "checkmark.circle.fill", text: "More guided desk reset routines")
                FeatureRow(icon: "checkmark.circle.fill", text: "Flexible reminder schedules")
                FeatureRow(icon: "checkmark.circle.fill", text: "Deeper progress history")
            }
            .padding()

            Button(action: {
                // TODO: Integrate RevenueCat Here
            }) {
                Text("See Premium Options")
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
