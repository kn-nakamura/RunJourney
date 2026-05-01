import SwiftUI
import SwiftData

/// アプリ設定・データ管理画面。
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var races: [Race]
    @Query private var results: [RaceResult]
    @Query private var plans: [PacePlan]

    @State private var showingDeleteAllAlert = false
    @State private var deleteScope: DeleteScope = .results

    enum DeleteScope: String, CaseIterable, Identifiable {
        case results
        case races
        case plans
        case everything

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .results: return "結果のみ"
            case .races: return "大会と結果"
            case .plans: return "ペースプランのみ"
            case .everything: return "すべて"
            }
        }
        var summary: String {
            switch self {
            case .results: return "登録された結果（タイム・ルート）を全て削除します。大会マスターは残ります。"
            case .races: return "大会マスターと、それに紐付くすべての結果を削除します。"
            case .plans: return "保存したペース計算プランを全て削除します。"
            case .everything: return "全データ（大会・結果・ペースプラン）を削除します。元に戻せません。"
            }
        }
    }

    var body: some View {
        Form {
            statsSection
            dataSection
            iCloudSection
            aboutSection
        }
        .navigationTitle("設定")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .alert("\(deleteScope.displayName) を削除しますか？", isPresented: $showingDeleteAllAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) { performDelete() }
        } message: {
            Text(deleteScope.summary)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        Section("登録データ") {
            statRow(symbol: "flag.checkered", label: "大会", count: races.count, color: .accentPrimary)
            statRow(symbol: "figure.run", label: "結果", count: results.count, color: .cat10K)
            statRow(symbol: "bookmark.fill", label: "ペースプラン", count: plans.count, color: .catHalfMarathon)
        }
    }

    private func statRow(symbol: String, label: String, count: Int, color: Color) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
            Spacer()
            Text("\(count)")
                .font(.mono(15, bold: true))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data management

    private var dataSection: some View {
        Section {
            ForEach(DeleteScope.allCases) { scope in
                Button(role: .destructive) {
                    deleteScope = scope
                    showingDeleteAllAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(scope.displayName + " を削除")
                    }
                }
            }
        } header: {
            Text("データ管理")
        } footer: {
            Text("CloudKit同期がオンの場合は、すべての連携端末からも削除されます。")
        }
    }

    // MARK: - iCloud

    private var iCloudSection: some View {
        Section {
            HStack {
                Image(systemName: "icloud")
                    .foregroundStyle(Color.cat5K)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud 同期")
                        .font(.body(14))
                    Text("MVP初期はローカル保存のみ")
                        .font(.body(11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("オフ")
                    .font(.mono(11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.bgTertiary, in: Capsule())
            }
        } header: {
            Text("同期")
        } footer: {
            Text("Apple Developer Program 加入後、ModelConfiguration を cloudKitDatabase: .private に切り替えると有効化されます。複数端末（iPhone・iPad・Mac）で記録を共有可能。")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("アプリ情報") {
            LabeledContent("バージョン", value: appVersion)
            LabeledContent("ビルド", value: buildNumber)
            Link(destination: URL(string: "https://github.com/kn-nakamura/run-journey-ios")!) {
                Label("GitHubリポジトリ", systemImage: "link")
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func performDelete() {
        switch deleteScope {
        case .results:
            for r in results { modelContext.delete(r) }
        case .races:
            for r in races { modelContext.delete(r) }   // cascade で結果も消える
        case .plans:
            for p in plans { modelContext.delete(p) }
        case .everything:
            for r in results { modelContext.delete(r) }
            for r in races { modelContext.delete(r) }
            for p in plans { modelContext.delete(p) }
        }
        try? modelContext.save()
    }
}
