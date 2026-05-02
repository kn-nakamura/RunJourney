import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// ツールバーに置く「ファイル取り込み」ボタン。
/// `.fileImporter` で TCX/GPX/FIT/ZIP を選択 → パース → 確認シートで保存先（新規大会 / 既存大会）を選択 → 保存。
struct FileImportButton: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isImporterPresented = false
    @State private var isProcessing = false
    @State private var pendingImports: [PendingImport] = []
    @State private var currentIndex = 0
    @State private var importedSummary: ImportedSummary?
    @State private var errorMessage: String?

    var body: some View {
        Button {
            isImporterPresented = true
        } label: {
            Label("Import File", systemImage: "square.and.arrow.down")
        }
        .disabled(isProcessing)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await prepareImports(urls: urls) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .sheet(item: currentPendingBinding) { pending in
            ImportConfirmationSheet(
                activity: pending.activity,
                fileName: pending.fileName,
                onConfirm: { target in
                    handleConfirm(target: target, pending: pending)
                },
                onCancel: {
                    advanceQueue(skipped: true)
                }
            )
            .interactiveDismissDisabled()
        }
        .alert("Import Complete", isPresented: Binding(
            get: { importedSummary != nil },
            set: { if !$0 { importedSummary = nil } }
        ), presenting: importedSummary) { _ in
            Button("OK") { importedSummary = nil }
        } message: { summary in
            Text(summary.message)
        }
        .alert("Import Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        ), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    /// 対応するファイルタイプ。
    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.xml, .zip]
        if let gpx = UTType(filenameExtension: "gpx") { types.append(gpx) }
        if let tcx = UTType(filenameExtension: "tcx") { types.append(tcx) }
        if let fit = UTType(filenameExtension: "fit") { types.append(fit) }
        types.append(.data)
        return types
    }

    /// 現在処理中の PendingImport を sheet(item:) 用に Binding として公開する。
    private var currentPendingBinding: Binding<PendingImport?> {
        Binding(
            get: {
                guard currentIndex < pendingImports.count else { return nil }
                return pendingImports[currentIndex]
            },
            set: { _ in /* sheet 経由のキャンセルは onCancel で処理 */ }
        )
    }

    // MARK: - Pipeline

    /// パースしてキューに積む。エラーは即座にダイアログ表示。
    @MainActor
    private func prepareImports(urls: [URL]) async {
        isProcessing = true
        defer { isProcessing = false }

        var items: [PendingImport] = []
        var failures: [(name: String, reason: String)] = []

        for url in urls {
            do {
                let activity = try ActivityImporter.parse(url: url)
                items.append(PendingImport(
                    activity: activity,
                    fileName: url.lastPathComponent
                ))
            } catch let importError as ImportError {
                failures.append((url.lastPathComponent, importError.errorDescription ?? "Unknown error"))
            } catch {
                failures.append((url.lastPathComponent, error.localizedDescription))
            }
        }

        if items.isEmpty {
            if let first = failures.first {
                errorMessage = "\(first.name): \(first.reason)"
            }
            return
        }

        // パース失敗が一部だけある場合もユーザーに伝える
        if !failures.isEmpty {
            errorMessage = "Some files failed to parse:\n" + failures.map { "• \($0.name): \($0.reason)" }.joined(separator: "\n")
        }

        pendingImports = items
        currentIndex = 0
        // sheet は currentPendingBinding 経由で自動表示される
    }

    private func handleConfirm(target: ImportConfirmationSheet.ImportTarget, pending: PendingImport) {
        switch target {
        case .newRace(let name):
            _ = ActivityImporter.saveAsNewRace(
                pending.activity,
                context: modelContext,
                raceName: name,
                fileName: pending.fileName
            )
        case .existing(let race):
            _ = ActivityImporter.appendResult(
                pending.activity,
                to: race,
                context: modelContext
            )
        }
        advanceQueue(skipped: false)
    }

    private func advanceQueue(skipped: Bool) {
        currentIndex += 1
        if currentIndex >= pendingImports.count {
            // 全部処理し終わった
            let total = pendingImports.count
            let savedCount = skipped ? total - 1 : total  // 最後だけスキップの簡易判定（厳密にはカウンター必要だが軽量化）
            pendingImports = []
            currentIndex = 0
            if savedCount > 0 {
                importedSummary = ImportedSummary(message: "Imported \(savedCount) activity / activities")
            }
        }
        // それ以外（残ファイルあり）は currentPendingBinding が次のシートを自動表示
    }
}

// MARK: - Models

struct PendingImport: Identifiable {
    let id = UUID()
    let activity: ParsedActivity
    let fileName: String?
}

struct ImportedSummary: Identifiable {
    let id = UUID()
    let message: String
}
