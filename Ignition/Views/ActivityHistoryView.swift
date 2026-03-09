import SwiftUI

struct ActivityHistoryView: View {
    @EnvironmentObject var historyService: ActivityHistoryService
    let agentLabel: String?

    @State private var events: [ActivityEvent] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Text(agentLabel != nil ? "Activity" : "Recent Activity")
                    .font(.headline)
                Spacer()

                if !events.isEmpty {
                    Button {
                        if let label = agentLabel {
                            historyService.clearHistory(for: label)
                        } else {
                            historyService.clearHistory()
                        }
                        refreshEvents()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear history")
                }
            }

            if events.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                        Text("No activity recorded yet")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(events) { event in
                        ActivityEventRow(event: event, showLabel: agentLabel == nil)
                    }
                }
            }
        }
        .onAppear { refreshEvents() }
        .onChange(of: historyService.recentEvents) { refreshEvents() }
    }

    private func refreshEvents() {
        if let label = agentLabel {
            events = historyService.eventsForAgent(label)
        } else {
            events = historyService.allRecentEvents()
        }
    }
}

struct ActivityEventRow: View {
    let event: ActivityEvent
    let showLabel: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.eventType.icon)
                .font(.system(size: 12))
                .foregroundStyle(eventColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if showLabel {
                        Text(event.label)
                            .font(.system(.caption, weight: .medium))
                            .lineLimit(1)
                    }
                    Text(event.eventType.rawValue.capitalized)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(eventColor)
                }

                HStack(spacing: 8) {
                    Text(event.timestamp, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    if let exit = event.exitCode {
                        Text("exit \(exit)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(exit == 0 ? Color.secondary : Color.red)
                    }

                    if let detail = event.detail {
                        Text(detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.08) : .clear)
        )
        .onHover { isHovered = $0 }
    }

    private var eventColor: Color {
        switch event.eventType.colorName {
        case "green": return .green
        case "red": return .red
        case "blue": return .blue
        case "orange": return .orange
        default: return .gray
        }
    }
}
