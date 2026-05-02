import SwiftUI
import SwiftData

/// アプリ設定・データ管理画面。
/// Dashboard / Pace と同じ ScrollView + VStack 構造で、L2 中タイトルに `SectionHeader`
/// (Bebas Neue 24pt) を使う。Form ではなく独自レイアウトなので、行は角丸ダーク背景の
/// カード (`Color.bgSecondary` + RoundedRectangle 12pt) でくるむ。
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .appText(.displayLg)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                librarySection
                dataSection
                iCloudSection
                aboutSection
            }
            .padding()
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

    // MARK: - Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Library")
            VStack(spacing: 0) {
                statRow(symbol: "flag.checkered", label: "Races", count: races.count, color: .accentPrimary)
                rowDivider
                statRow(symbol: "figure.run", label: "Results", count: results.count, color: .cat10K)
                rowDivider
                statRow(symbol: "bookmark.fill", label: "Pace Plans", count: plans.count, color: .catHalfMarathon)
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statRow(symbol: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .appText(.bodyBase)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text("\(count)")
                .appText(.codeBaseBold)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Data management

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Data Management")
            VStack(spacing: 0) {
                ForEach(Array(DeleteScope.allCases.enumerated()), id: \.element) { idx, scope in
                    Button {
                        deleteScope = scope
                        showingDeleteAllAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .frame(width: 24)
                            Text("Delete \(scope.displayName)")
                                .appText(.bodyBase)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < DeleteScope.allCases.count - 1 {
                        rowDivider
                    }
                }
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            Text("If iCloud sync is enabled, deletions also propagate to all linked devices.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - iCloud

    private var iCloudSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Sync")
            HStack(spacing: 12) {
                Image(systemName: "icloud")
                    .foregroundStyle(Color.cat5K)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                        .appText(.bodyBase)
                        .foregroundStyle(Color.textPrimary)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            Text("Once Apple Developer Program is enabled, switch ModelConfiguration to cloudKitDatabase: .private to share records across iPhone / iPad / Mac.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "About")
            VStack(spacing: 0) {
                aboutRow(label: "Version", value: appVersion)
                rowDivider
                aboutRow(label: "Build", value: buildNumber)
                rowDivider
                Link(destination: URL(string: "https://github.com/kn-nakamura/run-journey-ios")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .foregroundStyle(Color.accentPrimary)
                            .frame(width: 24)
                        Text("GitHub Repository")
                            .appText(.bodyBase)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .appText(.bodyBase)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value)
                .appText(.codeSm)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

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
