import AppKit
import SwiftUI

/// Recent activity in plain words, so a failed poll can be explained without
/// opening Console.
struct LogsView: View {
    let log: AppLog

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(log.entries.reversed()) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)

                            Text(entry.message)
                                .font(.callout)
                                .foregroundStyle(colour(for: entry.level))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.exportAsText(), forType: .string)
                }
            }
        }
        .padding(16)
    }

    private func colour(for level: LogLevel) -> Color {
        switch level {
        case .debug: .secondary
        case .info: .primary
        case .warning: .orange
        case .error: .red
        }
    }
}
