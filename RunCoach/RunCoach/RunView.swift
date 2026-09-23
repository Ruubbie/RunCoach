import SwiftUI

struct RunView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: RunSession
    @State private var confirmEnd = false
    @State private var effort = 5
    @State private var note = ""

    init(workout: PlannedWorkout) {
        _session = StateObject(wrappedValue: RunSession(workout: workout))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if session.phase == .ready {
                    Button { session.stopTracking(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 34, height: 34)
                            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
                Caps(session.workout.title)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(session.gpsReady ? Theme.accent : Theme.muted).frame(width: 6, height: 6)
                    Caps(session.gpsReady ? "GPS locked" : "Finding GPS",
                         color: session.gpsReady ? Theme.ink : Theme.muted)
                }
            }

            segmentBlock

            VStack(alignment: .leading, spacing: 0) {
                Caps("Total time", color: Theme.muted)
                Text(Fmt.clock(session.elapsed))
                    .font(.system(size: 88, weight: .heavy).monospacedDigit())
                    .tracking(-3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.top, 28)

            HStack(spacing: 16) {
                StatColumn(label: "Distance", value: String(format: "%.2f", session.distance / 1000), unit: "km")
                VHairline()
                StatColumn(label: "Pace now", value: Fmt.pace(session.currentPace), unit: "/km")
                VHairline()
                StatColumn(label: "Avg pace", value: Fmt.pace(session.averagePace), unit: "/km")
            }
            .padding(.top, 16)

            if session.authorizationDenied {
                Text("Location access is off. Turn it on in Settings → run. → Location.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 16)
            }

            Spacer()
            controls
        }
        .padding(24)
        .background(AppBackground())
        .preferredColorScheme(.light)
        .onAppear { session.prepare() }
        .onDisappear { session.stopTracking() }
        .confirmationDialog("End this run?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End run", role: .destructive) { session.finish() }
            Button("Keep going", role: .cancel) {}
        }
        .sheet(isPresented: Binding(get: { session.phase == .finished }, set: { _ in })) {
            saveSheet.interactiveDismissDisabled()
        }
    }

    // MARK: Current interval

    @ViewBuilder private var segmentBlock: some View {
        if let seg = session.currentSegment, session.phase != .finished {
            let totalRuns = session.workout.segments.filter { $0.kind == .run }.count
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Wordmark(text: seg.kind.wordmark, size: 56, color: seg.kind.foreground)
                    Text(Fmt.clock(session.segmentRemaining))
                        .font(Theme.number(44))
                        .foregroundStyle(seg.kind.foreground)
                    if let next = session.nextSegment {
                        Caps("Then \(next.kind.label), \(next.seconds / 60) min",
                             color: seg.kind.foreground.opacity(0.7))
                            .padding(.top, 6)
                    }
                }
                Spacer()
                if seg.kind == .run && totalRuns > 1 {
                    Text(String(format: "%02d/%02d", session.runNumber, totalRuns))
                        .font(Theme.number(16))
                        .foregroundStyle(seg.kind.foreground)
                        .rotatedVertical()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(seg.kind.blockColor)
            .padding(.top, 24)
        } else if session.workout.segments.isEmpty && session.phase != .finished {
            Wordmark(text: "free run.", size: 56).padding(.top, 24)
        }
    }

    // MARK: Controls

    @ViewBuilder private var controls: some View {
        switch session.phase {
        case .ready:
            BlockButton(title: "Start run") { session.start() }
        case .running:
            HStack(spacing: 12) {
                Button { session.pause() } label: { ArrowSquare(systemImage: "pause.fill", size: 60) }
                    .buttonStyle(.plain)
                BlockButton(title: "End run", systemImage: "stop.fill") { confirmEnd = true }
            }
        case .paused:
            HStack(spacing: 12) {
                Button { confirmEnd = true } label: { ArrowSquare(systemImage: "stop.fill", size: 60) }
                    .buttonStyle(.plain)
                BlockButton(title: "Resume", systemImage: "play.fill") { session.resume() }
            }
        case .finished:
            EmptyView()
        }
    }

    // MARK: Save

    private var saveSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Wordmark(text: "done.")

                HStack(spacing: 16) {
                    StatColumn(label: "Time", value: Fmt.clock(session.elapsed))
                    VHairline()
                    StatColumn(label: "Distance", value: String(format: "%.2f", session.distance / 1000), unit: "km")
                    VHairline()
                    StatColumn(label: "Avg pace", value: Fmt.pace(session.averagePace), unit: "/km")
                }

                Hairline()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Caps("How hard was it?")
                        Spacer()
                        Text("\(effort)/10").font(Theme.number(15))
                    }
                    HStack(spacing: 4) {
                        ForEach(1...10, id: \.self) { n in
                            Button { effort = n } label: {
                                Rectangle()
                                    .fill(n == effort ? Theme.accent : (n < effort ? Theme.ink : Theme.hairline))
                                    .frame(height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(effortHint).font(Theme.body).foregroundStyle(Theme.muted)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Caps("Notes for your coach")
                    TextField("Heavy legs, side stitch, felt great…", text: $note, axis: .vertical)
                        .font(Theme.body)
                    Hairline()
                }

                BlockButton(title: "Save run") {
                    store.add(session.record(effort: effort, note: note))
                    Notifier.reschedule(store: store)
                    dismiss()
                }

                Button("Discard run") { dismiss() }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .underline()
            }
            .padding(24)
            .padding(.top, 16)
        }
        .background(AppBackground())
    }

    private var effortHint: String {
        switch effort {
        case ...3: return "Easy. You could have kept going."
        case 4...6: return "Moderate. The right zone for most runs."
        case 7...8: return "Hard. We'll keep an eye on this."
        default: return "Very hard. Tell your coach about it."
        }
    }
}

extension RunSession {
    /// Which run interval you're in (1-based).
    var runNumber: Int {
        guard !workout.segments.isEmpty else { return 0 }
        let idx = min(segmentIndex, workout.segments.count - 1)
        return workout.segments[0...idx].filter { $0.kind == .run }.count
    }
}
