import SwiftUI
import UIKit

struct CoachView: View {
    @EnvironmentObject private var store: Store
    @State private var copied = false
    private let voice = VoiceCoach()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TopBar(lead: "+\(store.streak)", caption: "day streak", trailing: "Your coach")
                Wordmark(text: "coach.").padding(.top, 24)
                Text("Copy your training summary, paste it into a Claude chat and ask anything: how it's going, whether to push harder, what comes next.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                BlockButton(title: copied ? "Copied. Paste it into Claude" : "Copy training summary",
                            systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = CoachExport.text(store: store)
                    copied = true
                }
                .padding(.top, 20)

                Caps("Schedule", color: Theme.muted).padding(.top, 40).padding(.bottom, 4)
                Hairline()
                SettingRow("Reminder") {
                    HStack(spacing: 0) {
                        SquareIconButton(systemImage: "minus") {
                            store.settings.reminderHour = max(5, store.settings.reminderHour - 1)
                        }
                        Text("\(store.settings.reminderHour):00")
                            .font(Theme.number(17))
                            .frame(width: 70)
                        SquareIconButton(systemImage: "plus") {
                            store.settings.reminderHour = min(20, store.settings.reminderHour + 1)
                        }
                    }
                }
                Hairline()
                SettingRow("Rest day") {
                    Menu {
                        Picker("Rest day", selection: $store.settings.restWeekday) {
                            ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(Calendar.current.weekdaySymbols[store.settings.restWeekday - 1]).font(Theme.rowTitle)
                            Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Theme.ink)
                    }
                }
                Hairline()
                SettingRow("Program start") {
                    DatePicker("Program start", selection: $store.settings.programStart, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
                Hairline()
                Button {
                    store.settings.programStart = Calendar.current.date(byAdding: .day, value: 7,
                                                                        to: store.settings.programStart)!
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Repeat this week").font(Theme.rowTitle).foregroundStyle(Theme.ink)
                            Text("Too hard? Push the plan back one week.").font(Theme.body).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        ArrowSquare(systemImage: "arrow.counterclockwise", size: 34)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Hairline()

                Caps("Check your setup", color: Theme.muted).padding(.top, 40).padding(.bottom, 4)
                Hairline()
                testRow("Hear a voice cue") { voice.say("Run! Interval 1 of 4. 4 minutes, easy pace.") }
                Hairline()
                testRow("Send a test reminder in 5 seconds") { Notifier.test() }
                Hairline()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .onChange(of: store.settings) { _, _ in Notifier.reschedule(store: store) }
    }

    private func testRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(Theme.rowTitle).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum CoachExport {
    @MainActor
    static func text(store: Store) -> String {
        let s = store.settings
        let now = Date()
        let cal = Calendar.current
        let week = PlanEngine.weekIndex(for: now, settings: s)
        let program = week < PlanEngine.programWeeks
            ? "week \(week + 1) of \(PlanEngine.programWeeks)"
            : "8-week plan finished"

        var lines: [String] = []
        lines.append("run. summary, \(now.formatted(date: .abbreviated, time: .shortened))")
        lines.append("Program: \(program) (started \(s.programStart.formatted(date: .abbreviated, time: .omitted))). Rest day: \(cal.weekdaySymbols[s.restWeekday - 1]). Reminders at \(s.reminderHour):00.")
        lines.append("Streak: \(store.streak) days. This week: \(String(format: "%.1f", store.distanceThisWeek / 1000)) km.")
        lines.append("")
        lines.append("Next 7 days:")
        for offset in 0..<7 {
            let day = cal.date(byAdding: .day, value: offset, to: now)!
            let w = PlanEngine.workout(for: day, settings: s)
            lines.append("- \(day.formatted(.dateTime.weekday(.wide))): \(w.title). \(w.summary)")
        }
        lines.append("")
        lines.append("Recent sessions (newest first):")
        if store.runs.isEmpty { lines.append("- none yet") }
        for r in store.runs.prefix(15) {
            var line = "- \(r.date.formatted(date: .abbreviated, time: .shortened)) | \(r.workoutTitle) | \(String(format: "%.2f", r.distanceMeters / 1000)) km in \(Fmt.clock(r.durationSeconds)) | avg \(Fmt.pace(r.avgPace))/km | plan completed: \(r.completedPlan ? "yes" : "no")"
            if !r.splits.isEmpty { line += " | splits: " + r.splits.map { Fmt.pace($0) }.joined(separator: ", ") }
            if let e = r.effort { line += " | effort \(e)/10" }
            if let n = r.note { line += " | note: \(n)" }
            lines.append(line)
        }
        lines.append("")
        lines.append("You're my running coach. Review how I'm doing, be honest and strict, and tell me what to adjust.")
        return lines.joined(separator: "\n")
    }
}
