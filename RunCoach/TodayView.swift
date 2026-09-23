import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: Store
    @State private var active: PlannedWorkout?

    var body: some View {
        let now = Date()
        let workout = PlanEngine.workout(for: now, settings: store.settings)
        let week = PlanEngine.weekIndex(for: now, settings: store.settings)
        let doneToday = store.didActivity(on: now)
        let inProgram = week < PlanEngine.programWeeks

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TopBar(lead: "+\(store.streak)",
                       caption: "day streak",
                       trailing: inProgram ? "Week \(week + 1)/\(PlanEngine.programWeeks)" : "Plan complete")
                    .padding(.horizontal, 24)

                HStack(alignment: .top) {
                    Wordmark(text: "run.")
                    Spacer()
                    Caps(doneToday ? "Done today" : (workout.dayType == .rest ? "Rest day" : "Today's session"),
                         color: doneToday ? Theme.accent : Theme.ink)
                        .rotatedVertical()
                        .padding(.top, 14)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                hero(workout: workout, doneToday: doneToday)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Caps(workout.title)
                            Text(workout.summary)
                                .font(Theme.body)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Caps("This week", color: Theme.muted)
                            Text(String(format: "%.1f", store.distanceThisWeek / 1000)).font(Theme.number(26))
                            Caps("km", color: Theme.muted)
                        }
                    }

                    if !workout.segments.isEmpty {
                        SegmentBar(segments: workout.segments).frame(height: 8)
                    }

                    HStack {
                        WeekDots(current: min(week, PlanEngine.programWeeks - 1), total: PlanEngine.programWeeks)
                        Spacer()
                        Button("Free run, no intervals") { active = PlanEngine.freeRun() }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .underline()
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Caps("Coming up", color: Theme.muted).padding(.bottom, 8)
                        Hairline()
                        ForEach(1..<7, id: \.self) { offset in
                            let day = Calendar.current.date(byAdding: .day, value: offset, to: now)!
                            let w = PlanEngine.workout(for: day, settings: store.settings)
                            HStack(spacing: 12) {
                                Rectangle().fill(marker(for: w.dayType)).frame(width: 6, height: 6)
                                Caps(day.formatted(.dateTime.weekday(.abbreviated)), color: Theme.muted)
                                    .frame(width: 36, alignment: .leading)
                                Text(w.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                Spacer()
                                Text(w.dayType == .rest ? "–" : "\(w.totalSeconds / 60)′")
                                    .font(Theme.number(15))
                            }
                            .padding(.vertical, 12)
                            Hairline()
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .background(AppBackground())
        .fullScreenCover(item: $active) { w in RunView(workout: w) }
    }

    /// The session number, the figure, and the orange block with the start button.
    private func hero(workout: PlannedWorkout, doneToday: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(String(format: "%03d", store.runs.count + 1))
                .font(Theme.number(44))
                .tracking(-1)
                .rotatedVertical()
                .frame(width: 64)
                .padding(.bottom, 12)

            ZStack(alignment: .bottomLeading) {
                Theme.accent
                    .frame(height: 210)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Image(systemName: symbol(for: workout.dayType))
                    .font(.system(size: 220, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 18)

                if workout.dayType != .rest {
                    Button { active = workout } label: {
                        HStack(spacing: 14) {
                            ArrowSquare(size: 60)
                            Caps(doneToday ? "Go again" : "Start")
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 290)
        }
    }

    private func symbol(for type: DayType) -> String {
        switch type {
        case .run: return "figure.run"
        case .recovery: return "figure.walk"
        case .rest: return "figure.mind.and.body"
        }
    }

    private func marker(for type: DayType) -> Color {
        switch type {
        case .run: return Theme.accent
        case .recovery: return Theme.ink
        case .rest: return Theme.hairline
        }
    }
}

struct SegmentBar: View {
    let segments: [Segment]

    var body: some View {
        GeometryReader { geo in
            let total = max(1, segments.reduce(0) { $0 + $1.seconds })
            let usable = geo.size.width - CGFloat(segments.count * 2)
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, s in
                    Rectangle()
                        .fill(s.kind.color)
                        .frame(width: max(2, usable * CGFloat(s.seconds) / CGFloat(total)))
                }
            }
        }
    }
}
