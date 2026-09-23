import Foundation

/// 8-week run/walk program: from ~10-15 min of running to 30 min nonstop.
enum PlanEngine {
    static let programWeeks = 8

    // Per week: minutes running, minutes walking between, repetitions.
    static let intervals: [(run: Int, walk: Int, reps: Int)] = [
        (4, 1, 4), (5, 1, 4), (7, 1, 3), (8, 1, 3),
        (10, 1, 3), (13, 1, 2), (15, 1, 2), (30, 0, 1)
    ]

    static func weekIndex(for date: Date, settings: CoachSettings) -> Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: settings.programStart),
                                      to: cal.startOfDay(for: date)).day ?? 0
        return max(0, days / 7)
    }

    /// 0 = rest day, 1...6 = days after the rest day.
    static func dayPosition(for date: Date, restWeekday: Int) -> Int {
        let wd = Calendar.current.component(.weekday, from: date)
        return ((wd - restWeekday) % 7 + 7) % 7
    }

    static func workout(for date: Date, settings: CoachSettings) -> PlannedWorkout {
        let week = weekIndex(for: date, settings: settings)
        let pos = dayPosition(for: date, restWeekday: settings.restWeekday)
        let label = week < programWeeks ? "Week \(week + 1)" : "Maintenance"

        if pos == 0 {
            return PlannedWorkout(title: "Rest day",
                                  summary: "Full rest. Sleep well, stretch, drink water. You earned it.",
                                  dayType: .rest, segments: [])
        }
        let runDays: Set<Int> = week < 4 ? [1, 3, 5] : [1, 3, 5, 6]
        if runDays.contains(pos) {
            return runWorkout(week: week, short: pos == 6, label: label)
        }
        return PlannedWorkout(title: "\(label) · Recovery walk",
                              summary: "25 min brisk walk. Easy effort, keeps the habit alive.",
                              dayType: .recovery,
                              segments: [Segment(kind: .walk, seconds: 25 * 60)])
    }

    static func runWorkout(week: Int, short: Bool, label: String) -> PlannedWorkout {
        let step = intervals[min(week, intervals.count - 1)]
        var run = step.run
        var reps = step.reps
        let walk = step.walk
        if short {
            if walk == 0 { run = 20 } else { reps = max(1, reps - 1) }
        }
        var segments = [Segment(kind: .warmup, seconds: 5 * 60)]
        for i in 0..<reps {
            segments.append(Segment(kind: .run, seconds: run * 60))
            if walk > 0 && i < reps - 1 {
                segments.append(Segment(kind: .walk, seconds: walk * 60))
            }
        }
        segments.append(Segment(kind: .cooldown, seconds: 5 * 60))
        let summary = walk > 0
            ? "\(reps) × \(run) min run with \(walk) min walks"
            : "\(run) min continuous easy run"
        return PlannedWorkout(title: "\(label) · \(short ? "Easy run" : "Run")",
                              summary: summary + ". 5 min walk before and after.",
                              dayType: .run, segments: segments)
    }

    static func freeRun() -> PlannedWorkout {
        PlannedWorkout(title: "Free run", summary: "No intervals, just go.", dayType: .run, segments: [])
    }
}
