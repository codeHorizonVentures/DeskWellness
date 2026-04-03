import Foundation

struct ResetConsistencyEntry {
    let date: Date
    let kind: JournalEntryKind
    let exercisesCompleted: Bool
}

struct ResetConsistencySummary {
    let weeklyGoal: Int
    let completedResets: Int
    let loggedResets: Int
    let checkIns: Int
    let activeDays: Int

    var remainingResets: Int {
        max(0, weeklyGoal - completedResets)
    }

    var hasReachedGoal: Bool {
        completedResets >= weeklyGoal
    }

    var progressFraction: Double {
        guard weeklyGoal > 0 else { return 1 }
        return min(1, Double(completedResets) / Double(weeklyGoal))
    }

    var headline: String {
        if hasReachedGoal {
            return "Weekly goal reached"
        }

        if completedResets == 0 {
            return "Start your first reset this week"
        }

        if remainingResets == 1 {
            return "1 more reset to reach your weekly goal"
        }

        return "\(remainingResets) more resets to reach your weekly goal"
    }

    var supportingText: String {
        if completedResets == 0 {
            return "Aim for \(weeklyGoal) completed desk resets this week."
        }

        if hasReachedGoal {
            return "You completed \(completedResets) resets across \(activeDays) active day\(activeDays == 1 ? "" : "s")."
        }

        return "\(completedResets) of \(weeklyGoal) completed resets so far."
    }

    static func build(
        from entries: [ResetConsistencyEntry],
        now: Date = Date(),
        calendar: Calendar = .current,
        weeklyGoal: Int = 3
    ) -> ResetConsistencySummary {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return ResetConsistencySummary(
                weeklyGoal: weeklyGoal,
                completedResets: 0,
                loggedResets: 0,
                checkIns: 0,
                activeDays: 0
            )
        }

        let weeklyEntries = entries.filter { weekInterval.contains($0.date) }
        let weeklyResets = weeklyEntries.filter { $0.kind == .workout }
        let completedWeeklyResets = weeklyResets.filter(\.exercisesCompleted)
        let checkIns = weeklyEntries.filter { $0.kind == .scan }.count

        let activeDays = Set(
            completedWeeklyResets.map { calendar.startOfDay(for: $0.date) }
        ).count

        return ResetConsistencySummary(
            weeklyGoal: weeklyGoal,
            completedResets: completedWeeklyResets.count,
            loggedResets: weeklyResets.count,
            checkIns: checkIns,
            activeDays: activeDays
        )
    }
}
