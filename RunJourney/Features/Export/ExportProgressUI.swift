import SwiftUI
#if canImport(UIKit)
import UIKit

/// アプリのルートに重ねるエクスポート進捗バッジ。
/// `RouteVideoRenderer.shared` の状態を観察し、書き出し中・完了直後だけ
/// 画面上部に小さなカプセルを表示する。タップで `ExportStatusSheet` を開いて
/// キャンセル / 共有 / 詳細状態確認ができる。
struct ExportProgressBadge: View {
    @State private var renderer = RouteVideoRenderer.shared
    @State private var showSheet: Bool = false
    @State private var autoDismissTask: Task<Void, Never>? = nil
    /// 完了/失敗後、しばらくしてバッジを自動的に隠すフラグ。
    @State private var hideAfterFinish: Bool = false

    var body: some View {
        Group {
            if shouldShow {
                badgeCapsule
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: shouldShow)
        .onChange(of: renderer.phase) { _, _ in handlePhaseChange() }
        .sheet(isPresented: $showSheet) {
            ExportStatusSheet()
        }
        .allowsHitTesting(shouldShow)
    }

    private var shouldShow: Bool {
        if hideAfterFinish { return false }
        switch renderer.phase {
        case .preparing, .rendering, .finalizing, .savingToPhotos, .finished, .failed:
            return true
        case .idle, .cancelled:
            return false
        }
    }

    private var badgeCapsule: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 8) {
                badgeIcon
                Text(label)
                    .appText(.bodyXs)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.20), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var badgeIcon: some View {
        switch renderer.phase {
        case .preparing, .finalizing, .savingToPhotos:
            ProgressView()
                .tint(Color.accentPrimary)
                .scaleEffect(0.7)
                .frame(width: 16, height: 16)
        case .rendering:
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.04, renderer.progress)))
                    .stroke(Color.accentPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 16, height: 16)
            .animation(.linear(duration: 0.1), value: renderer.progress)
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentPrimary)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .idle, .cancelled:
            EmptyView()
        }
    }

    private var label: String {
        switch renderer.phase {
        case .preparing:      return "Preparing video…"
        case .rendering:      return "Exporting \(Int((renderer.progress * 100).rounded()))%"
        case .finalizing:     return "Finalizing…"
        case .savingToPhotos: return "Saving to Photos…"
        case .finished:       return renderer.savedToPhotos ? "Saved to Photos" : "Export complete"
        case .failed:         return "Export failed"
        case .idle, .cancelled: return ""
        }
    }

    private func handlePhaseChange() {
        autoDismissTask?.cancel()
        switch renderer.phase {
        case .preparing, .rendering, .finalizing, .savingToPhotos:
            hideAfterFinish = false
        case .finished, .failed:
            hideAfterFinish = false
            // 5 秒で自動的にバッジをフェードアウトさせる (タップで開けば中断される)。
            autoDismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { return }
                withAnimation { hideAfterFinish = true }
            }
        case .idle, .cancelled:
            hideAfterFinish = true
        }
    }
}

// MARK: - Status sheet (presentable from anywhere)

/// `RouteVideoRenderer.shared` の現在状態だけを表示する軽量シート。
/// ExportSheet とは異なり `controller` 等のコンテキストを必要としないので、
/// 別画面に遷移したあとでも進捗確認 / 共有 / キャンセルができる。
struct ExportStatusSheet: View {
    @State private var renderer = RouteVideoRenderer.shared
    @State private var showShareSheet: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                statusSection
                if renderer.phase == .finished, renderer.outputURL != nil {
                    shareSection
                }
                actionsSection
            }
            .navigationTitle("Export Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = renderer.outputURL {
                    ExportShareSheet(items: [url])
                        .ignoresSafeArea()
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Section {
            switch renderer.phase {
            case .preparing, .rendering, .finalizing, .savingToPhotos:
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: renderer.progress)
                        .tint(Color.accentPrimary)
                    Text(renderer.statusMessage.isEmpty
                         ? "\(Int((renderer.progress * 100).rounded()))%"
                         : renderer.statusMessage)
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    Text("You can close this sheet and keep using the app — the export keeps running in the background.")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            case .finished:
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.accentPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export complete")
                            .appText(.bodyBaseBold)
                        Text(renderer.savedToPhotos
                             ? "Saved to your Photo Library."
                             : "Video saved to a temporary file.")
                            .appText(.bodyXs)
                            .foregroundStyle(.secondary)
                    }
                }
            case .failed:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Export failed")
                        .appText(.bodyBaseBold)
                    Text(renderer.errorMessage ?? "Unknown error.")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                }
            case .cancelled, .idle:
                Text("No export in progress.")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var shareSection: some View {
        Section {
            Button {
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Video")
                        .appText(.bodyBaseBold)
                    Spacer()
                }
                .foregroundStyle(Color.accentPrimary)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            switch renderer.phase {
            case .preparing, .rendering, .finalizing, .savingToPhotos:
                Button(role: .destructive) {
                    renderer.cancel()
                } label: {
                    HStack { Spacer(); Text("Cancel Export"); Spacer() }
                }
            case .finished, .failed, .cancelled:
                Button {
                    renderer.reset()
                    dismiss()
                } label: {
                    HStack { Spacer(); Text("Dismiss"); Spacer() }
                }
            case .idle:
                EmptyView()
            }
        }
    }
}

// MARK: - Share sheet (shared)

/// UIActivityViewController の SwiftUI ラッパ。`ExportSheet` / `ExportStatusSheet`
/// 両方で再利用する。
struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
