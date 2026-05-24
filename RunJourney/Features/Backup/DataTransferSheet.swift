import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataTransferSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var races: [Race]
    @Query private var results: [RaceResult]
    @Query private var plans: [PacePlan]

    @State private var isExporting = false
    @State private var exportDocument: BackupFileDocument?
    @State private var isImporting = false
    @State private var importSummary: BackupImportSummary?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Data Transfer")

                exportCard
                importCard

                Text("Logos and photo attachments are not included in the backup file.")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onChange(of: exportDocument) { _, doc in
            if doc != nil { isExporting = true }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            exportDocument = nil
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Complete", isPresented: Binding(
            get: { importSummary != nil },
            set: { if !$0 { importSummary = nil } }
        )) {
            Button("OK") { importSummary = nil }
        } message: {
            if let s = importSummary {
                let msg = "Added \(s.racesAdded) races, \(s.resultsAdded) results, \(s.plansAdded) plans."
                let skip = s.totalSkipped > 0 ? " Skipped \(s.totalSkipped) duplicates." : ""
                let warn = s.errors.isEmpty ? "" : " \(s.errors.count) field(s) used defaults due to parse errors."
                Text(msg + skip + warn)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Cards

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.selection()
                prepareExport()
            } label: {
                HStack(spacing: 12) {
                    Group {
                        if isProcessing {
                            ProgressView().tint(.secondary)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Backup")
                            .appText(.bodyBase)
                            .foregroundStyle(Color.textPrimary)
                        Text("\(races.count) races · \(results.count) results · \(plans.count) plans")
                            .appText(.bodyXs)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.selection()
                isImporting = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from File")
                            .appText(.bodyBase)
                            .foregroundStyle(Color.textPrimary)
                        Text("Supports RunJourney backup and Supabase JSON export")
                            .appText(.bodyXs)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "RunJourney-Backup-\(formatter.string(from: .now)).json"
    }

    private func prepareExport() {
        guard !isProcessing else { return }
        isProcessing = true
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                let data = try BackupExporter.makeBackupData(races: races, plans: plans)
                exportDocument = BackupFileDocument(data: data)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleImport(result: Result<URL, any Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = BackupImportError.fileAccessDenied.errorDescription
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let summary = try BackupImporter.importData(
                    from: data,
                    into: modelContext,
                    existingRaces: races,
                    existingResults: results,
                    existingPlans: plans
                )
                importSummary = summary
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
