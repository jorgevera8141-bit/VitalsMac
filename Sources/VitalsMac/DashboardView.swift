import SensorKit
import SwiftUI

enum DashboardPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case sensors = "Sensors"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .sensors: return "thermometer.medium"
        }
    }
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var page: DashboardPage? = .overview

    var body: some View {
        NavigationSplitView {
            List(DashboardPage.allCases, selection: $page) { item in
                Label(item.rawValue, systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            switch page ?? .overview {
            case .overview: OverviewPage(model: model)
            case .sensors: SensorsPage(model: model)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
    }
}

/// Every reading, grouped, including the temperature sensors tucked away in the menu.
struct SensorsPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List {
            ForEach(SensorGroup.allCases, id: \.self) { group in
                let rows = model.readings.filter { $0.group == group }
                if !rows.isEmpty {
                    Section(group.rawValue) {
                        ForEach(rows) { reading in
                            LabeledContent(reading.label) {
                                Text(reading.value).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sensors")
    }
}
