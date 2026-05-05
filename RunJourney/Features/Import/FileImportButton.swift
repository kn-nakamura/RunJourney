import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// ツールバーに置く「ファイル取り込み」ボタン。
/// `.fileImporter` で TCX/GPX/FIT/ZIP を選択 → パース → 確認シートで保存先（新規大会 / 既存大会）を選択 → 保存。
///
/// `attachTo` をセットすると確認シートをスキップして、直接そのレースに RaceResult を追加する。
/// RaceDetailView の Results セクションヘッダの「+」ボタン用途。
struct FileImportButton: View {
    @Environment(\.modelContext) private var modelContext

    var attachTo: Race? = nil
    /// 指定すると、確認シートをスキップして既存 RaceResult のルートデータ
    /// (trackPoints / lapData / summary / raceDate / finishTimeSec) を新ファイルで上書きする。
    /// weather / bib / places / comment などユーザー手入力メタは保持される。
    /// 上書き前に「Replace existing route?」確認ダイアログを表示する。
    /// 複数ファイルが選ばれた場合は最初の 1 件のみが適用される。
    var replaceOn: RaceResult? = nil
    var iconName: String = "square.and.arrow.down"
    var labelText: String = "Import File"
    /// 取り込み成功時に親へ通知するクロージャ。設定されている場合、内部の "Import Complete" アラートは出さず、
    /// 親側でシートを閉じる等の処理を行う前提となる（AddResultSheet からの呼び出し用）。
    var onCompleted: (() -> Void)? = nil
    /// 外部から `.fileImporter` をトリガーするための binding。指定すると本ボタンの可視 UI は非表示扱いに
    /// なり、`true` をセットされたタイミングで `.fileImporter` が開く。FAB 等の別 UI から
    /// インポートフローを起動するための入口。
    var externalTrigger: Binding<Bool>? = nil
    /// `externalTrigger` を使う場合に本体ボタンの見た目を消すフラグ (true = 不可視)。
    var hidesButtonUI: Bool = false

    @State private var isImporterPresentedInternal = false
    @State private var isProcessing = false
    @State private var pendingImports: [PendingImport] = []
    @State private var currentIndex = 0
    @State private var importedSummary: ImportedSummary?
    @State private var errorMessage: String?
    /// `replaceOn` モード時、parse 済みの上書き候補。confirm alert で実際に書き込む前のバッファ。
    @State private var pendingReplace: PendingImport?

    /// 実体としてバインドされる「インポータ表示中」状態。外部 binding があればそれを優先。
    private var isImporterPresented: Binding<Bool> {
        externalTrigger ?? Binding(
            get: { isImporterPresentedInternal },
            set: { isImporterPresentedInternal = $0 }
        )
    }

    var body: some View {
        Group {
            if hidesButtonUI {
                // 外部トリガー専用モード。可視ボタンは出さず .fileImporter のフックだけ生やす。
                Color.clear.frame(width: 0, height: 0)
            } else {
                Button {
                    isImporterPresented.wrappedValue = true
                } label: {
                    Label(labelText, systemImage: iconName)
                }
            }
        }
        .disabled(isProcessing)
        .fileImporter(
            isPresented: isImporterPresented,
            allowedContentTypes: Self.allowedTypes,
            allowsMultipleSelection: replaceOn == nil
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
        .alert("Replace existing route?", isPresented: Binding(
            get: { pendingReplace != nil },
            set: { if !$0 { pendingReplace = nil } }
        ), presenting: pendingReplace) { pending in
            Button("Replace", role: .destructive) {
                applyReplace(pending: pending)
            }
            Button("Cancel", role: .cancel) {
                pendingReplace = nil
            }
        } message: { _ in
            Text("This will overwrite the route, laps, finish time, and start date with the imported file. Weather, bib, places, and comments will be preserved.")
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

        // replaceOn が指定されているときは「上書き確認」alert を出して、その応答後に書き込む。
        // 複数ファイルが選ばれても最初の 1 件のみが対象。
        if replaceOn != nil {
            pendingReplace = items.first
            return
        }

        // attachTo が指定されているときは確認シートをスキップして即追加。
        if let race = attachTo {
            for item in items {
                _ = ActivityImporter.appendResult(item.activity, to: race, context: modelContext)
            }
            if let onCompleted {
                onCompleted()
            } else {
                importedSummary = ImportedSummary(message: "Imported \(items.count) activity / activities")
            }
            return
        }

        pendingImports = items
        currentIndex = 0
        // sheet は currentPendingBinding 経由で自動表示される
    }

    /// Replace alert で「Replace」が押されたときの実書き込み。
    private func applyReplace(pending: PendingImport) {
        guard let target = replaceOn else {
            pendingReplace = nil
            return
        }
        _ = ActivityImporter.replaceTrackData(
            pending.activity,
            on: target,
            context: modelContext
        )
        pendingReplace = nil
        if let onCompleted {
            onCompleted()
        } else {
            importedSummary = ImportedSummary(message: "Activity file replaced.")
        }
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
