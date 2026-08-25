import SwiftUI
import WidgetKit

struct SimRaStatisticsEntry: TimelineEntry {
    let date: Date
    let totalRides: Int
    let totalKilometers: Double
    let totalIncidents: Int
    let slots: [Int]
}

struct SimRaStatisticsProvider: TimelineProvider {
    typealias Entry = SimRaStatisticsEntry
    
    private var regionSuffix: String {
        let regionId = AppDelegate.shared().regions.regionId
        return regionId.isEmpty ? "" : "-\(regionId)"
    }
    
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), totalRides: 3, totalKilometers: 7.5, totalIncidents: 1, slots: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadEntry() -> Entry {
        let defaults = UserDefaults.standard
        
        let totalRidesKey = "totalRides" + regionSuffix
        let totalLengthKey = "totalLength" + regionSuffix
        let totalIncidentsKey = "totalIncidents" + regionSuffix
        let totalSlotsKey = "totalSlots" + regionSuffix
        
        let totalRides = defaults.integer(forKey: totalRidesKey)
        let totalLengthMeters = defaults.integer(forKey: totalLengthKey)
        let totalKilometers = Double(totalLengthMeters) / 1000.0
        let totalIncidents = defaults.integer(forKey: totalIncidentsKey)
        let slots = defaults.array(forKey: totalSlotsKey) as? [Int] ?? []
        
        return Entry(date: Date(), totalRides: totalRides, totalKilometers: totalKilometers, totalIncidents: totalIncidents, slots: slots)
    }
}

struct SimRaStatisticsWidgetEntryView: View {
    var entry: SimRaStatisticsProvider.Entry
    @Environment(\.widgetFamily) var family
    
    private let maxBarHeight: CGFloat = 60
    
    private var maxValueForBars: Double {
        max(Double(entry.totalRides), entry.totalKilometers, 1)
    }
    
    private func barHeight(for value: Double) -> CGFloat {
        guard maxValueForBars > 0 else { return 0 }
        return CGFloat(value / maxValueForBars) * maxBarHeight
    }
    
    var body: some View {
        switch family {
        case .systemSmall:
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "bicycle")
                        .widgetAccentable()
                        .symbolRenderingMode(.hierarchical)
                    Text("SimRa")
                        .font(.footnote.weight(.semibold))
                        .widgetAccentable()
                }
                HStack(alignment: .bottom, spacing: 20) {
                    VStack {
                        Text("\(entry.totalRides)")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .widgetAccentedRenderingMode(.monochrome)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.75))
                            .frame(width: 20, height: barHeight(for: Double(entry.totalRides)))
                            .animation(.easeInOut, value: entry.totalRides)
                        Text("Fahrten")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    VStack {
                        Text(String(format: "%.1f", entry.totalKilometers))
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .widgetAccentedRenderingMode(.monochrome)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.4))
                            .frame(width: 20, height: barHeight(for: entry.totalKilometers))
                            .animation(.easeInOut, value: entry.totalKilometers)
                        Text("km")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.yellow, .orange)
                    Text("\(entry.totalIncidents)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .containerBackground(for: .widget) {
                Color.teal.opacity(0.08)
            }
        case .systemMedium:
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bicycle")
                            .widgetAccentable()
                            .symbolRenderingMode(.hierarchical)
                        Text("SimRa")
                            .font(.title3.weight(.semibold))
                            .widgetAccentable()
                    }
                    Spacer()
                    HStack(alignment: .bottom, spacing: 48) {
                        VStack {
                            Text("\(entry.totalRides)")
                                .font(.system(.title2, design: .monospaced).weight(.semibold))
                                .widgetAccentedRenderingMode(.monochrome)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.75))
                                .frame(width: 30, height: barHeight(for: Double(entry.totalRides)))
                                .animation(.easeInOut, value: entry.totalRides)
                            Text("Fahrten")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text(String(format: "%.1f", entry.totalKilometers))
                                .font(.system(.title2, design: .monospaced).weight(.semibold))
                                .widgetAccentedRenderingMode(.monochrome)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(width: 30, height: barHeight(for: entry.totalKilometers))
                                .animation(.easeInOut, value: entry.totalKilometers)
                            Text("km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 14) {
                    VStack {
                        Text("\(entry.totalRides)")
                            .font(.headline.monospacedDigit())
                        Text("Fahrten gesamt")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    VStack {
                        Text(String(format: "%.1f", entry.totalKilometers))
                            .font(.headline.monospacedDigit())
                        Text("km gesamt")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    VStack {
                        Text("\(entry.totalIncidents)")
                            .font(.headline.monospacedDigit())
                        Text("Incidents")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .containerBackground(for: .widget) {
                Color.teal.opacity(0.08)
            }
        default:
            // Fallback for other sizes: show small version
            Text("Unsupported widget size")
        }
    }
}

@main
struct SimRaStatisticsWidget: Widget {
    let kind = "SimRaStatisticsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimRaStatisticsProvider()) { entry in
            SimRaStatisticsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SimRa Statistik")
        .description("Deine Fahrten auf einen Blick.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SimRaStatisticsWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SimRaStatisticsWidgetEntryView(entry: SimRaStatisticsEntry(date: Date(), totalRides: 4, totalKilometers: 12.5, totalIncidents: 2, slots: []))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            SimRaStatisticsWidgetEntryView(entry: SimRaStatisticsEntry(date: Date(), totalRides: 35, totalKilometers: 132.7, totalIncidents: 7, slots: []))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
