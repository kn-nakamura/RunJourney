import SwiftUI
import SwiftData
import CoreLocation

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

    // Weather
    @State private var weatherTempC: Double?
    @State private var weatherDescription: WeatherDescription?
    @State private var weatherCondition: Condition?
    @State private var weatherCode: Int?
    @State private var isFetchingWeather = false
    @State private var weatherFetchInfo: String?
    @State private var weatherFetchError: String?

    var body: some View {
        NavigationStack {
            Form {
                importSection
                timeSection
                placesSection
                weatherSection
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

    private var weatherSection: some View {
        Section {
            HStack {
                Button {
                    Task { await fetchWeather() }
                } label: {
                    Label(isFetchingWeather ? "Fetching…" : "Fetch from race location", systemImage: "cloud.sun")
                        .appText(.bodySmBold)
                }
                .disabled(isFetchingWeather)
                Spacer()
                if isFetchingWeather {
                    ProgressView().controlSize(.small)
                }
            }
            if let info = weatherFetchInfo {
                Text(info)
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
            if let err = weatherFetchError {
                Text(err)
                    .appText(.bodyXs)
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Temp")
                Spacer()
                TextField("°C", value: $weatherTempC, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 100)
                Text("°C")
                    .appText(.codeXs)
                    .foregroundStyle(.secondary)
            }
            Picker("Sky", selection: $weatherDescription) {
                Text("—").tag(WeatherDescription?.none)
                ForEach(WeatherDescription.allCases) { d in
                    Label(d.displayName, systemImage: d.symbolName).tag(WeatherDescription?.some(d))
                }
            }
            Picker("Condition", selection: $weatherCondition) {
                Text("—").tag(Condition?.none)
                ForEach(Condition.allCases) { c in
                    Text(c.displayName).tag(Condition?.some(c))
                }
            }
        } header: {
            SectionHeader(title: "Weather (Optional)")
        } footer: {
            Text("Tap fetch to auto-fill the temperature and sky for the race date and start location, or enter values manually.")
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
        result.weatherTempC = weatherTempC
        result.weatherDescription = weatherDescription
        result.weatherCode = weatherCode
        result.condition = weatherCondition

        modelContext.insert(result)
        if race.results?.contains(result) == false {
            race.results?.append(result)
        }
        try? modelContext.save()
        dismiss()
    }

    /// レース座標 + raceDate を使って 0〜23 時の天気を取得し、raceDate にもっとも近い時刻を採用する。
    /// `WeatherSection` のスライダー UI までは出さず、シンプルにオートフィルする。
    @MainActor
    private func fetchWeather() async {
        isFetchingWeather = true
        weatherFetchError = nil
        weatherFetchInfo = nil
        defer { isFetchingWeather = false }

        do {
            let coord = CLLocationCoordinate2D(latitude: race.lat, longitude: race.lng)
            let response = try await WeatherFetcher.fetchHourly(at: coord, on: raceDate)
            guard !response.hours.isEmpty else {
                weatherFetchError = "No weather data for this date / location."
                return
            }
            let nearest = response.hours.min(by: {
                abs($0.hour.timeIntervalSince(raceDate)) < abs($1.hour.timeIntervalSince(raceDate))
            })!
            weatherTempC = nearest.tempC
            weatherDescription = nearest.description
            weatherCode = nearest.code
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "HH:mm"
            weatherFetchInfo = "Filled \(f.string(from: nearest.hour)) sample (\(response.source.rawValue))"
        } catch {
            weatherFetchError = error.localizedDescription
        }
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
