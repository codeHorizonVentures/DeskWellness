//
//  ScanningEffects.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 07.02.2026.
//

import SwiftUI

// MARK: - Apple ARKit-Style Scan Colors
// Warm yellow/orange palette inspired by Apple's object scanning UI
private let scanAccent = Color(red: 1.0, green: 0.8, blue: 0.0)      // Warm yellow
private let scanGlow = Color(red: 1.0, green: 0.6, blue: 0.0)        // Orange glow
private let scanHighlight = Color(red: 1.0, green: 0.9, blue: 0.4)   // Light yellow

// MARK: - Front Scanning Effects (Phase 1)

struct FrontScanningEffectsView: View {
    let points: FrontPosePoints
    let isLocked: Bool
    let showDebug: Bool
    
    @State private var scanLineOffset: CGFloat = 0
    @State private var showLockConfirmation = false
    
    var body: some View {
        GeometryReader { geo in
            let leftShoulder = CGPoint(x: points.leftShoulder.x * geo.size.width, y: points.leftShoulder.y * geo.size.height)
            let rightShoulder = CGPoint(x: points.rightShoulder.x * geo.size.width, y: points.rightShoulder.y * geo.size.height)
            let nose = CGPoint(x: points.nose.x * geo.size.width, y: points.nose.y * geo.size.height)
            
            let fullScreenRect = CGRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height)
            
            ZStack {
                // Full-body scan effect
                FullBodyScanEffect(screenRect: fullScreenRect, scanOffset: scanLineOffset)
                
                // Particles
                FullScreenParticleEffect(screenRect: fullScreenRect)
                
                // Viewfinder
                FullBodyViewfinder(screenRect: fullScreenRect)
                
                // Shoulder line visualization (when locked)
                if isLocked {
                    FrontPoseVisualization(
                        leftShoulder: leftShoulder,
                        rightShoulder: rightShoulder,
                        nose: nose,
                        showDebug: showDebug
                    )
                }
                
                // Lock confirmation
                if showLockConfirmation {
                    LockConfirmationEffect(center: nose)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    scanLineOffset = 1.0
                }
            }
            .onChange(of: isLocked) { oldValue, newValue in
                if newValue && !oldValue {
                    showLockConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showLockConfirmation = false
                    }
                }
            }
        }
    }
}

// MARK: - Front Pose Visualization

struct FrontPoseVisualization: View {
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    let nose: CGPoint
    let showDebug: Bool
    
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Shoulder line glow
            Path { path in
                path.move(to: leftShoulder)
                path.addLine(to: rightShoulder)
            }
            .stroke(scanAccent, lineWidth: 4)
            .blur(radius: 6)
            .opacity(glowIntensity)
            
            // Debug: show points and labels
            if showDebug {
                // Shoulder line
                Path { path in
                    path.move(to: leftShoulder)
                    path.addLine(to: rightShoulder)
                }
                .stroke(scanAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                // Vertical from nose to shoulder center
                let shoulderCenter = CGPoint(
                    x: (leftShoulder.x + rightShoulder.x) / 2,
                    y: (leftShoulder.y + rightShoulder.y) / 2
                )
                Path { path in
                    path.move(to: nose)
                    path.addLine(to: shoulderCenter)
                }
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                
                // Points
                Circle().fill(Color.green).frame(width: 10, height: 10).position(leftShoulder)
                Circle().fill(Color.green).frame(width: 10, height: 10).position(rightShoulder)
                Circle().fill(Color.red).frame(width: 10, height: 10).position(nose)
                
                // Labels
                Text("L").font(.caption2).foregroundColor(.green).position(x: leftShoulder.x, y: leftShoulder.y - 15)
                Text("R").font(.caption2).foregroundColor(.green).position(x: rightShoulder.x, y: rightShoulder.y - 15)
                Text("NOSE").font(.caption2).foregroundColor(.red).position(x: nose.x + 25, y: nose.y)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowIntensity = 0.6
            }
        }
    }
}

// MARK: - Side Scanning Effects Container

struct ScanningEffectsView: View {
    let points: SidePosePoints
    let isLocked: Bool
    let showDebug: Bool
    
    @State private var scanLineOffset: CGFloat = 0
    @State private var showLockConfirmation = false
    
    var body: some View {
        GeometryReader { geo in
            let ear = CGPoint(x: points.ear.x * geo.size.width, y: points.ear.y * geo.size.height)
            let neck = CGPoint(x: points.neck.x * geo.size.width, y: points.neck.y * geo.size.height)
            
            // Full screen bounding for body scan effect
            let fullScreenRect = CGRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height)
            
            // Measurement zone around ear/neck (C7)
            let measurementRect = calculateBoundingRect(ear: ear, neck: neck, padding: 50)
            
            ZStack {
                // Layer 1: Full-body scanning effects (covers whole screen)
                FullBodyScanEffect(screenRect: fullScreenRect, scanOffset: scanLineOffset)
                
                // Layer 2: Full-screen particle field
                FullScreenParticleEffect(screenRect: fullScreenRect)
                
                // Layer 3: Full-body viewfinder corners (screen edges)
                FullBodyViewfinder(screenRect: fullScreenRect)
                
                // Layer 4: Measurement zone highlight (when locked)
                if isLocked {
                    MeasurementZoneHighlight(rect: measurementRect, ear: ear, neck: neck, showDebug: showDebug)
                }
                
                // Layer 5: Lock confirmation pulse
                if showLockConfirmation {
                    LockConfirmationEffect(center: ear)
                }
                
                // Layer 6: Debug overlay (optional)
                if showDebug {
                    DebugOverlay(ear: ear, neck: neck)
                }
            }
            .onAppear {
                startScanAnimation()
            }
            .onChange(of: isLocked) { oldValue, newValue in
                if newValue && !oldValue {
                    triggerLockConfirmation()
                }
            }
        }
    }
    
    private func calculateBoundingRect(ear: CGPoint, neck: CGPoint, padding: CGFloat) -> CGRect {
        let minX = min(ear.x, neck.x) - padding
        let maxX = max(ear.x, neck.x) + padding
        let minY = min(ear.y, neck.y) - padding
        let maxY = max(ear.y, neck.y) + padding
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func startScanAnimation() {
        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
            scanLineOffset = 1.0
        }
    }
    
    private func triggerLockConfirmation() {
        showLockConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showLockConfirmation = false
        }
    }
}

// MARK: - Full Body Scan Effect

struct FullBodyScanEffect: View {
    let screenRect: CGRect
    let scanOffset: CGFloat
    
    var body: some View {
        ZStack {
            // Primary scan line (full width)
            let yPosition = screenRect.height * scanOffset
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, scanAccent.opacity(0.6), scanAccent, scanAccent.opacity(0.6), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: screenRect.width, height: 3)
                .blur(radius: 1)
                .shadow(color: scanAccent, radius: 12)
                .position(x: screenRect.width / 2, y: yPosition)
            
            // Secondary trailing glow
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, scanAccent.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: screenRect.width, height: 80)
                .position(x: screenRect.width / 2, y: yPosition - 40)
            
            // Grid overlay effect
            GridOverlay(screenRect: screenRect, scanOffset: scanOffset)
        }
    }
}

// MARK: - Grid Overlay (Scanning grid lines)

struct GridOverlay: View {
    let screenRect: CGRect
    let scanOffset: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let gridSpacing: CGFloat = 40
            let scanY = size.height * scanOffset
            
            // Horizontal grid lines
            for y in stride(from: 0, to: size.height, by: gridSpacing) {
                let distanceFromScan = abs(y - scanY)
                let opacity = max(0, 0.15 - (distanceFromScan / 300))
                
                if opacity > 0 {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(scanAccent.opacity(opacity)), lineWidth: 0.5)
                }
            }
            
            // Vertical grid lines
            for x in stride(from: 0, to: size.width, by: gridSpacing) {
                let centerX = size.width / 2
                let distanceFromCenter = abs(x - centerX)
                let opacity = max(0, 0.1 - (distanceFromCenter / size.width) * 0.15)
                
                if opacity > 0 {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: max(0, scanY - 150)))
                    path.addLine(to: CGPoint(x: x, y: scanY))
                    context.stroke(path, with: .color(scanAccent.opacity(opacity)), lineWidth: 0.5)
                }
            }
        }
    }
}

// MARK: - Full Body Viewfinder

struct FullBodyViewfinder: View {
    let screenRect: CGRect
    
    @State private var cornerOpacity: Double = 0.5
    
    private let cornerLength: CGFloat = 40
    private let padding: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Four corner brackets at screen edges
            CornerBracket(corner: .topLeft)
                .position(x: padding + cornerLength/2, y: padding + cornerLength/2)
            
            CornerBracket(corner: .topRight)
                .position(x: screenRect.width - padding - cornerLength/2, y: padding + cornerLength/2)
            
            CornerBracket(corner: .bottomLeft)
                .position(x: padding + cornerLength/2, y: screenRect.height - padding - cornerLength/2)
            
            CornerBracket(corner: .bottomRight)
                .position(x: screenRect.width - padding - cornerLength/2, y: screenRect.height - padding - cornerLength/2)
        }
        .opacity(cornerOpacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                cornerOpacity = 0.8
            }
        }
    }
}

// MARK: - Measurement Zone Highlight

struct MeasurementZoneHighlight: View {
    let rect: CGRect
    let ear: CGPoint
    let neck: CGPoint       // C7 approximation
    let showDebug: Bool
    
    @State private var glowIntensity: Double = 0.3
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            // Subtle glow around measurement zone (no corners - only full-body viewfinder)
            RoundedRectangle(cornerRadius: 16)
                .stroke(scanAccent, lineWidth: 2)
                .blur(radius: 6)
                .opacity(glowIntensity)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            
            // Connecting line and points - only in debug mode
            if showDebug {
                Path { path in
                    path.move(to: neck)
                    path.addLine(to: ear)
                }
                .stroke(
                    LinearGradient(
                        colors: [scanAccent.opacity(0.6), scanGlow.opacity(0.6)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .shadow(color: scanAccent, radius: 4)
                .opacity(appeared ? 1 : 0)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: scanAccent, radius: 6)
                    .position(ear)
                    .opacity(appeared ? 1 : 0)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: scanAccent, radius: 6)
                    .position(neck)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowIntensity = 0.6
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - Measurement Corners

struct MeasurementCorners: View {
    let rect: CGRect
    private let length: CGFloat = 20
    
    var body: some View {
        ZStack {
            SmallCorner(corner: .topLeft)
                .position(x: rect.minX + length/2, y: rect.minY + length/2)
            SmallCorner(corner: .topRight)
                .position(x: rect.maxX - length/2, y: rect.minY + length/2)
            SmallCorner(corner: .bottomLeft)
                .position(x: rect.minX + length/2, y: rect.maxY - length/2)
            SmallCorner(corner: .bottomRight)
                .position(x: rect.maxX - length/2, y: rect.maxY - length/2)
        }
    }
}

struct SmallCorner: View {
    let corner: Corner
    private let length: CGFloat = 20
    
    var body: some View {
        Path { path in
            switch corner {
            case .topLeft:
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
            case .topRight:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
                path.addLine(to: CGPoint(x: length, y: length))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: length, y: length))
            case .bottomRight:
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: length, y: length))
                path.addLine(to: CGPoint(x: length, y: 0))
            }
        }
        .stroke(scanAccent.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: length, height: length)
    }
}

// MARK: - Full Screen Particle Effect

struct FullScreenParticleEffect: View {
    let screenRect: CGRect
    
    @State private var particles: [Particle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.position.x - particle.size/2,
                        y: particle.position.y - particle.size/2,
                        width: particle.size,
                        height: particle.size
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(scanAccent.opacity(particle.opacity))
                    )
                }
            }
        }
        .onAppear {
            generateParticles()
            startParticleAnimation()
        }
    }
    
    private func generateParticles() {
        particles = (0..<35).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenRect.width),
                    y: CGFloat.random(in: 0...screenRect.height)
                ),
                size: CGFloat.random(in: 1.5...4),
                opacity: Double.random(in: 0.2...0.5),
                velocity: CGPoint(
                    x: CGFloat.random(in: -0.3...0.3),
                    y: CGFloat.random(in: -0.2...0.2)
                )
            )
        }
    }
    
    private func startParticleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
            for i in particles.indices {
                particles[i].position.x += particles[i].velocity.x
                particles[i].position.y += particles[i].velocity.y
                
                // Twinkle effect
                particles[i].opacity += Double.random(in: -0.03...0.03)
                particles[i].opacity = max(0.1, min(0.5, particles[i].opacity))
                
                // Wrap around screen
                if particles[i].position.x < 0 { particles[i].position.x = screenRect.width }
                if particles[i].position.x > screenRect.width { particles[i].position.x = 0 }
                if particles[i].position.y < 0 { particles[i].position.y = screenRect.height }
                if particles[i].position.y > screenRect.height { particles[i].position.y = 0 }
            }
        }
    }
}

// MARK: - Corner Bracket

enum Corner {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct CornerBracket: View {
    let corner: Corner
    private let length: CGFloat = 40
    private let strokeWidth: CGFloat = 3
    
    var body: some View {
        Path { path in
            switch corner {
            case .topLeft:
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
            case .topRight:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
                path.addLine(to: CGPoint(x: length, y: length))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: length, y: length))
            case .bottomRight:
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: length, y: length))
                path.addLine(to: CGPoint(x: length, y: 0))
            }
        }
        .stroke(
            LinearGradient(
                colors: [scanAccent, scanGlow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
        )
        .frame(width: length, height: length)
    }
}

// MARK: - Lock Confirmation Effect

struct LockConfirmationEffect: View {
    let center: CGPoint
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            // Outer ripple
            Circle()
                .stroke(scanAccent, lineWidth: 3)
                .frame(width: 100, height: 100)
                .scaleEffect(scale * 1.5)
                .opacity(opacity * 0.5)
            
            // Inner ripple
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
                .opacity(opacity)
            
            // Center flash
            Circle()
                .fill(scanAccent)
                .frame(width: 20, height: 20)
                .opacity(opacity)
        }
        .position(center)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 2.0
                opacity = 0
            }
        }
    }
}

// MARK: - Particle Model

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var velocity: CGPoint
}

// MARK: - Debug Overlay (Hidden by default)

struct DebugOverlay: View {
    let ear: CGPoint
    let neck: CGPoint       // C7 approximation
    
    var body: some View {
        ZStack {
            // Connection line (Tragus to C7)
            Path { path in
                path.move(to: neck)
                path.addLine(to: ear)
            }
            .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            
            // Ear point (Tragus)
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .position(ear)
            
            Text("TRAGUS")
                .font(.caption2)
                .foregroundColor(.red)
                .position(x: ear.x + 25, y: ear.y)
            
            // Neck point (C7)
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
                .position(neck)
            
            Text("C7")
                .font(.caption2)
                .foregroundColor(.green)
                .position(x: neck.x + 20, y: neck.y)
        }
    }
}
