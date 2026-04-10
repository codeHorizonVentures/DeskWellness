//
//  PostureTipView.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 07.02.2026.
//

import SwiftUI

import AVKit
import SwiftData

// MARK: - Models

struct PostureTip: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let videoName: String? // Added video support
    let duration: TimeInterval
    let benefit: String
    let color: Color
}

// MARK: - Data

struct PostureTipsData {
    static let deskReset = [
        PostureTip(
            title: "Neck Reset",
            description: "Sit or stand tall. Gently glide your chin straight back like you're making a double chin. Pause for 2 seconds, then release and repeat.",
            iconName: "figure.mind.and.body",
            videoName: "chin-tucks-exercise-animation",
            duration: 60,
            benefit: "Helps ease neck stiffness after long screen focus.",
            color: .blue
        ),
        PostureTip(
            title: "Shoulder Opener",
            description: "Stand with your back against a wall. Start with your arms in a W shape, then slide toward a Y while keeping contact where comfortable.",
            iconName: "figure.arms.open",
            videoName: "wall-angels-animation",
            duration: 60,
            benefit: "Helps unload tight shoulders and upper back after sitting.",
            color: .orange
        ),
        PostureTip(
            title: "Chest + Back Release",
            description: "Place your forearms on a door frame at 90 degrees. Step through gently until you feel a stretch across the front of your chest and upper back line.",
            iconName: "figure.walk",
            videoName: "doorway-streach-animation",
            duration: 45,
            benefit: "Helps ease desk hunch tension through the chest and back.",
            color: .green
        )
    ]
}

// MARK: - Views

struct PostureTipView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode
    @State private var currentIndex = 0
    @State private var timeRemaining: TimeInterval = 60
    @State private var timerActive = false
    @State private var showCompletion = false
    @State private var hasLoggedCompletion = false
    @State private var showCompletionSaveErrorAlert = false
    
    let tips = PostureTipsData.deskReset
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("3-Minute Desk Reset")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .accessibilityIdentifier("desk_reset_screen")
                        Text("Neck, shoulders, and back")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                if showCompletion {
                    CompletionView(onDismiss: dismissCompletion)
                } else {
                    // Progress Bar
                    ProgressBar(current: currentIndex + 1, total: tips.count)
                        .padding(.horizontal)
                    
                    // Exercise Card
                    ExerciseCard(
                        tip: tips[currentIndex],
                        timeRemaining: timeRemaining,
                        totalTime: tips[currentIndex].duration,
                        onSkip: nextExercise,
                        toggleTimer: { timerActive.toggle() }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    .id(currentIndex) // Force transition
                }
                
                Spacer()
            }
        }
        .onAppear {
            timeRemaining = tips[currentIndex].duration
            timerActive = true
        }
        .onReceive(timer) { _ in
            guard timerActive && !showCompletion else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                nextExercise()
            }
        }
        .alert("Couldn't Save Reset", isPresented: $showCompletionSaveErrorAlert) {
            Button("Try Again") {
                finishReset()
            }
            Button("Close", role: .cancel) {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your reset finished, but it could not be added to the journal. Please try again.")
        }
    }
    
    private func nextExercise() {
        if currentIndex < tips.count - 1 {
            withAnimation {
                currentIndex += 1
                timeRemaining = tips[currentIndex].duration
                timerActive = true
            }
        } else {
            finishReset()
        }
    }

    private func finishReset() {
        timerActive = false

        do {
            try logCompletedResetIfNeeded()
            withAnimation {
                showCompletion = true
            }
        } catch {
            showCompletionSaveErrorAlert = true
        }
    }

    private func logCompletedResetIfNeeded() throws {
        guard !hasLoggedCompletion else { return }

        let entry = DailyEntry.completedQuickResetEntry()
        modelContext.insert(entry)

        do {
            try modelContext.save()
            hasLoggedCompletion = true
        } catch {
            modelContext.delete(entry)
            throw error
        }
    }

    private func dismissCompletion() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct ExerciseCard: View {
    let tip: PostureTip
    let timeRemaining: TimeInterval
    let totalTime: TimeInterval
    let onSkip: () -> Void
    let toggleTimer: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Media (Video or Icon)
            if let videoName = tip.videoName {
                LoopingVideoPlayer(videoName: videoName)
                    .frame(height: 220)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else {
                ZStack {
                    Circle()
                        .fill(tip.color.opacity(0.2))
                        .frame(width: 100, height: 100)
                    Image(systemName: tip.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(tip.color)
                }
                .padding(.top, 20)
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Text
                    VStack(spacing: 8) {
                        Text(tip.title)
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        Text(tip.benefit)
                            .font(.subheadline)
                            .foregroundColor(tip.color)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Instructions
                    Text(tip.description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                }
            }
            
            Spacer()
            
            // Timer
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining / totalTime))
                    .stroke(tip.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                    .animation(.linear(duration: 1), value: timeRemaining)
                
                Text("\(Int(timeRemaining))")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            .onTapGesture(perform: toggleTimer)
            
            Button(action: onSkip) {
                Text(timeRemaining == 0 ? "Next Exercise" : "Skip")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 40)
                    .background(Capsule().fill(Color.gray.opacity(0.3)))
            }
            .accessibilityIdentifier("desk_reset_skip_button")
            .padding(.bottom, 20)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(UIColor.secondarySystemBackground).opacity(0.1)))
        .padding(.horizontal)
    }
}

struct ProgressBar: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.cyan : Color.gray.opacity(0.3))
                    .frame(height: 6)
                    .animation(.default, value: current)
            }
        }
    }
}

struct CompletionView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding()
                .background(Circle().fill(Color.green.opacity(0.2)).frame(width: 150, height: 150))
            
            VStack(spacing: 12) {
                Text("Great Job!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                
                Text("You've finished a quick desk reset for this work block.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("This reset was added to your journal.")
                    .font(.subheadline)
                    .foregroundColor(.green.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .accessibilityIdentifier("desk_reset_completion_done_button")
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}
