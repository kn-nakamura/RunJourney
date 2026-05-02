import SwiftUI
import SwiftData

/// アプリ設定・データ管理画面。
/// Dashboard / Pace と同じ ScrollView + VStack 構造で、L2 中タイトルに `SectionHeader`
/// (Bebas Neue 24pt) を使う。Form ではなく独自レイアウトなので、行は角丸ダーク背景の
/// カード (`Color.bgSecondary` + RoundedRectangle 12pt) でくるむ。
struct SettingsView: View {
    @Query private var races: [Race]
    @Query private var results: [RaceResult]
    @Query private var plans: [PacePlan]

    @AppStorage(StorageLocation.userDefaultsKey) private var storageRaw: String = StorageLocation.local.rawValue
    @AppStorage(StorageLocation.chosenFlagKey) private var hasChosen: Bool = false

    @State private var showDataSheet = false
    @State private var showStorageSwitchAlert = false

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
                iCloudSection
                aboutSection
                dataSection
            }
            .padding()
        }
        .background(Color.bgPrimary)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .sheet(isPresented: $showDataSheet) {
            DataManagementSheet()
                .presentationDetents([.medium, .large])
        }
        .alert("Choose storage on next launch?", isPresented: $showStorageSwitchAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Re-choose on Relaunch") {
                hasChosen = false
            }
        } message: {
            Text("Switching does not migrate existing data. Quit and reopen RunJourney to pick a new storage location.")
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
    //
    // 画面最下部に置く控えめな入口。配色は `.secondary` (グレー) で「探さないと見つからない」程度に
    // 抑え、誤タップで4スコープが見えないようにする。タップで `DataManagementSheet` を開き、
    // そこで初めてスコープ選択 → 個別 alert で確定。

    private var dataSection: some View {
        Button {
            showDataSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Delete data...")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Storage

    private var iCloudSection: some View {
        let location = StorageLocation(rawValue: storageRaw) ?? .local
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Storage")
            Button {
                showStorageSwitchAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: location.systemImage)
                        .foregroundStyle(Color.cat5K)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.displayName)
                            .appText(.bodyBase)
                            .foregroundStyle(Color.textPrimary)
                        Text(location.detail)
                            .appText(.bodyXs)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("Switching does not migrate existing data. Each store is independent.")
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
}
