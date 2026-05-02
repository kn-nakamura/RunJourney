import SwiftUI
import SwiftData
import MapKit

/// 大会の開催地を Apple MKLocalSearch で検索 → 選択して `Race` の住所/座標を確定する。
///
/// App Store 規約観点での選定理由:
/// - MKLocalSearch / MKLocalSearchCompleter は Apple 純正・無料・キー不要・利用制約が緩い。
/// - 一方 Nominatim (OSM) は heavy use 禁止 / 専用 User-Agent 必須など、商用配布アプリには不適。
struct LocationSearchField: View {
    @Bindable var race: Race
    @State private var completer = LocationSearchCompleter()
    @State private var resolving = false
    @State private var resolveError: String?

    var body: some View {
        @Bindable var bcompleter = completer
        return VStack(alignment: .leading, spacing: 8) {
            TextField("Search address or place", text: $bcompleter.queryFragment)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)

            if !completer.results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(completer.results.prefix(6), id: \.self) { row in
                        Button {
                            resolve(row)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(Color.accentPrimary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.title)
                                        .appText(.bodySmBold)
                                        .foregroundStyle(Color.textPrimary)
                                    if !row.subtitle.isEmpty {
                                        Text(row.subtitle)
                                            .appText(.bodyXs)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if resolving {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Resolving location…")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                }
            }

            if let resolveError {
                Text(resolveError)
                    .appText(.bodyXs)
                    .foregroundStyle(.red)
            }

            // 確定済みロケーション
            if let address = race.address, !address.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(address)
                        .appText(.bodySm)
                        .foregroundStyle(Color.textPrimary)
                    Text(String(format: "%.4f, %.4f", race.lat, race.lng))
                        .appText(.codeXs)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            } else if race.lat != 0 || race.lng != 0 {
                Text(String(format: "%.4f, %.4f", race.lat, race.lng))
                    .appText(.codeXs)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        resolving = true
        resolveError = nil
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                resolving = false
                if let error {
                    resolveError = "Search failed: \(error.localizedDescription)"
                    return
                }
                guard let item = response?.mapItems.first else {
                    resolveError = "No place found."
                    return
                }
                let placemark = item.placemark
                let coord = placemark.coordinate
                race.lat = coord.latitude
                race.lng = coord.longitude
                let title = completion.title
                let subtitle = completion.subtitle
                race.address = subtitle.isEmpty ? title : "\(title), \(subtitle)"
                race.city = placemark.locality ?? placemark.administrativeArea ?? race.city
                if let country = placemark.country, !country.isEmpty {
                    race.country = country
                }
                completer.queryFragment = ""
                completer.results = []
            }
        }
    }
}

/// `MKLocalSearchCompleter` を SwiftUI Observation から使えるようラップする。
@Observable
final class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var queryFragment: String = "" {
        didSet { completer.queryFragment = queryFragment }
    }
    var results: [MKLocalSearchCompletion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let snapshot = completer.results
        Task { @MainActor in
            self.results = snapshot
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}
