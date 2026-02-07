//
//  PostureConstants.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 7/02/26.
//

import SwiftUI

/// Shared constants for posture analysis using CVA (Craniovertebral Angle) methodology
/// Based on 2024-2025 peer-reviewed research with 97%+ reliability
enum PostureConstants {
    
    // MARK: - CVA Thresholds (Clinically Validated)
    // Reference: Meta-analysis 2024, ICC = 0.904
    
    /// CVA above which posture is normal (good head position)
    static let cvaNormal: Double = 53.0
    
    /// CVA indicating mild forward head posture
    static let cvaMildFHP: Double = 48.0
    
    /// CVA indicating moderate forward head posture
    static let cvaModerateFHP: Double = 45.0
    
    /// CVA below 45° indicates severe forward head posture
    
    // MARK: - Legacy Thresholds (for backward compatibility)
    
    static let badAngleThreshold: Double = 25.0
    static let perfectAngleThreshold: Double = 10.0
    
    // MARK: - Front View Thresholds
    
    /// Maximum acceptable shoulder tilt (degrees)
    static let maxShoulderTilt: Double = 5.0
    
    /// Maximum acceptable head lateral tilt (degrees)
    static let maxHeadTilt: Double = 3.0
    
    // MARK: - Timing
    
    /// Duration (seconds) of stable tracking before auto-finishing scan
    static let scanLockDuration: Double = 5.0
    
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
    
    /// Returns wellness-friendly feedback based on posture angle
    static func cvaClassification(for cva: Double) -> String {
        if cva >= cvaNormal { return "Great Alignment" }
        if cva >= cvaMildFHP { return "Slight Forward Lean" }
        if cva >= cvaModerateFHP { return "Noticeable Forward Lean" }
        return "Significant Forward Lean"
    }
    
    /// Returns short wellness status
    static func cvaStatus(for cva: Double) -> String {
        if cva >= cvaNormal { return "GREAT" }
        if cva >= cvaMildFHP { return "GOOD" }
        if cva >= cvaModerateFHP { return "FAIR" }
        return "NEEDS WORK"
    }
    
    // MARK: - CVA Scoring
    
    /// Calculates posture score (0-100) based on CVA
    /// Higher CVA = better posture = higher score
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
        if angle > badAngleThreshold { return "HEAD FORWARD" }
        if angle > perfectAngleThreshold { return "ALMOST THERE" }
        return "PERFECT ALIGNMENT"
    }
    
    static func statusText(for angle: Double) -> String {
        angle > badAngleThreshold ? "HEAD FORWARD" : "GOOD ALIGNMENT"
    }
    
    static func score(for angle: Double) -> Int {
        Int(max(0, min(100, 100 - (angle * 2.0))))
    }
}
