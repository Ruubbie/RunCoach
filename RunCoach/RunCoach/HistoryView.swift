import SwiftUI
import MapKit

struct HistoryView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        let totalKm = store.runs.reduce(0) { $0 + $1.distanceMeters } / 1000

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TopBar(lead: String(format: "%.0f", totalKm),
                           caption: "km total",
                           trailing: "\(store.runs.count) sessions")
                    Wordmark(text: "log.")
                        .padding(.top, 24)
                        .padding(.bottom, 20)

                    if store.runs.isEmpty {
                        Text("No runs yet. Finish today's session and it shows up here.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.muted)
                    } else {
                        Hairline()
                    }

                    ForEach(Array(store.runs.enumerated()), id: \.element.id) { i, run in
                        NavigationLink {
                            RunDetailView(run: run)
                        } label: {
                            LogRow(number: store.runs.count - i, run: run)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete run", role: .destructive) { store.delete(at: IndexSet(integer: i)) }
                        }
                        Hairline()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct LogRow: View {
    let number: Int
    let run: RunRecord

    var body: some View {
        HStack(spacing: 16) {
            Text(String(format: "%03d", number))
                .font(Theme.number(15))
                .foregroundStyle(run.dayType == .run ? Theme.accent : Theme.muted)
            VStack(alignment: .leading, spacing: 4) {
                Text(run.workoutTitle).font(Theme.rowTitle).lineLimit(1)
                Caps(run.date.formatted(date: .abbreviated, time: .shortened), color: Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f", run.distanceMeters / 1000)).font(Theme.number(22))
                Caps("km in \(Fmt.clock(run.durationSeconds))", color: Theme.muted)
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

struct RunDetailView: View {
    let run: RunRecord

    var body: some View {
        let fastest = run.splits.min() ?? 1

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Wordmark(text: String(format: "%.2f", run.distanceMeters / 1000), size: 76)
                        Caps("km")
                    }
                    Caps("\(run.workoutTitle), \(run.date.formatted(date: .abbreviated, time: .shortened))",
                         color: Theme.muted)
                }

                if run.route.count > 1 {
                    Map {
                        MapPolyline(coordinates: run.route.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                        })
                        .stroke(Theme.accent, lineWidth: 4)
                    }
                    .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
                    .frame(height: 240)
                }

                HStack(spacing: 16) {
                    StatColumn(label: "Time", value: Fmt.clock(run.durationSeconds))
                    VHairline()
                    StatColumn(label: "Avg pace", value: Fmt.pace(run.avgPace), unit: "/km")
                    VHairline()
                    StatColumn(label: "Effort", value: run.effort.map { "\($0)" } ?? "–", unit: "/10")
                }

                HStack(spacing: 8) {
                    Rectangle().fill(run.completedPlan ? Theme.accent : Theme.hairline).frame(width: 6, height: 6)
                    Caps(run.completedPlan ? "Full plan completed" : "Stopped before the plan ended")
                }

                if !run.splits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Caps("Splits", color: Theme.muted)
                        ForEach(Array(run.splits.enumerated()), id: \.offset) { i, s in
                            HStack(spacing: 12) {
                                Caps(String(format: "Km %02d", i + 1)).frame(width: 52, alignment: .leading)
                                GeometryReader { g in
                                    Rectangle()
                                        .fill(s == fastest ? Theme.accent : Theme.ink)
                                        .frame(width: g.size.width * CGFloat(fastest / s))
                                }
                                .frame(height: 6)
                                Text(Fmt.pace(s)).font(Theme.number(14)).frame(width: 48, alignment: .trailing)
                            }
                        }
                    }
                }

                if let note = run.note {
                    VStack(alignment: .leading, spacing: 6) {
                        Caps("Notes", color: Theme.muted)
                        Text(note).font(Theme.body)
                    }
                }
            }
            .padding(24)
        }
        .background(AppBackground())
        .navigationBarTitleDisplayMode(.inline)
    }
}
