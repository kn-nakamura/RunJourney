import SwiftUI
import SwiftData

/// `RaceResult` を編集するフォーム。Time / Weather / Places / Comment / PB-SB Flags。
/// ヒーロータイム + 統計グリッドの「読み取り専用ビュー」は `RaceResultDetailView` 側で担当。
struct RaceResultEditView: View {
    @Bindable var result: RaceResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            timeSection
            WeatherSection(result: result)
            placesSection
            commentSection
            flagsSection
            PlanPickerRow(result: result)
            replaceFitSection
            AttachmentSection(owner: result)
            PhotoLinkSection(owner: result)
        }
        .navigationTitle("Edit Result")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
#endif
        .keyboardCloseToolbar()
        .dismissKeyboardOnBackgroundTap()
    }

    // MARK: - Time

    private var timeSection: some View {
        Section {
            DatePicker("Start time", selection: $result.raceDate)

            HStack {
                Text("Finish time")
                Spacer()
                TextField(
                    "seconds",
                    value: $result.finishTimeSec,
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 140)
                Text("sec")
                    .appText(.codeXs)
                    .foregroundStyle(.secondary)
            }
            if let sec = result.finishTimeSec, sec > 0 {
                Text(formatDuration(sec))
                    .appText(.codeMd)
                    .foregroundStyle(Color.accentPrimary)
            }
        } header: {
            SectionHeader(title: "Time")
        }
    }

    // MARK: - Places

    private var placesSection: some View {
        Section {
            TextField("Bib number", text: $result.bibNumber.bound)
                .keyboardType(.numbersAndPunctuation)
            HStack {
                Text("Overall place")
                Spacer()
                TextField("—", value: $result.overallPlace, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 100)
            }
            HStack {
                Text("Total finishers")
                Spacer()
                TextField("—", value: $result.totalFinishers, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 100)
            }
            HStack {
                Text("Age group place")
                Spacer()
                TextField("—", value: $result.ageGroupPlace, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 100)
            }
        } header: {
            SectionHeader(title: "Places")
        }
    }

    // MARK: - Comment

    private var commentSection: some View {
        Section {
            TextEditor(text: $result.comment.bound)
                .frame(minHeight: 96)
        } header: {
            SectionHeader(title: "Comment")
        }
    }

    // MARK: - Activity File (replace FIT/GPX/TCX)

    /// 既存 result のルートデータ (trackPoints / lapData / summary / raceDate / finishTimeSec)
    /// を新しいファイルで上書きする。weather / bib / places / comment は保持される。
    /// FileImportButton 側で「Replace existing route?」確認 alert を出す。
    private var replaceFitSection: some View {
        Section {
            FileImportButton(
                replaceOn: result,
                iconName: "arrow.triangle.2.circlepath",
                labelText: "Replace activity file (.fit / .gpx / .tcx / .zip)"
            )
            .foregroundStyle(Color.accentPrimary)
        } header: {
            SectionHeader(title: "Activity File")
        } footer: {
            Text("Imports a new file and overwrites the route, laps, finish time, and start date. Weather, bib, places, and comments are preserved.")
        }
    }

    // MARK: - Flags

    private var flagsSection: some View {
        Section {
            Toggle("PB", isOn: $result.isPB)
            Toggle("SB", isOn: $result.isSB)
            Toggle("DNF", isOn: $result.isDNF)
            Toggle("DNS", isOn: $result.isDNS)
        } header: {
            SectionHeader(title: "Flags")
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}
