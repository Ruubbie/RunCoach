import Foundation
import CoreLocation

/// Live run: GPS tracking (works with the screen locked), interval timing and voice cues.
@MainActor
final class RunSession: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Phase { case ready, running, paused, finished }

    let workout: PlannedWorkout
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var currentPace: Double?
    @Published private(set) var segmentIndex = 0
    @Published private(set) var segmentRemaining: Double = 0
    @Published private(set) var gpsAccuracy: Double = -1
    @Published private(set) var authorizationDenied = false

    private let manager = CLLocationManager()
    private let voice = VoiceCoach()
    private var timer: Timer?
    private var accumulated: Double = 0
    private var resumedAt: Date?
    private var startedAt: Date?
    private var lastLocation: CLLocation?
    private var route: [RoutePoint] = []
    private var window: [(t: Double, d: Double)] = []
    private var splits: [Double] = []
    private var lastSplitAt: Double = 0
    private var nextKm: Double = 1000
    private var spoken = Set<String>()
    private let segmentStarts: [Double]
    private let plannedTotal: Double

    init(workout: PlannedWorkout) {
        self.workout = workout
        var t = 0.0
        var starts: [Double] = []
        for s in workout.segments { starts.append(t); t += Double(s.seconds) }
        segmentStarts = starts
        plannedTotal = t
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
        if let first = workout.segments.first { segmentRemaining = Double(first.seconds) }
    }

    var currentSegment: Segment? {
        workout.segments.indices.contains(segmentIndex) ? workout.segments[segmentIndex] : nil
    }
    var nextSegment: Segment? {
        workout.segments.indices.contains(segmentIndex + 1) ? workout.segments[segmentIndex + 1] : nil
    }
    var gpsReady: Bool { gpsAccuracy > 0 && gpsAccuracy <= 20 }
    var averagePace: Double? { distance > 50 ? elapsed / (distance / 1000) : nil }

    // MARK: Controls

    /// Start GPS early so it has a lock by the time you press Start.
    func prepare() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: authorizationDenied = true
        default: break
        }
        manager.startUpdatingLocation()
    }

    func start() {
        guard phase == .ready else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        startedAt = Date()
        resume(initial: true)
    }

    func pause() {
        guard phase == .running else { return }
        refreshElapsed()
        accumulated = elapsed
        resumedAt = nil
        lastLocation = nil
        phase = .paused
        timer?.invalidate()
        voice.say("Paused.")
    }

    func resume(initial: Bool = false) {
        guard phase == .paused || initial else { return }
        resumedAt = Date()
        phase = .running
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if initial {
            if let first = workout.segments.first { announce(segment: first, index: 0) }
            else { voice.say("Free run started. Enjoy it.") }
        } else {
            voice.say("Resumed. Let's go.")
        }
    }

    func finish() {
        if phase == .running { refreshElapsed() }
        stopTracking()
        resumedAt = nil
        phase = .finished
        voice.say("Done. \(String(format: "%.2f", distance / 1000)) kilometers in \(Fmt.spoken(elapsed)). Proud of you.")
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func record(effort: Int, note: String) -> RunRecord {
        RunRecord(date: startedAt ?? Date(),
                  workoutTitle: workout.title,
                  dayType: workout.dayType,
                  durationSeconds: elapsed,
                  distanceMeters: distance,
                  splits: splits,
                  route: route,
                  completedPlan: workout.segments.isEmpty || elapsed >= plannedTotal - 5,
                  effort: effort,
                  note: note.isEmpty ? nil : note)
    }

    // MARK: Timing & cues

    private func refreshElapsed() {
        if let r = resumedAt { elapsed = accumulated + Date().timeIntervalSince(r) }
    }

    private func tick() {
        guard phase == .running else { return }
        refreshElapsed()
        updateSegments()
    }

    private func updateSegments() {
        guard !workout.segments.isEmpty else { return }
        var idx = 0
        while idx + 1 < segmentStarts.count && elapsed >= segmentStarts[idx + 1] { idx += 1 }
        if idx != segmentIndex {
            segmentIndex = idx
            announce(segment: workout.segments[idx], index: idx)
        }
        let seg = workout.segments[idx]
        segmentRemaining = max(0, segmentStarts[idx] + Double(seg.seconds) - elapsed)

        if let next = nextSegment, segmentRemaining <= 10, segmentRemaining > 0 {
            once("ten-\(idx)", next.kind == .run ? "Ten seconds. Get ready to run." : "Ten seconds, then you can walk.")
        }
        if seg.kind == .run, seg.seconds >= 240, segmentRemaining <= Double(seg.seconds) / 2 {
            once("half-\(idx)", "Halfway through this interval. \(Fmt.spoken(segmentRemaining)) to go. Relax your shoulders.")
        }
        if elapsed >= plannedTotal {
            once("done", "That's the whole workout. Nailed it. Stop whenever you're ready and save your run.")
        }
    }

    private func announce(segment: Segment, index: Int) {
        let length = Fmt.spoken(Double(segment.seconds))
        if workout.dayType == .recovery {
            voice.say("Recovery walk. \(length) at a brisk pace. Swing those arms.")
            return
        }
        let runNumber = workout.segments[0...index].filter { $0.kind == .run }.count
        let totalRuns = workout.segments.filter { $0.kind == .run }.count
        switch segment.kind {
        case .warmup:
            voice.say("Let's go. Start with a \(length) brisk walk to warm up.")
        case .run:
            voice.say(totalRuns > 1
                      ? "Run! Interval \(runNumber) of \(totalRuns). \(length), easy pace. You should be able to talk."
                      : "Run! \(length). Easy, steady pace.")
        case .walk:
            voice.say("Walk. \(length) to recover. Nice work.")
        case .cooldown:
            voice.say("Running's done! Cool down with a \(length) easy walk.")
        }
    }

    private func once(_ key: String, _ text: String) {
        guard !spoken.contains(key) else { return }
        spoken.insert(key)
        voice.say(text)
    }

    // MARK: GPS

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.handle(locations) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationDenied = (status == .denied || status == .restricted)
        }
    }

    private func handle(_ locations: [CLLocation]) {
        for loc in locations {
            gpsAccuracy = loc.horizontalAccuracy
            guard phase == .running else { continue }
            guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy <= 25,
                  abs(loc.timestamp.timeIntervalSinceNow) < 15 else { continue }
            refreshElapsed()

            if let last = lastLocation {
                let d = loc.distance(from: last)
                let dt = loc.timestamp.timeIntervalSince(last.timestamp)
                guard dt > 0 else { continue }
                if d / dt > 12 { continue }   // GPS jump, faster than a sprinter: ignore
                distance += d
            }
            lastLocation = loc
            route.append(RoutePoint(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude, t: elapsed))

            // Current pace over the last ~30 seconds.
            window.append((t: elapsed, d: distance))
            window.removeAll { elapsed - $0.t > 30 }
            if let first = window.first, elapsed - first.t >= 10 {
                let dd = distance - first.d
                currentPace = dd > 10 ? (elapsed - first.t) / (dd / 1000) : nil
            }

            while distance >= nextKm {
                let split = elapsed - lastSplitAt
                splits.append(split)
                lastSplitAt = elapsed
                let km = Int(nextKm / 1000)
                voice.say("\(km) kilometer\(km == 1 ? "" : "s"). Time \(Fmt.spoken(elapsed)). That kilometer took \(Fmt.spoken(split)).")
                nextKm += 1000
            }
        }
    }
}
