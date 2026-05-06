#if canImport(HealthKit)
import SwiftUI
import HealthKit

/// Apple Health から取得した HKWorkout (running) のリストを表示し、1 件選んで取り込みフローに渡す。
///
/// 使い方:
///   .sheet(isPresented: $showPicker) {
///       HealthKitWorkoutPickerSheet { workout in
///           // workout を ParsedActivity に変換して保存
///       }
///   }
struct HealthKitWorkoutPickerSheet: View {
    let onSelect: (HKWorkout) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var workouts: [HKWorkout] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasRequestedAuth = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Apple Health")
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await reload() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                    }
                }
                .task { await initialLoad() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !HealthKitWorkoutFetcher.isAvailable {
            unavailableState
        } else if isLoading && workouts.isEmpty {
            ProgressView("Loading workouts...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            errorState(errorMessage)
        } else if workouts.isEmpty {
            emptyState
        } else {
            workoutList
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Apple Health is not available on this device.")
                .appText(.bodySm)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text(message)
                .appText(.bodySm)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                Task { await reload() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
            .foregroundStyle(.black)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No running workouts found in the past year.")
                .appText(.bodySm)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Make sure RunJourney has access to Health data in Settings → Health.")
                .appText(.bodyXs)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var workoutList: some View {
        List {
            ForEach(workouts, id: \.uuid) { workout in
                Button {
                    onSelect(workout)
                    dismiss()
                } label: {
                    WorkoutRow(workout: workout)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .refreshable { await reload() }
    }

    // MARK: - Loading

    private func initialLoad() async {
        guard !hasRequestedAuth else { return }
        hasRequestedAuth = true
        do {
            try await HealthKitWorkoutFetcher.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await reload()
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            workouts = try await HealthKitWorkoutFetcher.recentRunningWorkouts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Row

private struct WorkoutRow: View {
    let workout: HKWorkout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.startDate, format: .dateTime.year().month().day().hour().minute())
                    .appText(.bodyBase)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 12) {
                    Text(distanceLabel)
                        .appText(.codeSm)
                        .foregroundStyle(.secondary)
                    Text(durationLabel)
                        .appText(.codeSm)
                        .foregroundStyle(.secondary)
                    if let pace = paceLabel {
                        Text(pace)
                            .appText(.codeSm)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    private var distanceMeters: Double? {
        if let stat = workout.statistics(for: HKQuantityType(.distanceWalkingRunning)),
           let q = stat.sumQuantity() {
            return q.doubleValue(for: .meter())
        }
        return nil
    }

    private var distanceLabel: String {
        guard let m = distanceMeters, m > 0 else { return "—" }
        let km = m / 1000.0
        return km >= 10 ? String(format: "%.1f km", km) : String(format: "%.2f km", km)
    }

    private var durationLabel: String {
        let s = Int(workout.duration)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    private var paceLabel: String? {
        guard let m = distanceMeters, m > 0 else { return nil }
        let pace = workout.duration / (m / 1000.0)
        let mm = Int(pace) / 60
        let ss = Int(pace) % 60
        return String(format: "%d:%02d /km", mm, ss)
    }
}
#endif
