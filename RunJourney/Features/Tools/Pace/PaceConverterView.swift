import SwiftUI

/// TOOLS · Pace モードのシェル。3 つのサブモード:
/// - Pace/Speed: distance + time → pace + speed
/// - Time:       pace + distance → time
/// - Distance:   pace + time → distance
struct PaceConverterView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case paceSpeed
        case time
        case distance

        var id: String { rawValue }
        var label: String {
            switch self {
            case .paceSpeed: return "Pace / Speed"
            case .time: return "Time"
            case .distance: return "Distance"
            }
        }
    }

    @State private var mode: Mode = .paceSpeed

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .paceSpeed:
                PaceFromDistanceTimeView()
            case .time:
                TimeFromPaceDistanceView()
            case .distance:
                DistanceFromPaceTimeView()
            }
        }
    }
}
