import Foundation

enum SegmentKind: String, Codable {
    case warmup, run, walk, cooldown

    var label: String {
        switch self {
        case .warmup: return "Warm-up walk"
        case .run: return "Run"
        case .walk: return "Walk"
        case .cooldown: return "Cool-down walk"
        }
    }
}

struct Segment: Hashable {
    var kind: SegmentKind
    var seconds: Int
}

enum DayType: String, Codable {
    case run, recovery, rest
}

struct PlannedWorkout: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var summary: String
    var dayType: DayType
    var segments: [Segment]
    var totalSeconds: Int { segments.reduce(0) { $0 + $1.seconds } }
}

struct RoutePoint: Codable {
    var lat: Double
    var lon: Double
    var t: Double
}

struct RunRecord: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var workoutTitle: String
    var dayType: DayType
    var durationSeconds: Double
    var distanceMeters: Double
    var splits: [Double]          // seconds per kilometer
    var route: [RoutePoint]
    var completedPlan: Bool
    var effort: Int?              // 1-10
    var note: String?

    var avgPace: Double? { distanceMeters > 50 ? durationSeconds / (distanceMeters / 1000) : nil }
}

struct CoachSettings: Codable, Equatable {
    var programStart: Date = Calendar.current.startOfDay(for: Date())
    var reminderHour: Int = 18
    var restWeekday: Int = 1      // 1 = Sunday ... 7 = Saturday
}

enum Fmt {
    static func clock(_ seconds: Double) -> String {
        let t = max(0, Int(seconds.rounded()))
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func pace(_ secPerKm: Double?) -> String {
        guard let p = secPerKm, p.isFinite, p > 0, p < 3600 else { return "–:––" }
        let t = Int(p.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    static func spoken(_ seconds: Double) -> String {
        let t = max(0, Int(seconds.rounded()))
        let m = t / 60, s = t % 60
        let minutes = "\(m) minute\(m == 1 ? "" : "s")"
        if m == 0 { return "\(s) seconds" }
        return s == 0 ? minutes : "\(minutes) \(s)"
    }
}
