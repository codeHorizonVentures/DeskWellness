//
//  PostureConstants.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 7/02/26.
//

import SwiftUI

/// Shared constants for the app's optional posture-awareness check-in.
enum PostureConstants {
    
    // MARK: - CVA Thresholds
    // Tuned for wellness-oriented feedback instead of medical assessment.
    
    /// CVA above which the side view looks more upright.
    static let cvaNormal: Double = 53.0
    
    /// CVA indicating a slight forward lean.
    static let cvaMildFHP: Double = 48.0
    
    /// CVA indicating a more noticeable forward lean.
    static let cvaModerateFHP: Double = 45.0
    
    /// CVA below 45° suggests a stronger forward lean.
    
    // MARK: - Legacy Thresholds (for backward compatibility)
    
    static let badAngleThreshold: Double = 25.0
    static let perfectAngleThreshold: Double = 10.0
    
    // MARK: - Front View Thresholds
    
    /// Maximum acceptable shoulder tilt (degrees)
    static let maxShoulderTilt: Double = 5.0
    
    /// Maximum acceptable head lateral tilt (degrees)
    static let maxHeadTilt: Double = 3.0
    
    // MARK: - Stability
    
    /// Number of consecutive missed frames to tolerate before unlocking (approx. 0.5s at 30fps)
    static let missedFrameTolerance: Int = 15
    
    // MARK: - Timing
    
    /// Duration (seconds) of stable tracking before auto-finishing scan
    static let scanLockDuration: Double = 3.0

    /// Maximum time (seconds) to wait before offering retry instead of endless scanning.
    static let frontScanTimeoutDuration: Double = 12.0
    
    /// Minimum interval (seconds) between speech prompts
    static let speechDebounceInterval: TimeInterval = 5.0
    
    // MARK: - Debug
    
    /// Toggle to show debug overlay (joint dots and connecting lines)
    static let showDebugOverlay: Bool = false
    
    // MARK: - Colors
    
    static let severeColors: [Color] = [.red, .orange]
    static let moderateColors: [Color] = [.orange, .yellow]
    static let mildColors: [Color] = [.yellow, .cyan]
    static let normalColors: [Color] = [.green, .cyan]
    
    /// Returns gradient colors based on CVA
    static func colorsForCVA(_ cva: Double) -> [Color] {
        if cva >= cvaNormal { return normalColors }
        if cva >= cvaMildFHP { return mildColors }
        if cva >= cvaModerateFHP { return moderateColors }
        return severeColors
    }
    
    /// Legacy: Returns gradient colors based on forward angle (old method)
    static func colors(for angle: Double) -> [Color] {
        if angle > badAngleThreshold { return severeColors }
        if angle > perfectAngleThreshold { return moderateColors }
        return normalColors
    }
    
    // MARK: - Posture Feedback (Wellness Language)
    
    /// Returns wellness-friendly feedback based on the optional side-view check.
    static func cvaClassification(for cva: Double) -> String {
        if cva >= cvaNormal { return "Upright" }
        if cva >= cvaMildFHP { return "Slight Forward Lean" }
        if cva >= cvaModerateFHP { return "Noticeable Forward Lean" }
        return "Reset Suggested"
    }
    
    /// Returns short wellness status
    static func cvaStatus(for cva: Double) -> String {
        if cva >= cvaNormal { return "UPRIGHT" }
        if cva >= cvaMildFHP { return "GOOD" }
        if cva >= cvaModerateFHP { return "RESET" }
        return "MOVE"
    }
    
    // MARK: - CVA Scoring
    
    /// Calculates a simple check-in score (0-100) based on the side-view estimate.
    static func cvaScore(for cva: Double) -> Int {
        if cva >= cvaNormal { return 100 }
        if cva >= cvaMildFHP { return 85 }
        if cva >= cvaModerateFHP { return 70 }
        if cva >= 40 { return 55 }
        if cva >= 35 { return 40 }
        return max(0, Int(cva))
    }
    
    // MARK: - Legacy Functions (backward compatibility)
    
    static func feedbackText(for angle: Double) -> String {
        if angle > badAngleThreshold { return "LEANING FORWARD" }
        if angle > perfectAngleThreshold { return "EASING IN" }
        return "UPRIGHT"
    }
    
    static func statusText(for angle: Double) -> String {
        angle > badAngleThreshold ? "LEANING FORWARD" : "UPRIGHT"
    }
    
    static func score(for angle: Double) -> Int {
        Int(max(0, min(100, 100 - (angle * 2.0))))
    }
}
