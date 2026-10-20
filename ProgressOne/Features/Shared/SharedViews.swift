import SwiftUI
import ProgressCore

extension Color {
    /// Parses `#RRGGBB`. Falls back to the accent color for anything else.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            self = .accentColor
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// The sync state as a small chip, tappable to open the full status.
struct SyncStatusBadge: View {
    @Environment(SyncCoordinator.self) private var sync

    var body: some View {
        let state = sync.displayState
        Label(state.title, systemImage: state.symbol)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint(for: state).opacity(0.15), in: Capsule())
            .foregroundStyle(tint(for: state))
            .accessibilityLabel("Sync status: \(state.title)")
    }

    private func tint(for state: SyncCoordinator.DisplayState) -> Color {
        switch state {
        case .synced: .green
        case .syncing, .pending: .blue
        case .localOnly, .offline: .secondary
        case .conflicts, .error: .orange
        }
    }
}

/// An honest placeholder for a section that is planned but not built yet.
struct PlannedFeatureView: View {
    let title: String
    let symbol: String
    let step: String
    let items: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.largeTitle.bold())
                Text("Planned for \(step). Nothing here is working yet.")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Label(item, systemImage: "circle.dashed")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .navigationTitle(title)
    }
}

struct WorkspaceDot: View {
    let colorHex: String?

    var body: some View {
        Circle()
            .fill(colorHex.map { Color(hex: $0) } ?? .secondary)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

extension TaskPriority {
    var color: Color {
        switch self {
        case .low: .secondary
        case .medium: .blue
        case .high: .orange
        case .critical: .red
        }
    }
}
