import SwiftUI
import WidgetKit

private enum VerseStore {
    static let group = "group.com.FernandoSac.gymTracker"
    static let kind = "StkVerseLockWidget"

    static func read() -> VerseEntry {
        let defaults = UserDefaults(suiteName: group)
        let enabled = defaults?.bool(forKey: "stkVerseWidgetEnabled") ?? false
        let text = enabled ? (defaults?.string(forKey: "stkVerseText") ?? "") : ""
        let reference = enabled ? (defaults?.string(forKey: "stkVerseReference") ?? "") : ""
        return VerseEntry(
            date: .now,
            text: text.isEmpty ? "Abre STK Haven para ver tu versículo." : text,
            reference: reference.isEmpty ? "Reflexión diaria" : reference
        )
    }
}

private struct VerseEntry: TimelineEntry {
    let date: Date
    let text: String
    let reference: String
}

private struct VerseTimeline: TimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: .now, text: "Tu versículo de cada día", reference: "STK Haven")
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(VerseStore.read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        // Reading native shared storage is inexpensive; timeline reload is
        // requested explicitly when Flutter selects a new verse.
        let entry = VerseStore.read()
        let nextDay = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(24 * 3600)
        completion(Timeline(entries: [entry], policy: .after(nextDay)))
    }
}

private struct VerseView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    @ViewBuilder var body: some View {
        if #available(iOS 17.0, *) {
            widgetContent.containerBackground(for: .widget) {
                Color(red: 0.07, green: 0.11, blue: 0.17)
            }
        } else {
            widgetContent
        }
    }

    @ViewBuilder private var widgetContent: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("\(entry.reference): \(entry.text)")
                    .lineLimit(1)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.text)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(entry.reference)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                VStack(alignment: .leading, spacing: 10) {
                    Label("STK Haven", systemImage: "book.closed")
                        .font(.caption.weight(.bold))
                    Text(entry.text)
                        .font(.body.weight(.medium))
                        .lineLimit(5)
                    Spacer(minLength: 0)
                    Text(entry.reference)
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(14)
            }
        }

    }
}

@main
struct StkVerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: VerseStore.kind, provider: VerseTimeline()) { entry in
            VerseView(entry: entry)
        }
        .configurationDisplayName("Versículo STK Haven")
        .description("Tu versículo de reflexión, también en la pantalla de bloqueo.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall])
    }
}
