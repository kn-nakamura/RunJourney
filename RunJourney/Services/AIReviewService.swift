import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Foundation Models (on-device Apple Intelligence) を使った AI レースレビュー生成。
///
/// - 端末側で完結するため API キー不要・通信なし。
/// - GitHub Actions の `macos-latest` には FoundationModels SDK が無い可能性があるため
///   `#if canImport(FoundationModels)` で全実装をガードする。
@Observable @MainActor
final class AIReviewService {

    enum Availability: Equatable {
        case unknown
        case ready
        case unavailable(reason: String)
    }

    enum GenerationState: Equatable {
        case idle
        case generating
        case success
        case failure(message: String)
    }

    private(set) var availability: Availability = .unknown
    private(set) var state: GenerationState = .idle

    /// 識別用のモデルバージョン文字列。`RaceResult.aiReviewModelVersion` に保存される。
    static let modelVersion = "foundation-models-1.0"

    init() {}

    /// `SystemLanguageModel.default.availability` を読みに行く。UI の onAppear などから呼ぶ。
    func refreshAvailability() async {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                availability = .ready
            case .unavailable(let reason):
                availability = .unavailable(reason: Self.message(for: reason))
            @unknown default:
                availability = .unavailable(reason: String(localized: "AI Review is unavailable"))
            }
        } else {
            availability = .unavailable(reason: String(localized: "AI Review requires iOS 26 or later"))
        }
        #else
        availability = .unavailable(reason: String(localized: "AI Review is unavailable"))
        #endif
    }

    /// 1回分のレビューを生成して返す。失敗時は nil。`state` を内部で更新する。
    /// 呼び出し側が `RaceResult.aiReviewText` 等への保存と `modelContext.save()` を担う。
    func generateReview(
        for result: RaceResult,
        race: Race?,
        plan: PacePlan?,
        unit: DistanceUnit
    ) async -> String? {
        state = .generating

        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            state = .failure(message: String(localized: "AI Review requires iOS 26 or later"))
            return nil
        }
        if availability == .unknown { await refreshAvailability() }
        guard case .ready = availability else {
            if case .unavailable(let reason) = availability {
                state = .failure(message: reason)
            } else {
                state = .failure(message: String(localized: "AI Review is unavailable"))
            }
            return nil
        }

        let userPrompt = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: race,
            plan: plan,
            unit: unit
        )

        do {
            let session = LanguageModelSession {
                AIReviewPromptBuilder.systemPrompt
            }
            let response = try await session.respond(to: userPrompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                state = .failure(message: String(localized: "Generation returned an empty response"))
                return nil
            }
            state = .success
            return text
        } catch is CancellationError {
            state = .idle
            return nil
        } catch {
            state = .failure(message: error.localizedDescription)
            return nil
        }
        #else
        state = .failure(message: String(localized: "AI Review is unavailable"))
        return nil
        #endif
    }

    // MARK: - Helpers

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return String(localized: "Apple Intelligence is not available on this device")
        case .appleIntelligenceNotEnabled:
            return String(localized: "Apple Intelligence is disabled in Settings")
        case .modelNotReady:
            return String(localized: "Generative model is not ready yet")
        @unknown default:
            return String(localized: "AI Review is unavailable")
        }
    }
    #endif
}
