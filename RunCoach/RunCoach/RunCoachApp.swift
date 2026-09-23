import SwiftUI
import UserNotifications

/// Shows reminders even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct RunCoachApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    await Notifier.requestPermission()
                    Notifier.reschedule(store: store)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Notifier.reschedule(store: store) }
        }
    }
}

enum AppTab: CaseIterable {
    case today, log, coach

    var title: String {
        switch self {
        case .today: return "Today"
        case .log: return "Log"
        case .coach: return "Coach"
        }
    }
}

struct ContentView: View {
    @State private var tab: AppTab = .today

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .today: TodayView()
                case .log: HistoryView()
                case .coach: CoachView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabBar(selection: $tab)
        }
        .tint(Theme.ink)
        .preferredColorScheme(.light)
    }
}

struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button { selection = tab } label: {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(selection == tab ? Theme.accent : Color.clear)
                                .frame(width: 6, height: 6)
                            Caps(tab.title, color: selection == tab ? Theme.ink : Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.paper.ignoresSafeArea(edges: .bottom))
    }
}
