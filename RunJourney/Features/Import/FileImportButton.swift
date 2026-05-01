import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// ツールバーに置く「ファイル取り込み」ボタン。
/// `.fileImporter` で TCX/GPX を選択 → パース → SwiftData に Race+Result として保存。
struct FileImportButton: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isImporterPresented = false
    @State private var isProcessing = false
    @State private var importedSummary: ImportedSummary?
    @State private var errorMessage: String?

    var body: some View {
        Button {
            isImporterPresented = true
        } label: {
            Label("ファイル取り込み", systemImage: "square.and.arrow.down")
        }
        .disabled(isProcessing)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await importFiles(urls: urls) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("取り込み完了", isPresented: Binding(
            get: { importedSummary != nil },
            set: { if !$0 { importedSummary = nil } }
        ), presenting: importedSummary) { _ in
            Button("OK") { importedSummary = nil }
        } message: { summary in
            Text(summary.message)
        }
        .alert("取り込みエラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        ), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    /// 対応するファイルタイプ。
    /// - .gpx / .tcx → XML
    /// - .fit → 任意バイナリ（`UTType(filenameExtension:)` で生成）
    /// - .zip → アーカイブ
    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.xml, .zip]
        if let gpx = UTType(filenameExtension: "gpx") { types.append(gpx) }
        if let tcx = UTType(filenameExtension: "tcx") { types.append(tcx) }
        if let fit = UTType(filenameExtension: "fit") { types.append(fit) }
        // フォールバック: 任意の data
        types.append(.data)
        return types
    }

    private func importFiles(urls: [URL]) async {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }

        var successCount = 0
        var failures: [(name: String, reason: String)] = []

        for url in urls {
            do {
                let activity = try ActivityImporter.parse(url: url)
                await MainActor.run {
                    // 戻り値は @Model（非Sendable）なので _ = で破棄してクロージャを Void にする
                    _ = ActivityImporter.saveAsNewRace(
                        activity,
                        context: modelContext,
                        fileName: url.lastPathComponent
                    )
                }
                successCount += 1
            } catch let importError as ImportError {
                failures.append((url.lastPathComponent, importError.errorDescription ?? "不明なエラー"))
            } catch {
                failures.append((url.lastPathComponent, error.localizedDescription))
            }
        }

        await MainActor.run {
            if successCount > 0 {
                let suffix: String
                if failures.isEmpty {
                    suffix = ""
                } else {
                    suffix = "\n\n失敗:\n" + failures.map { "・\($0.name): \($0.reason)" }.joined(separator: "\n")
                }
                importedSummary = ImportedSummary(
                    message: "\(successCount) 件のアクティビティを取り込みました\(suffix)"
                )
            } else if let first = failures.first {
                errorMessage = "\(first.name): \(first.reason)"
            }
        }
    }
}

struct ImportedSummary: Identifiable {
    let id = UUID()
    let message: String
}
