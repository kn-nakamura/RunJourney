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
            case .results: return "Results Only"
            case .races: return "Races & Results"
            case .plans: return "Pace Plans Only"
            case .everything: return "Everything"
            }
        }
        var summary: String {
            switch self {
            case .results: return "Deletes all registered results (times, routes). Race entries are kept."
            case .races: return "Deletes race entries and all linked results."
            case .plans: return "Deletes all saved pace plans."
            case .everything: return "Deletes everything (races, results, pace plans). Cannot be undone."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .appText(.displayLg)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color.bgPrimary)
            Form {
                statsSection
                dataSection
                iCloudSection
                aboutSection
            }
        }
        .background(Color.bgPrimary)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .alert("Delete \(deleteScope.displayName)?", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text(deleteScope.summary)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        Section("Library") {
            statRow(symbol: "flag.checkered", label: "Races", count: races.count, color: .accentPrimary)
            statRow(symbol: "figure.run", label: "Results", count: results.count, color: .cat10K)
            statRow(symbol: "bookmark.fill", label: "Pace Plans", count: plans.count, color: .catHalfMarathon)
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
                .appText(.codeBaseBold)
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
                        Text("Delete \(scope.displayName)")
                    }
                }
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("If iCloud sync is enabled, deletions also propagate to all linked devices.")
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
                    Text("iCloud Sync")
                        .appText(.bodySm)
                    Text("Local storage only in MVP")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("OFF")
                    .appText(.codeXs)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.bgTertiary, in: Capsule())
            }
        } header: {
            Text("Sync")
        } footer: {
            Text("Once Apple Developer Program is enabled, switch ModelConfiguration to cloudKitDatabase: .private to share records across iPhone / iPad / Mac.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)
            Link(destination: URL(string: "https://github.com/kn-nakamura/run-journey-ios")!) {
                Label("GitHub Repository", systemImage: "link")
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
