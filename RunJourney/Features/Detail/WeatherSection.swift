import SwiftUI
import SwiftData
import CoreLocation

/// `RaceResult` の天気フィールドを編集するセクション。
///
/// フロー:
/// 1. 「Fetch hourly」を押すと、レース当日 0〜23時の天気を取得 (WeatherKit → Open-Meteo)。
/// 2. スライダーが `result.raceDate` の時刻にデフォルトでセットされる。
/// 3. ユーザーがスライダーを動かすと該当時刻の温度・天気が即時プレビュー。
/// 4. 「Apply this hour」で `result` に確定。手動入力 (TextField/Picker) も併存。
struct WeatherSection: View {
    @Bindable var result: RaceResult

    @State private var hourly: [HourlyWeather] = []
    @State private var selectedIndex: Int = 0
    @State private var isFetching = false
    @State private var source: WeatherSource?
    @State private var errorMessage: String?

    var body: some View {
        Section {
            fetchControls
            if !hourly.isEmpty {
                Divider().padding(.vertical, 4)
                hourlyPreview
                hourlySlider
                applyButton
            }

            Divider().padding(.vertical, 4)

            // 手動入力（Fetch なしでも編集可能）
            manualEditors
        } header: {
            SectionHeader(title: "Weather")
        } footer: {
            if let source {
                Text("Hourly data via \(source.rawValue)")
                    .appText(.bodyXs)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var fetchControls: some View {
        HStack {
            Button {
                Task { await fetch() }
            } label: {
                Label(isFetching ? "Fetching…" : "Fetch hourly weather", systemImage: "cloud.sun")
                    .appText(.bodySmBold)
            }
            .disabled(isFetching || result.race == nil)
            Spacer()
            if isFetching {
                ProgressView().controlSize(.small)
            }
        }
        if let errorMessage {
            Text(errorMessage)
                .appText(.bodyXs)
                .foregroundStyle(.red)
        }
        if result.race == nil {
            Text("Attach this result to a race first.")
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var hourlyPreview: some View {
        let sample = hourly[max(0, min(selectedIndex, hourly.count - 1))]
        HStack(spacing: 16) {
            Image(systemName: sample.description.symbolName)
                .font(.system(size: 28))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(sample.hour, format: .dateTime.hour().minute())
                    .appText(.codeMd)
                    .foregroundStyle(Color.textPrimary)
                Text(sample.description.displayName)
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f°C", sample.tempC))
                    .appText(.codeLg)
                    .foregroundStyle(Color.textPrimary)
                Text("WMO \(sample.code)")
                    .appText(.codeXs)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var hourlySlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Slider(
                value: Binding(
                    get: { Double(selectedIndex) },
                    set: { selectedIndex = Int($0.rounded()) }
                ),
                in: 0...Double(max(0, hourly.count - 1)),
                step: 1
            )
            HStack {
                Text("00:00").appText(.codeXs)
                Spacer()
                Text("12:00").appText(.codeXs)
                Spacer()
                Text("23:00").appText(.codeXs)
            }
            .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var applyButton: some View {
        Button {
            applySelectedHour()
        } label: {
            Label("Apply this hour", systemImage: "checkmark.circle.fill")
                .appText(.bodySmBold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.accentPrimary)
        .foregroundStyle(.black)
    }

    @ViewBuilder
    private var manualEditors: some View {
        HStack {
            Text("Temp")
            Spacer()
            TextField("°C", value: $result.weatherTempC, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 100)
            Text("°C")
                .appText(.codeXs)
                .foregroundStyle(.secondary)
        }
        Picker("Sky", selection: bindingForDescription) {
            Text("—").tag(WeatherDescription?.none)
            ForEach(WeatherDescription.allCases) { d in
                Label(d.displayName, systemImage: d.symbolName).tag(WeatherDescription?.some(d))
            }
        }
        Picker("Condition", selection: bindingForCondition) {
            Text("—").tag(Condition?.none)
            ForEach(Condition.allCases) { c in
                Text(c.displayName).tag(Condition?.some(c))
            }
        }
    }

    private var bindingForDescription: Binding<WeatherDescription?> {
        Binding(
            get: { result.weatherDescription },
            set: { result.weatherDescription = $0 }
        )
    }

    private var bindingForCondition: Binding<Condition?> {
        Binding(
            get: { result.condition },
            set: { result.condition = $0 }
        )
    }

    // MARK: - Actions

    private func fetch() async {
        guard let race = result.race else { return }
        isFetching = true
        errorMessage = nil
        defer { isFetching = false }

        do {
            let coord = CLLocationCoordinate2D(latitude: race.lat, longitude: race.lng)
            let response = try await WeatherFetcher.fetchHourly(at: coord, on: result.raceDate)
            hourly = response.hours
            source = response.source
            selectedIndex = nearestHourIndex(in: response.hours, target: result.raceDate)
        } catch {
            errorMessage = error.localizedDescription
            hourly = []
            source = nil
        }
    }

    private func nearestHourIndex(in hours: [HourlyWeather], target: Date) -> Int {
        guard !hours.isEmpty else { return 0 }
        var best = 0
        var bestDiff: TimeInterval = .greatestFiniteMagnitude
        for (i, h) in hours.enumerated() {
            let diff = abs(h.hour.timeIntervalSince(target))
            if diff < bestDiff {
                best = i
                bestDiff = diff
            }
        }
        return best
    }

    private func applySelectedHour() {
        guard !hourly.isEmpty else { return }
        let sample = hourly[max(0, min(selectedIndex, hourly.count - 1))]
        result.weatherTempC = sample.tempC
        result.weatherDescription = sample.description
        result.weatherCode = sample.code
    }
}
