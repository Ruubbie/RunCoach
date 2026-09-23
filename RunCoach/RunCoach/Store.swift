import Foundation
import SwiftUI

@MainActor
final class Store: ObservableObject {
    @Published private(set) var runs: [RunRecord] = []
    @Published var settings: CoachSettings {
        didSet { save(settings, to: settingsURL) }
    }

    private let runsURL: URL
    private let settingsURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        runsURL = dir.appendingPathComponent("runs.json")
        settingsURL = dir.appendingPathComponent("settings.json")
        settings = Store.load(CoachSettings.self, from: settingsURL) ?? CoachSettings()
        runs = Store.load([RunRecord].self, from: runsURL) ?? []
    }

    func add(_ run: RunRecord) {
        runs.insert(run, at: 0)
        save(runs, to: runsURL)
    }

    func delete(at offsets: IndexSet) {
        runs.remove(atOffsets: offsets)
        save(runs, to: runsURL)
    }

    /// A day counts when you logged at least 10 minutes of activity.
    func didActivity(on date: Date) -> Bool {
        runs.contains { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.durationSeconds >= 10 * 60 }
    }

    /// Consecutive active days. Rest days don't break the streak; skipped workout days do.
    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if !didActivity(on: day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        let start = cal.startOfDay(for: settings.programStart)
        var count = 0
        while day >= start {
            if didActivity(on: day) {
                count += 1
            } else if PlanEngine.workout(for: day, settings: settings).dayType != .rest {
                break
            }
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    var distanceThisWeek: Double {
        guard let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return runs.filter { $0.date >= start }.reduce(0) { $0 + $1.distanceMeters }
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(value) { try? data.write(to: url, options: .atomic) }
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(type, from: data)
    }
}
