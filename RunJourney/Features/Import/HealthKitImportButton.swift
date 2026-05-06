#if canImport(HealthKit)
import SwiftUI
import SwiftData
import HealthKit

/// `FileImportButton` の HealthKit 版。タップで `HealthKitWorkoutPickerSheet` を開き、
/// 選んだ HKWorkout を `ParsedActivity` に変換 → 既存の `ActivityImporter` フローへ流す。
///
/// v1 では `attachTo` (= 既存 Race に結果を追加) のみサポートする。
/// 「新規 Race を作る」「既存 Result を上書きする」フローは将来対応。
struct HealthKitImportButton: View {
    @Environment(\.modelContext) private var modelContext

    /// セットされていれば、選択した workout をこの Race の RaceResult として直接追加する。
    let attachTo: Race
    var iconName: String = "heart.text.square"
    var labelText: String = "Import from Apple Health"
    /// 取り込み成功時に親へ通知。設定されていない場合は内部の "Import Complete" alert を出す。
    var onCompleted: (() -> Void)? = nil

    @State private var showPicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Label(labelText, systemImage: iconName)
        }
        .disabled(isProcessing || !HealthKitWorkoutFetcher.isAvailable)
        .sheet(isPresented: $showPicker) {
            HealthKitWorkoutPickerSheet { workout in
                Task { await ingest(workout) }
            }
        }
        .alert("Import Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        ), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
        .alert("Import Complete", isPresented: Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        ), presenting: successMessage) { _ in
            Button("OK") { successMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    @MainActor
    private func ingest(_ workout: HKWorkout) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let activity = try await HealthKitWorkoutFetcher.parsedActivity(from: workout)
            _ = ActivityImporter.appendResult(activity, to: attachTo, context: modelContext)
            if let onCompleted {
                onCompleted()
            } else {
                successMessage = "Imported workout from Apple Health."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// HealthKit が無いプラットフォーム向けスタブ（macOS の旧バージョンなど）。
#else
import SwiftUI

struct HealthKitImportButton: View {
    let attachTo: Race
    var iconName: String = "heart.text.square"
    var labelText: String = "Import from Apple Health"
    var onCompleted: (() -> Void)? = nil

    var body: some View {
        EmptyView()
    }
}
#endif
