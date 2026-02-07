//
//  PostureConstants.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 7/02/26.
//

import SwiftUI

/// Shared constants for posture analysis thresholds and styling
enum PostureConstants {
    // MARK: - Angle Thresholds (in degrees)
    
    /// Angle above which posture is considered "bad" (head forward)
    static let badAngleThreshold: Double = 25.0
    
    /// Angle below which posture is considered "perfect"
    static let perfectAngleThreshold: Double = 10.0
    
    // MARK: - Scoring
    
    /// Multiplier for converting angle to score deduction
    static let scoreMultiplier: Double = 2.0
    
    // MARK: - Timing
    
    /// Duration (seconds) of stable tracking before auto-finishing scan
    static let scanLockDuration: Double = 5.0
    
    /// Minimum interval (seconds) between speech prompts
    static let speechDebounceInterval: TimeInterval = 5.0
    
    // MARK: - Colors
    
    /// Gradient colors for bad posture
    static let badPostureColors: [Color] = [.red, .orange]
    
    /// Gradient colors for okay posture
    static let okayPostureColors: [Color] = [.yellow, .orange]
    
    /// Gradient colors for perfect posture
    static let perfectPostureColors: [Color] = [.blue, .cyan]
    
    /// Returns gradient colors based on current angle
    static func colors(for angle: Double) -> [Color] {
        if angle > badAngleThreshold { return badPostureColors }
        if angle > perfectAngleThreshold { return okayPostureColors }
        return perfectPostureColors
    }
    
    /// Returns feedback text based on current angle
    static func feedbackText(for angle: Double) -> String {
        if angle > badAngleThreshold { return "HEAD FORWARD" }
        if angle > perfectAngleThreshold { return "ALMOST THERE" }
        return "PERFECT ALIGNMENT"
    }
    
    /// Returns short status text based on angle
    static func statusText(for angle: Double) -> String {
        angle > badAngleThreshold ? "HEAD FORWARD" : "GOOD ALIGNMENT"
    }
    
    /// Calculates posture score (0-100) based on angle
    static func score(for angle: Double) -> Int {
        Int(max(0, min(100, 100 - (angle * scoreMultiplier))))
    }
}
