import Foundation
import SwiftUI
#if os(iOS)
import ReplayKit
#endif

/// 画面録画 (ReplayKit) のラッパー。
/// iOSのみ対応。macOSでは録画ボタンを非表示にする。
@Observable
final class VideoExporter {

    enum State: Equatable {
        case idle
        case starting
        case recording
        case stopping
        case error(String)
    }

    private(set) var state: State = .idle
    /// 録画開始時のシステム時刻（UI上の経過秒表示用）
    private(set) var startedAt: Date?

#if os(iOS)
    private let recorder = RPScreenRecorder.shared()

    /// この端末/シミュレータで録画可能か
    var isAvailable: Bool { recorder.isAvailable }

    func startRecording() async {
        guard recorder.isAvailable else {
            state = .error("Screen recording is not available on this device (try on a real iOS device).")
            return
        }
        if recorder.isRecording {
            state = .recording
            return
        }
        state = .starting
        do {
            try await startRecordingHandler()
            await MainActor.run {
                self.state = .recording
                self.startedAt = .now
            }
        } catch {
            await MainActor.run {
                self.state = .error("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    /// 録画を停止し、プレビュー画面を返す。
    /// 戻り値が `nil` の場合は失敗（state.error を確認）。
    func stopRecording() async -> RPPreviewViewController? {
        guard recorder.isRecording else { return nil }
        state = .stopping
        do {
            let preview = try await stopRecordingHandler()
            await MainActor.run {
                self.state = .idle
                self.startedAt = nil
            }
            return preview
        } catch {
            await MainActor.run {
                self.state = .error("Failed to stop recording: \(error.localizedDescription)")
                self.startedAt = nil
            }
            return nil
        }
    }

    func discardRecording() async {
        guard recorder.isRecording else { return }
        _ = try? await stopRecordingHandler()
        await MainActor.run {
            self.state = .idle
            self.startedAt = nil
        }
    }

    // MARK: - Continuation wrappers (iOS 18+ にあるasync APIをバックポート)

    private func startRecordingHandler() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            recorder.startRecording { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func stopRecordingHandler() async throws -> RPPreviewViewController {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RPPreviewViewController, Error>) in
            recorder.stopRecording { preview, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let preview = preview {
                    continuation.resume(returning: preview)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "VideoExporter",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Recording preview was not returned"]
                    ))
                }
            }
        }
    }
#else
    var isAvailable: Bool { false }
    func startRecording() async {
        state = .error("Screen recording is iOS only.")
    }
    func stopRecording() async -> Any? { nil }
    func discardRecording() async {}
#endif
}
