import SwiftUI

/// Cheer Point モードのシェル。2 つのサブモード:
/// - From Goal Time: ゴール予想タイムから応援地点の通過予想時刻を計算
/// - From Recent Pass: 直近の通過時刻から応援地点の通過予想時刻を計算 (現場での再計算用途)
struct CheerPointView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case fromGoalTime
        case fromRecentPass

        var id: String { rawValue }
        var label: String {
            switch self {
            case .fromGoalTime: return "From Goal Time"
            case .fromRecentPass: return "From Recent Pass"
            }
        }
    }

    @State private var mode: Mode = .fromGoalTime

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Cheer Mode", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .fromGoalTime:
                CheerFromGoalTimeView()
            case .fromRecentPass:
                CheerFromRecentPassView()
            }
        }
    }
}
