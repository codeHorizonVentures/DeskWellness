//
//  JournalModels.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 07.02.2026.
//

import Foundation
import SwiftData
import SwiftUI

/// Represents a value type for stored entries (Scan or Workout)
enum EntryType: String, Codable {
    case scan
    case workout
}

@Model
class DailyEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var type: EntryType
    var note: String?
    var photoPath: String? // Side profile
    var frontPhotoPath: String? // Front profile
    var exercisesCompleted: Bool = false
    var cvaScore: Double? // For scan results
    var frontPointsData: Data? // Serialized FrontPosePoints
    var sidePointsData: Data? // Serialized SidePosePoints
    
    init(date: Date = Date(), type: EntryType, note: String? = nil, photoPath: String? = nil, frontPhotoPath: String? = nil, exercisesCompleted: Bool = false, cvaScore: Double? = nil, frontPointsData: Data? = nil, sidePointsData: Data? = nil) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.note = note
        self.photoPath = photoPath
        self.frontPhotoPath = frontPhotoPath
        self.exercisesCompleted = exercisesCompleted
        self.cvaScore = cvaScore
        self.frontPointsData = frontPointsData
        self.sidePointsData = sidePointsData
    }
    
    // MARK: - Helpers
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var iconName: String {
        switch type {
        case .scan: return "camera.viewfinder"
        case .workout: return "figure.mind.and.body"
        }
    }

    var color: Color {
        switch type {
        case .scan: return .blue
        case .workout: return .orange
        }
    }

    var journalEntryKind: JournalEntryKind {
        switch type {
        case .scan:
            return .scan
        case .workout:
            return .workout
        }
    }

    var journalTitle: String {
        JournalPresentation.title(for: journalEntryKind)
    }

    var journalStatusText: String {
        JournalPresentation.statusText(for: journalEntryKind, exercisesCompleted: exercisesCompleted)
    }

    var hasSavedImages: Bool {
        photoPath != nil || frontPhotoPath != nil
    }

    var hasPoseData: Bool {
        frontPointsData != nil || sidePointsData != nil
    }

    var hasAnyVisualData: Bool {
        hasSavedImages || hasPoseData
    }

    var resetConsistencyEntry: ResetConsistencyEntry {
        ResetConsistencyEntry(
            date: date,
            kind: journalEntryKind,
            exercisesCompleted: exercisesCompleted
        )
    }
}
