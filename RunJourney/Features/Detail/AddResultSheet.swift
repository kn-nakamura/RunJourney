import SwiftUI
import SwiftData

/// `RaceDetailView` の Results セクション "+" から開く、新規 RaceResult 追加シート。
/// 手動入力が基本フローで、最上部の "Import (Optional)" から FIT/GPX/TCX/ZIP を取り込んで
/// 自動で result を作ることもできる（その場合はシートを閉じて即反映）。
struct AddResultSheet: View {
    let race: Race

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Manual fields
    @State private var raceDate: Date = .now
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var isDNF: Bool = false
    @State private var isDNS: Bool = false
    @State private var bibNumber: String = ""
    @State private var overallPlace: Int?
    @State private var totalFinishers: Int?
    @State private var ageGroupPlace: Int?
    @State private var comment: String = ""

    var body: some View {
        NavigationStack {
            Form {
                importSection
                timeSection
                placesSection
                commentSection
            }
            .navigationTitle("Add Result")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .appText(.bodyBaseBold)
                }
            }
        }
    }

    // MARK: - Sections

    private var importSection: some View {
        Section {
            FileImportButton(
                attachTo: race,
                iconName: "square.and.arrow.down",
                labelText: "Import from .fit / .gpx / .tcx / .zip",
                onCompleted: { dismiss() }
            )
            .foregroundStyle(Color.accentPrimary)
        } header: {
            SectionHeader(title: "Import (Optional)")
        } footer: {
            Text("Upload a workout file to auto-fill date, finish time, laps and GPS track. Otherwise enter the result manually below.")
        }
    }

    private var timeSection: some View {
        Section {
            DatePicker(
                "Race date",
                selection: $raceDate,
                displayedComponents: [.date, .hourAndMinute]
            )

            if !isDNF && !isDNS {
                HStack {
                    Text("Finish time")
                    Spacer()
                    timeField($hours, placeholder: "h", width: 44)
                    Text(":").appText(.codeMd).foregroundStyle(.secondary)
                    timeField($minutes, placeholder: "mm", width: 44)
                    Text(":").appText(.codeMd).foregroundStyle(.secondary)
                    timeField($seconds, placeholder: "ss", width: 44)
                }
                if totalFinishSeconds > 0 {
                    Text(formatDuration(Double(totalFinishSeconds)))
                        .appText(.codeMd)
                        .foregroundStyle(Color.accentPrimary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Toggle("DNF (did not finish)", isOn: $isDNF.animation())
                .onChange(of: isDNF) { _, on in if on { isDNS = false } }
            Toggle("DNS (did not start)", isOn: $isDNS.animation())
                .onChange(of: isDNS) { _, on in if on { isDNF = false } }
        } header: {
            SectionHeader(title: "Time")
        }
    }

    @ViewBuilder
    private func timeField(_ binding: Binding<Int>, placeholder: String, width: CGFloat) -> some View {
        TextField(placeholder, value: binding, format: .number)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .font(.appFont(.codeMd))
            .frame(width: width)
    }

    private var placesSection: some View {
        Section {
            HStack {
                Text("Bib number")
                Spacer()
                TextField("—", text: $bibNumber)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .frame(maxWidth: 140)
            }
            HStack {
                Text("Overall place")
                Spacer()
                TextField("—", value: $overallPlace, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 100)
            }
            HStack {
                Text("Total finishers")
                Spacer()
                TextField("—", value: $totalFinishers, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 100)
            }
            HStack {
                Text("Age group place")
                Spacer()
                TextField("—", value: $ageGroupPlace, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 100)
            }
        } header: {
            SectionHeader(title: "Places")
        }
    }

    private var commentSection: some View {
        Section {
            TextEditor(text: $comment)
                .frame(minHeight: 96)
        } header: {
            SectionHeader(title: "Comment")
        }
    }

    // MARK: - Actions

    private var totalFinishSeconds: Int {
        max(0, hours) * 3600 + max(0, minutes) * 60 + max(0, seconds)
    }

    private func save() {
        let result = RaceResult(race: race, raceDate: raceDate)
        let total = totalFinishSeconds
        if !isDNF && !isDNS && total > 0 {
            result.finishTimeSec = Double(total)
        }
        result.isDNF = isDNF
        result.isDNS = isDNS
        let trimmedBib = bibNumber.trimmingCharacters(in: .whitespaces)
        result.bibNumber = trimmedBib.isEmpty ? nil : trimmedBib
        result.overallPlace = overallPlace
        result.totalFinishers = totalFinishers
        result.ageGroupPlace = ageGroupPlace
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        result.comment = trimmedComment.isEmpty ? nil : trimmedComment

        modelContext.insert(result)
        if race.results?.contains(result) == false {
            race.results?.append(result)
        }
        try? modelContext.save()
        dismiss()
    }

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}
