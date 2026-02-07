//
//  PostureTipView.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 07.02.2026.
//

import SwiftUI

// MARK: - Models

struct PostureTip: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let duration: TimeInterval
    let benefit: String
    let color: Color
}

// MARK: - Data

struct PostureTipsData {
    static let dailyFix = [
        PostureTip(
            title: "Chin Tucks",
            description: "Gently tuck your chin straight back like you're making a double chin. Feel the stretch at the base of your skull. Hold for 2 seconds, release.",
            iconName: "figure.mind.and.body",
            duration: 60,
            benefit: "Strengthens deep neck flexors to fix Forward Head Posture.",
            color: .blue
        ),
        PostureTip(
            title: "Wall Angels",
            description: "Stand with back against a wall. Arms in 'W' shape. Slide arms up to 'Y' while keeping elbows and wrists touching the wall.",
            iconName: "figure.arms.open",
            duration: 60,
            benefit: "Corrects rounded shoulders and opens the chest.",
            color: .orange
        ),
        PostureTip(
            title: "Doorway Stretch",
            description: "Place forearms on a door frame at 90 degrees. Step through gently until you feel a stretch in your chest. Hold.",
            iconName: "figure.walk",
            duration: 45,
            benefit: "Loosens tight pectoral muscles that pull shoulders forward.",
            color: .green
        )
    ]
}

// MARK: - Views

struct PostureTipView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentIndex = 0
    @State private var timeRemaining: TimeInterval = 60
    @State private var timerActive = false
    @State private var showCompletion = false
    
    let tips = PostureTipsData.dailyFix
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("The 3-Minute Fix")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                if showCompletion {
                    CompletionView { presentationMode.wrappedValue.dismiss() }
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
    }
    
    private func nextExercise() {
        if currentIndex < tips.count - 1 {
            withAnimation {
                currentIndex += 1
                timeRemaining = tips[currentIndex].duration
                timerActive = true
            }
        } else {
            withAnimation {
                showCompletion = true
                timerActive = false
            }
        }
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
            // Icon
            ZStack {
                Circle()
                    .fill(tip.color.opacity(0.2))
                    .frame(width: 100, height: 100)
                Image(systemName: tip.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(tip.color)
            }
            .padding(.top, 20)
            
            // Text
            VStack(spacing: 8) {
                Text(tip.title)
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                Text(tip.benefit)
                    .font(.subheadline)
                    .foregroundColor(tip.color)
                    .fontWeight(.medium)
            }
            
            // Instructions
            Text(tip.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
            
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
                
                Text("You've taken a big step towards better posture today.")
                    .font(.body)
                    .foregroundColor(.gray)
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
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}
