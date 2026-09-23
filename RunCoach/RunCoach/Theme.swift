import SwiftUI

/// Visual language: pale grey paper, pure black type, one vermilion block per screen,
/// oversized lowercase wordmarks, tiny tracked labels, square buttons, hairlines.
enum Theme {
    static let paper = Color(red: 0.949, green: 0.949, blue: 0.949)   // #F2F2F2
    static let ink = Color.black
    static let accent = Color(red: 1.0, green: 0.302, blue: 0.122)     // #FF4D1F
    static let muted = Color(red: 0.55, green: 0.55, blue: 0.55)
    static let hairline = Color.black.opacity(0.15)

    static func wordmark(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy).monospacedDigit() }
    static let label = Font.system(size: 10, weight: .bold)
    static let body = Font.system(size: 13, weight: .regular)
    static let rowTitle = Font.system(size: 15, weight: .semibold)
}

// MARK: - Type

struct Wordmark: View {
    let text: String
    var size: CGFloat = 84
    var color: Color = Theme.ink

    var body: some View {
        Text(text)
            .font(Theme.wordmark(size))
            .tracking(-size * 0.05)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

struct Caps: View {
    let text: String
    var color: Color = Theme.ink

    init(_ text: String, color: Color = Theme.ink) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label)
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

// MARK: - Structure

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.hairline).frame(height: 1) }
}

struct VHairline: View {
    var body: some View { Rectangle().fill(Theme.hairline).frame(width: 1, height: 36) }
}

/// Rotates a view 90° and swaps its layout box, for the vertical labels.
struct RotatedLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let s = subviews.first else { return .zero }
        let size = s.sizeThatFits(.unspecified)
        return CGSize(width: size.height, height: size.width)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let s = subviews.first else { return }
        let size = s.sizeThatFits(.unspecified)
        s.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(size))
    }
}

extension View {
    func rotatedVertical() -> some View {
        RotatedLayout { self.rotationEffect(.degrees(90)) }
    }
}

// MARK: - Controls

struct ArrowSquare: View {
    var systemImage = "arrow.right"
    var fill: Color = Theme.ink
    var foreground: Color = .white
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.32, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(fill)
    }
}

/// Vermilion block with a black arrow square: the one primary action on a screen.
struct BlockButton: View {
    let title: String
    var systemImage = "arrow.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                ArrowSquare(systemImage: systemImage, size: 60)
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                Spacer(minLength: 0)
            }
            .background(Theme.accent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SquareIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Layout pieces

struct TopBar: View {
    let lead: String
    let caption: String
    let trailing: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(lead).font(.system(size: 17, weight: .heavy))
            Caps(caption, color: Theme.muted)
            Spacer()
            Caps(trailing)
        }
        .padding(.top, 8)
    }
}

struct StatColumn: View {
    let label: String
    let value: String
    var unit: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Caps(label, color: Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(Theme.number(22)).lineLimit(1).minimumScaleFactor(0.6)
                if let unit {
                    Text(unit).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingRow<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title).font(Theme.rowTitle)
            Spacer()
            trailing
        }
        .padding(.vertical, 12)
    }
}

struct WeekDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? Theme.accent : (i < current ? Theme.ink : Theme.hairline))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

// MARK: - Background

struct Sphere: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [.white, Color(white: 0.9)],
                                 center: UnitPoint(x: 0.35, y: 0.3),
                                 startRadius: 1, endRadius: size * 0.7))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.06), radius: 16, y: 10)
    }
}

struct AppBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.paper
                Sphere(size: 180).position(x: geo.size.width + 30, y: geo.size.height * 0.62)
                Sphere(size: 90).position(x: -10, y: geo.size.height * 0.35)
                Sphere(size: 14).position(x: geo.size.width * 0.72, y: 120)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Segment styling

extension SegmentKind {
    /// Small markers and the plan bar.
    var color: Color {
        switch self {
        case .run: return Theme.accent
        case .walk: return Theme.ink
        case .warmup, .cooldown: return Theme.muted.opacity(0.35)
        }
    }

    /// Full-width block on the run screen.
    var blockColor: Color {
        switch self {
        case .run: return Theme.accent
        case .walk: return Theme.ink
        case .warmup, .cooldown: return .white
        }
    }

    var foreground: Color { self == .walk ? .white : Theme.ink }

    var wordmark: String {
        switch self {
        case .run: return "run."
        case .walk: return "walk."
        case .warmup: return "warm up."
        case .cooldown: return "cool down."
        }
    }
}
