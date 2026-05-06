import SwiftUI
import SwiftData

/// AIによるレースレビューを表示・生成するモーダル。
/// - 端末が Apple Intelligence 非対応なら案内のみ。
/// - キャッシュ済みなら即表示し、ボタンで再生成。
struct AIReviewSheet: View {
    @Bindable var result: RaceResult
    let race: Race?
    let plan: PacePlan?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    @State private var service = AIReviewService()
    @State private var generationTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    content
                }
                .padding()
            }
            .background(Color.bgPrimary)
            .navigationTitle("AI Review")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await service.refreshAvailability()
                if result.aiReviewText == nil, case .ready = service.availability {
                    startGeneration()
                }
            }
            .onDisappear {
                generationTask?.cancel()
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(race?.name ?? "Result")
                .appText(.displayMd)
                .foregroundStyle(Color.textPrimary)
            Text(result.raceDate.formatted(date: .long, time: .omitted))
                .appText(.bodySm)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch service.availability {
        case .unknown:
            HStack(spacing: 8) {
                ProgressView()
                Text("Checking…").appText(.bodySm).foregroundStyle(.secondary)
            }
        case .unavailable(let reason):
            unavailableView(reason: reason)
        case .ready:
            availableView
        }
    }

    @ViewBuilder
    private var availableView: some View {
        if case .generating = service.state {
            generatingView
        } else if let cached = result.aiReviewText, !cached.isEmpty {
            reviewView(text: cached)
        } else if case .failure(let message) = service.state {
            failureView(message: message)
        } else {
            emptyStateView
        }
    }

    private var generatingView: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Generating…")
                .appText(.bodyMd)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func reviewView(text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .appText(.bodyMd)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if let stamp = result.aiReviewGeneratedAt {
                Text("Generated \(stamp.formatted(.relative(presentation: .named)))")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
            Button {
                startGeneration()
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Get a coach-style reflection on this race, generated on-device by Apple Intelligence.")
                .appText(.bodyMd)
                .foregroundStyle(.secondary)
            Button {
                startGeneration()
            } label: {
                Label("Generate AI Review", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func failureView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .appText(.bodySm)
                    .foregroundStyle(Color.textPrimary)
            }
            Button {
                startGeneration()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func unavailableView(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.slash")
                    .foregroundStyle(.secondary)
                Text("AI Review Unavailable")
                    .appText(.bodyMdBold)
                    .foregroundStyle(Color.textPrimary)
            }
            Text(reason)
                .appText(.bodySm)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func startGeneration() {
        generationTask?.cancel()
        generationTask = Task {
            let generated = await service.generateReview(
                for: result,
                race: race,
                plan: plan,
                unit: unit
            )
            if let generated {
                result.aiReviewText = generated
                result.aiReviewGeneratedAt = .now
                result.aiReviewModelVersion = AIReviewService.modelVersion
                try? modelContext.save()
            }
        }
    }
}
