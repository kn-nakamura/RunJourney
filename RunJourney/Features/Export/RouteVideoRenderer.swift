import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
import MapKit
import AVFoundation
import CoreLocation
import Photos

/// 画面録画 (ReplayKit) ではなく、`MKMapSnapshotter` + `AVAssetWriter` でフレーム単位
/// にレンダリングするオフラインビデオエクスポータ。
/// - 画面に出ているマップに依存しないため、シートを閉じてアプリ内を別の操作中でも
///   バックグラウンドで書き出しが続行できる
/// - marathon-record-app の web 版と同じ「overview → ランナー追従 → overview → 結果ホールド」
///   というシネマティック構成を再現する
@MainActor
@Observable
final class RouteVideoRenderer {

    /// アプリ全体で 1 つの書き出しタスクを保持する。シート再表示や画面遷移を跨いでも
    /// 同じインスタンスを参照することで、進捗・完了通知を継続して表示できる。
    static let shared = RouteVideoRenderer()

    enum Phase: Equatable {
        case idle
        case preparing
        case rendering
        case finalizing
        case savingToPhotos
        case finished
        case failed
        case cancelled
    }

    private(set) var phase: Phase = .idle
    private(set) var progress: Double = 0
    private(set) var statusMessage: String = ""
    private(set) var errorMessage: String? = nil
    private(set) var outputURL: URL? = nil
    private(set) var savedToPhotos: Bool = false

    /// 現在実行中のエクスポートタスク。cancel() 用に保持する。
    private var task: Task<Void, Never>?
    /// 書き出し中のキャンセル要求フラグ。バックグラウンドスレッドから読み取るため
    /// `@unchecked Sendable` なクラスにラップする。
    private var cancelToken: CancellationToken?

    var isRunning: Bool {
        switch phase {
        case .preparing, .rendering, .finalizing, .savingToPhotos: return true
        default: return false
        }
    }

    var isFinishedOrFailed: Bool {
        switch phase {
        case .finished, .failed, .cancelled: return true
        default: return false
        }
    }

    // MARK: - Public API

    /// 書き出しを開始する。既に走行中の場合は何もしない。
    func start(
        trackPoints: [TrackPoint],
        raceName: String?,
        finishTimeSec: Double?,
        strokeColor: UIColor,
        configuration: MKMapConfiguration,
        userInterfaceStyle: UIUserInterfaceStyle,
        preset: RouteVideoExportPreset
    ) {
        guard !isRunning else { return }
        guard trackPoints.count >= 2 else {
            phase = .failed
            errorMessage = "Route has no track points to render."
            return
        }

        outputURL = nil
        savedToPhotos = false
        errorMessage = nil
        progress = 0
        statusMessage = "Preparing…"
        phase = .preparing

        let token = CancellationToken()
        cancelToken = token

        let input = ExportInput(
            trackPoints: trackPoints,
            raceName: raceName,
            finishTimeSec: finishTimeSec,
            strokeColor: strokeColor,
            configuration: configuration,
            userInterfaceStyle: userInterfaceStyle,
            preset: preset
        )

        task = Task.detached(priority: .userInitiated) { [weak self] in
            await Self.runExport(input: input, token: token, host: self)
        }
    }

    func cancel() {
        cancelToken?.cancel()
    }

    /// `finished` / `failed` / `cancelled` 状態をクリアして idle に戻す。
    func reset() {
        guard !isRunning else { return }
        phase = .idle
        progress = 0
        statusMessage = ""
        errorMessage = nil
        outputURL = nil
        savedToPhotos = false
        cancelToken = nil
        task = nil
    }

    // MARK: - State updates (called from detached task)

    fileprivate func updatePhase(_ p: Phase, status: String? = nil) {
        phase = p
        if let status { statusMessage = status }
    }

    fileprivate func updateProgress(_ p: Double, status: String? = nil) {
        progress = max(0, min(1, p))
        if let status { statusMessage = status }
    }

    fileprivate func updateOutput(url: URL) {
        outputURL = url
    }

    fileprivate func markSavedToPhotos() {
        savedToPhotos = true
    }

    fileprivate func markFinished() {
        phase = .finished
        progress = 1
        statusMessage = "Done"
    }

    fileprivate func markFailed(_ message: String) {
        phase = .failed
        errorMessage = message
        statusMessage = "Failed"
    }

    fileprivate func markCancelled() {
        phase = .cancelled
        statusMessage = "Cancelled"
    }

    // MARK: - Export driver (detached)

    private static func runExport(
        input: ExportInput,
        token: CancellationToken,
        host: RouteVideoRenderer?
    ) async {
        do {
            try await Self.run(input: input, token: token, host: host)
        } catch is CancellationError {
            await MainActor.run { host?.markCancelled() }
        } catch let error {
            let msg = (error as NSError).localizedDescription
            await MainActor.run { host?.markFailed(msg) }
        }
    }

    private static func run(
        input: ExportInput,
        token: CancellationToken,
        host: RouteVideoRenderer?
    ) async throws {
        let preset = input.preset
        let coords = input.trackPoints.map(\.coordinate)

        // 出力ファイル
        let url = Self.makeOutputURL()
        try? FileManager.default.removeItem(at: url)

        // AVAssetWriter セットアップ
        let writerBundle = try Self.makeAssetWriter(url: url, preset: preset)
        let writer = writerBundle.writer
        let writerInput = writerBundle.input
        let adaptor = writerBundle.adaptor

        guard writer.startWriting() else {
            throw NSError(domain: "RouteVideoRenderer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: writer.error?.localizedDescription
                    ?? "Failed to start AVAssetWriter."
            ])
        }
        writer.startSession(atSourceTime: .zero)

        // overview カメラを 1 度だけ仮想 MKMapView で計算
        let overviewCamera = await MainActor.run { () -> MKMapCamera in
            Self.makeOverviewCamera(coords: coords, size: preset.size)
        }

        // 最初の follow カメラ (intro 終端 / animation 開始)
        let firstFollowCamera = Self.makeFollowCamera(
            trackPoints: input.trackPoints,
            atTime: 0,
            distanceKm: input.totalDistanceKm
        )

        // 最後の follow カメラ (animation 終端 / outro 開始)
        let lastFollowCamera = Self.makeFollowCamera(
            trackPoints: input.trackPoints,
            atTime: input.totalDurationSec,
            distanceKm: input.totalDistanceKm
        )

        // フレーム数の見積り
        let introFrames = Int((preset.introSeconds * Double(preset.fps)).rounded())
        let outroFrames = Int((preset.outroSeconds * Double(preset.fps)).rounded())
        let holdFrames  = Int((preset.holdSeconds  * Double(preset.fps)).rounded())
        let animSeconds = min(preset.maxAnimationSeconds,
                              max(2.0, input.totalDurationSec / preset.playbackSpeed))
        let animFrames  = Int((animSeconds * Double(preset.fps)).rounded())
        let totalFrames = introFrames + animFrames + outroFrames + holdFrames

        await MainActor.run {
            host?.updatePhase(.rendering, status: "Rendering 0%")
        }

        // フレームレンダリングループ
        var frameIndex = 0
        let frameDuration = CMTime(value: 1, timescale: Int32(preset.fps))

        // INTRO: overview → first follow に補間
        for i in 0..<introFrames {
            try Self.checkCancel(token)
            let t = introFrames > 1 ? Double(i) / Double(introFrames - 1) : 1.0
            let camera = Self.lerpCamera(from: overviewCamera, to: firstFollowCamera, t: easeInOutCubic(t))
            try await Self.renderAndAppend(
                phase: .intro(progress: t),
                camera: camera,
                input: input,
                animationTime: 0,
                writerInput: writerInput,
                adaptor: adaptor,
                presentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            )
            frameIndex += 1
            await Self.report(host: host, total: totalFrames, current: frameIndex)
        }

        // ANIMATION: ランナー追従
        for i in 0..<animFrames {
            try Self.checkCancel(token)
            let t = animFrames > 1 ? Double(i) / Double(animFrames - 1) : 1.0
            let animTime = t * input.totalDurationSec
            let camera = Self.makeFollowCamera(
                trackPoints: input.trackPoints,
                atTime: animTime,
                distanceKm: input.totalDistanceKm
            )
            try await Self.renderAndAppend(
                phase: .animation(progress: t),
                camera: camera,
                input: input,
                animationTime: animTime,
                writerInput: writerInput,
                adaptor: adaptor,
                presentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            )
            frameIndex += 1
            await Self.report(host: host, total: totalFrames, current: frameIndex)
        }

        // OUTRO: last follow → overview に補間
        for i in 0..<outroFrames {
            try Self.checkCancel(token)
            let t = outroFrames > 1 ? Double(i) / Double(outroFrames - 1) : 1.0
            let camera = Self.lerpCamera(from: lastFollowCamera, to: overviewCamera, t: easeInOutCubic(t))
            try await Self.renderAndAppend(
                phase: .outro(progress: t),
                camera: camera,
                input: input,
                animationTime: input.totalDurationSec,
                writerInput: writerInput,
                adaptor: adaptor,
                presentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            )
            frameIndex += 1
            await Self.report(host: host, total: totalFrames, current: frameIndex)
        }

        // HOLD: overview + 結果オーバーレイ
        for _ in 0..<holdFrames {
            try Self.checkCancel(token)
            try await Self.renderAndAppend(
                phase: .hold,
                camera: overviewCamera,
                input: input,
                animationTime: input.totalDurationSec,
                writerInput: writerInput,
                adaptor: adaptor,
                presentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            )
            frameIndex += 1
            await Self.report(host: host, total: totalFrames, current: frameIndex)
        }

        // ファイナライズ
        await MainActor.run { host?.updatePhase(.finalizing, status: "Finalizing video…") }
        writerInput.markAsFinished()
        await writer.finishWriting()

        if writer.status != .completed {
            throw NSError(domain: "RouteVideoRenderer", code: 2, userInfo: [
                NSLocalizedDescriptionKey: writer.error?.localizedDescription
                    ?? "AVAssetWriter did not complete."
            ])
        }

        await MainActor.run { host?.updateOutput(url: url) }

        // Photos に保存
        await MainActor.run { host?.updatePhase(.savingToPhotos, status: "Saving to Photos…") }
        let saved = await Self.saveToPhotos(url: url)
        if saved {
            await MainActor.run { host?.markSavedToPhotos() }
        }

        await MainActor.run { host?.markFinished() }
    }

    // MARK: - Reporting / cancellation

    private static func checkCancel(_ token: CancellationToken) throws {
        if token.isCancelled { throw CancellationError() }
    }

    private static func report(host: RouteVideoRenderer?, total: Int, current: Int) async {
        guard total > 0 else { return }
        let p = Double(current) / Double(total)
        let pct = Int((p * 100).rounded())
        await MainActor.run {
            host?.updateProgress(p, status: "Rendering \(pct)%")
        }
    }

    // MARK: - Frame composition

    /// 1 フレーム分: MKMapSnapshotter で背景マップを描画し、オーバーレイを合成して
    /// pixel buffer に書き出し、Writer に append する。
    private static func renderAndAppend(
        phase: RenderPhase,
        camera: MKMapCamera,
        input: ExportInput,
        animationTime: Double,
        writerInput: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        presentationTime: CMTime
    ) async throws {
        // MKMapSnapshotter は MainActor で構築するのが安全
        let snapshot = try await Self.renderSnapshot(
            camera: camera,
            preset: input.preset,
            configuration: input.configuration,
            userInterfaceStyle: input.userInterfaceStyle
        )

        let pixelBuffer = try Self.makePixelBuffer(adaptor: adaptor, size: input.preset.size)

        // Pixel buffer を描画コンテキストにマップ
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                                      | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let cgCtx = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw NSError(domain: "RouteVideoRenderer", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create CGContext for frame."
            ])
        }

        // CGContext は origin が左下、UIImage は左上。flip して UIGraphics 系を使う。
        cgCtx.translateBy(x: 0, y: CGFloat(height))
        cgCtx.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(cgCtx)
        defer { UIGraphicsPopContext() }

        let size = input.preset.size
        let bounds = CGRect(origin: .zero, size: size)

        // 1. 背景: マップタイル
        snapshot.image.draw(in: bounds)

        // 2. ルートオーバーレイ
        Self.drawRouteOverlay(
            snapshot: snapshot,
            input: input,
            animationTime: animationTime,
            in: bounds,
            phase: phase
        )

        // 3. HUD / 結果パネル
        Self.drawHUD(
            input: input,
            animationTime: animationTime,
            phase: phase,
            in: bounds
        )

        // Append
        if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
            // backpressure: writer の readiness を少し待ってから諦める
            await Self.waitUntilReady(writerInput: writerInput)
            if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                throw NSError(domain: "RouteVideoRenderer", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to append pixel buffer."
                ])
            }
        }
    }

    private static func waitUntilReady(writerInput: AVAssetWriterInput) async {
        // Writer が次のサンプルを受け入れられるまで polling 待機する。
        // 通常 1 フレーム以内で復帰する。
        for _ in 0..<50 {
            if writerInput.isReadyForMoreMediaData { return }
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }

    // MARK: - Drawing

    private static func drawRouteOverlay(
        snapshot: MKMapSnapshotter.Snapshot,
        input: ExportInput,
        animationTime: Double,
        in bounds: CGRect,
        phase: RenderPhase
    ) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let allCoords = input.trackPoints.map(\.coordinate)
        guard allCoords.count >= 2 else { return }

        // フルルート (うっすら下書き)
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(4)
        let baseStroke: UIColor = (input.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.20)
            : UIColor.black.withAlphaComponent(0.30))
        ctx.setStrokeColor(baseStroke.cgColor)
        let allPath = UIBezierPath()
        allPath.move(to: snapshot.point(for: allCoords[0]))
        for c in allCoords.dropFirst() {
            allPath.addLine(to: snapshot.point(for: c))
        }
        ctx.addPath(allPath.cgPath)
        ctx.strokePath()
        ctx.restoreGState()

        // 走破済みライン
        let traveled = Self.traveledCoords(input: input, atTime: animationTime)
        if traveled.count >= 2 {
            ctx.saveGState()
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setLineWidth(6)
            ctx.setStrokeColor(input.strokeColor.cgColor)
            let traveledPath = UIBezierPath()
            traveledPath.move(to: snapshot.point(for: traveled[0]))
            for c in traveled.dropFirst() {
                traveledPath.addLine(to: snapshot.point(for: c))
            }
            ctx.addPath(traveledPath.cgPath)
            ctx.strokePath()
            ctx.restoreGState()
        }

        // スタート / フィニッシュフラグ
        if let first = allCoords.first {
            Self.drawFlag(
                at: snapshot.point(for: first),
                color: UIColor.systemGreen,
                symbol: "🏁",
                fill: false
            )
        }
        if let last = allCoords.last {
            Self.drawFlag(
                at: snapshot.point(for: last),
                color: UIColor.systemRed,
                symbol: "🏁",
                fill: true
            )
        }

        // ランナードット (animation / outro 中だけ。intro / hold は overview なので非表示)
        let showRunner: Bool
        switch phase {
        case .animation, .outro: showRunner = true
        default: showRunner = false
        }
        if showRunner,
           let runner = Self.interpolatedCoord(input: input, atTime: animationTime) {
            let p = snapshot.point(for: runner)
            ctx.saveGState()
            // グロー
            ctx.setShadow(offset: .zero, blur: 14, color: input.strokeColor.cgColor)
            ctx.setFillColor(input.strokeColor.cgColor)
            let radius: CGFloat = 11
            ctx.fillEllipse(in: CGRect(x: p.x - radius, y: p.y - radius,
                                       width: radius * 2, height: radius * 2))
            // 白ボーダー
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: CGRect(x: p.x - radius, y: p.y - radius,
                                         width: radius * 2, height: radius * 2))
            ctx.restoreGState()
        }
    }

    private static func drawFlag(at point: CGPoint, color: UIColor, symbol: String, fill: Bool) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let size: CGFloat = 22
        let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: rect)
        // 中央に小さなドット
        if fill {
            let inner = rect.insetBy(dx: size * 0.30, dy: size * 0.30)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: inner)
        }
        ctx.restoreGState()
        _ = symbol  // 将来絵文字を描画する場合に備えて残す
    }

    private static func drawHUD(
        input: ExportInput,
        animationTime: Double,
        phase: RenderPhase,
        in bounds: CGRect
    ) {
        switch phase {
        case .intro, .animation, .outro:
            Self.drawTopBanner(input: input, animationTime: animationTime, in: bounds, phase: phase)
        case .hold:
            Self.drawResultPanel(input: input, in: bounds)
        }
    }

    private static func drawTopBanner(
        input: ExportInput,
        animationTime: Double,
        in bounds: CGRect,
        phase: RenderPhase
    ) {
        let topPad: CGFloat = 24
        let height: CGFloat = 56
        let rect = CGRect(x: 16, y: topPad, width: bounds.width - 32, height: height)
        Self.drawBlurPanel(rect: rect, cornerRadius: 14)

        // 大会名
        if let name = input.raceName, !name.isEmpty {
            let p = NSMutableParagraphStyle(); p.alignment = .center; p.lineBreakMode = .byTruncatingTail
            (name as NSString).draw(
                in: CGRect(x: rect.minX + 12, y: rect.minY + 6, width: rect.width - 24, height: 20),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: p
                ]
            )
        }

        // 経過時間 / 進捗距離
        let elapsed = PaceUtils.formatDuration(animationTime)
        let curDist = Self.interpolatedDistanceM(input: input, atTime: animationTime) / 1000
        let totalDist = input.totalDistanceKm
        let line2 = "\(elapsed)   •   \(String(format: "%.2f", curDist)) / \(String(format: "%.2f", totalDist)) km"
        let p2 = NSMutableParagraphStyle(); p2.alignment = .center
        (line2 as NSString).draw(
            in: CGRect(x: rect.minX + 12, y: rect.minY + 28, width: rect.width - 24, height: 22),
            withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: p2
            ]
        )
        _ = phase
    }

    private static func drawResultPanel(input: ExportInput, in bounds: CGRect) {
        let height: CGFloat = 220
        let rect = CGRect(x: 24, y: bounds.height - height - 60,
                          width: bounds.width - 48, height: height)
        Self.drawBlurPanel(rect: rect, cornerRadius: 22)

        // ヘッダ
        let pCenter = NSMutableParagraphStyle(); pCenter.alignment = .center
        if let name = input.raceName, !name.isEmpty {
            (name as NSString).draw(
                in: CGRect(x: rect.minX + 16, y: rect.minY + 16, width: rect.width - 32, height: 24),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                    .paragraphStyle: pCenter
                ]
            )
        }

        // フィニッシュタイム
        let timeText: String
        if let t = input.finishTimeSec, t > 0 {
            timeText = PaceUtils.formatDuration(t)
        } else {
            timeText = PaceUtils.formatDuration(input.totalDurationSec)
        }
        (timeText as NSString).draw(
            in: CGRect(x: rect.minX + 16, y: rect.minY + 50, width: rect.width - 32, height: 60),
            withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 52, weight: .heavy),
                .foregroundColor: UIColor.white,
                .paragraphStyle: pCenter
            ]
        )

        // 距離 / ペース
        let distKm = input.totalDistanceKm
        let paceSecPerKm: Double
        if distKm > 0 {
            let totalSec = input.finishTimeSec ?? input.totalDurationSec
            paceSecPerKm = totalSec > 0 ? totalSec / distKm : 0
        } else {
            paceSecPerKm = 0
        }
        let distLabel = String(format: "%.2f km", distKm)
        let paceLabel = paceSecPerKm > 0 ? PaceUtils.formatPaceSimple(Int(paceSecPerKm.rounded())) + " /km" : "--:-- /km"

        let stats = "\(distLabel)   •   \(paceLabel)"
        (stats as NSString).draw(
            in: CGRect(x: rect.minX + 16, y: rect.minY + 120, width: rect.width - 32, height: 28),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                .paragraphStyle: pCenter
            ]
        )

        // ブランド (アプリ名)
        ("RunJourney" as NSString).draw(
            in: CGRect(x: rect.minX + 16, y: rect.minY + 162, width: rect.width - 32, height: 24),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: input.strokeColor,
                .paragraphStyle: pCenter
            ]
        )
    }

    private static func drawBlurPanel(rect: CGRect, cornerRadius: CGFloat) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        ctx.addPath(path.cgPath)
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fillPath()
        ctx.addPath(path.cgPath)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Math helpers

    private static func traveledCoords(input: ExportInput, atTime t: Double) -> [CLLocationCoordinate2D] {
        let pts = input.trackPoints
        guard !pts.isEmpty else { return [] }
        var lo = 0
        var hi = pts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if pts[mid].timeSec <= t { lo = mid } else { hi = mid - 1 }
        }
        var out = pts[0...lo].map(\.coordinate)
        if let cur = Self.interpolatedCoord(input: input, atTime: t),
           let last = out.last,
           last.latitude != cur.latitude || last.longitude != cur.longitude {
            out.append(cur)
        }
        return out
    }

    private static func interpolatedCoord(input: ExportInput, atTime t: Double) -> CLLocationCoordinate2D? {
        PlaybackMath.interpolatedPoint(in: input.trackPoints, at: t)?.coordinate
    }

    private static func interpolatedDistanceM(input: ExportInput, atTime t: Double) -> Double {
        PlaybackMath.interpolatedPoint(in: input.trackPoints, at: t)?.distanceM ?? 0
    }

    // MARK: - Camera builders

    private static func makeOverviewCamera(coords: [CLLocationCoordinate2D], size: CGSize) -> MKMapCamera {
        guard !coords.isEmpty else { return MKMapCamera() }
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLng = coords[0].longitude, maxLng = coords[0].longitude
        for c in coords {
            if c.latitude < minLat { minLat = c.latitude }
            if c.latitude > maxLat { maxLat = c.latitude }
            if c.longitude < minLng { minLng = c.longitude }
            if c.longitude > maxLng { maxLng = c.longitude }
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        // 1.4x padding
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.005, (maxLng - minLng) * 1.4)
        )

        // 仮の MKMapView に region をセットして camera を取得 → distance/heading が
        // 自動的に画面サイズにフィットする。MainActor 上で実行する前提。
        let map = MKMapView(frame: CGRect(origin: .zero, size: size))
        map.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        let cam = map.camera.copy() as? MKMapCamera ?? MKMapCamera()
        cam.centerCoordinate = center
        cam.pitch = 0
        cam.heading = 0
        return cam
    }

    private static func makeFollowCamera(
        trackPoints: [TrackPoint],
        atTime t: Double,
        distanceKm: Double
    ) -> MKMapCamera {
        let profile = PlaybackMath.followCameraProfile(distanceKm: distanceKm, emphasis: .high)
        let cur = PlaybackMath.interpolatedPoint(in: trackPoints, at: t)
        let lookAhead = PlaybackMath.lookAheadPoint(
            in: trackPoints,
            from: t,
            lookAheadSec: profile.lookAheadSec
        )
        let center = cur?.coordinate ?? trackPoints.first?.coordinate ?? CLLocationCoordinate2D()
        let bearing: Double = {
            guard let cur, let lookAhead, lookAhead.id != cur.id else { return 0 }
            return PlaybackMath.bearingDegrees(from: cur.coordinate, to: lookAhead.coordinate)
        }()
        let pitch = PlaybackMath.angleToMapPitch(profile.angle)
        let flip = PlaybackMath.headingFlip(forAngle: profile.angle)
        let heading = (bearing + flip + 360).truncatingRemainder(dividingBy: 360)
        let cam = MKMapCamera()
        cam.centerCoordinate = center
        cam.centerCoordinateDistance = profile.distance
        cam.pitch = pitch
        cam.heading = heading
        return cam
    }

    /// 2 つの MKMapCamera を線形補間。heading は最短経路で。
    private static func lerpCamera(from a: MKMapCamera, to b: MKMapCamera, t: Double) -> MKMapCamera {
        let lat = a.centerCoordinate.latitude + (b.centerCoordinate.latitude - a.centerCoordinate.latitude) * t
        let lng = a.centerCoordinate.longitude + (b.centerCoordinate.longitude - a.centerCoordinate.longitude) * t
        let dist = a.centerCoordinateDistance + (b.centerCoordinateDistance - a.centerCoordinateDistance) * t
        let pitch = Double(a.pitch) + (Double(b.pitch) - Double(a.pitch)) * t
        let headingDelta = AngleMath.shortestDelta(from: a.heading, to: b.heading)
        let heading = (a.heading + headingDelta * t + 360).truncatingRemainder(dividingBy: 360)

        let cam = MKMapCamera()
        cam.centerCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        cam.centerCoordinateDistance = max(1, dist)
        cam.pitch = CGFloat(pitch)
        cam.heading = heading
        return cam
    }

    // MARK: - MKMapSnapshotter wrapper

    private static func renderSnapshot(
        camera: MKMapCamera,
        preset: RouteVideoExportPreset,
        configuration: MKMapConfiguration,
        userInterfaceStyle: UIUserInterfaceStyle
    ) async throws -> MKMapSnapshotter.Snapshot {
        let options = await MainActor.run { () -> MKMapSnapshotter.Options in
            let o = MKMapSnapshotter.Options()
            o.size = preset.size
            o.scale = 1
            o.camera = camera
            o.preferredConfiguration = configuration
            o.traitCollection = UITraitCollection(userInterfaceStyle: userInterfaceStyle)
            return o
        }
        let snapshotter = MKMapSnapshotter(options: options)
        return try await withCheckedThrowingContinuation { cont in
            snapshotter.start(with: .global(qos: .userInitiated)) { snap, err in
                if let snap {
                    cont.resume(returning: snap)
                } else {
                    cont.resume(throwing: err ?? NSError(domain: "RouteVideoRenderer", code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "MKMapSnapshotter returned nil snapshot."
                    ]))
                }
            }
        }
    }

    // MARK: - AVAssetWriter

    private struct WriterBundle {
        let writer: AVAssetWriter
        let input: AVAssetWriterInput
        let adaptor: AVAssetWriterInputPixelBufferAdaptor
    }

    private static func makeAssetWriter(url: URL, preset: RouteVideoExportPreset) throws -> WriterBundle {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(preset.size.width),
            AVVideoHeightKey: Int(preset.size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: preset.bitrate,
                AVVideoExpectedSourceFrameRateKey: preset.fps,
                AVVideoMaxKeyFrameIntervalKey: preset.fps * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(preset.size.width),
            kCVPixelBufferHeightKey as String: Int(preset.size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attrs
        )
        if writer.canAdd(input) {
            writer.add(input)
        } else {
            throw NSError(domain: "RouteVideoRenderer", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "AVAssetWriter cannot add video input."
            ])
        }
        return WriterBundle(writer: writer, input: input, adaptor: adaptor)
    }

    private static func makePixelBuffer(
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        size: CGSize
    ) throws -> CVPixelBuffer {
        guard let pool = adaptor.pixelBufferPool else {
            throw NSError(domain: "RouteVideoRenderer", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "Pixel buffer pool is not available."
            ])
        }
        var pb: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        guard status == kCVReturnSuccess, let buffer = pb else {
            throw NSError(domain: "RouteVideoRenderer", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "CVPixelBufferPoolCreatePixelBuffer failed (status \(status))."
            ])
        }
        _ = size
        return buffer
    }

    // MARK: - Photos

    private static func saveToPhotos(url: URL) async -> Bool {
        let status: PHAuthorizationStatus = await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { s in cont.resume(returning: s) }
        }
        guard status == .authorized || status == .limited else { return false }
        return await withCheckedContinuation { cont in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, _ in
                cont.resume(returning: success)
            }
        }
    }

    // MARK: - Output URL

    private static func makeOutputURL() -> URL {
        let tmp = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "RunJourney-\(formatter.string(from: Date())).mp4"
        return tmp.appendingPathComponent(name)
    }
}

// MARK: - Input

private struct ExportInput: @unchecked Sendable {
    let trackPoints: [TrackPoint]
    let raceName: String?
    let finishTimeSec: Double?
    let strokeColor: UIColor
    let configuration: MKMapConfiguration
    let userInterfaceStyle: UIUserInterfaceStyle
    let preset: RouteVideoExportPreset

    var totalDurationSec: Double { trackPoints.last?.timeSec ?? 0 }
    var totalDistanceKm: Double { (trackPoints.last?.distanceM ?? 0) / 1000 }
}

// MARK: - Phase

private enum RenderPhase {
    case intro(progress: Double)
    case animation(progress: Double)
    case outro(progress: Double)
    case hold
}

// MARK: - Preset

struct RouteVideoExportPreset: Equatable {
    /// 動画サイズ (ピクセル)
    var size: CGSize
    /// fps
    var fps: Int
    /// イントロ秒数 (overview → follow)
    var introSeconds: Double
    /// アウトロ秒数 (follow → overview)
    var outroSeconds: Double
    /// 最後の overview ホールド秒数 (結果表示)
    var holdSeconds: Double
    /// アニメーション部の最大秒数 (実走時間 / playbackSpeed で決まるが上限を設ける)
    var maxAnimationSeconds: Double
    /// 実走を何倍速で進めるか (16× なら 16 倍速で 1 周再生する)
    var playbackSpeed: Double
    /// 動画ビットレート (bps)
    var bitrate: Int

    static let standard = RouteVideoExportPreset(
        size: CGSize(width: 720, height: 1280),
        fps: 30,
        introSeconds: 2.5,
        outroSeconds: 3.0,
        holdSeconds: 3.0,
        maxAnimationSeconds: 45,
        playbackSpeed: 32,
        bitrate: 6_000_000
    )

    static let detailed = RouteVideoExportPreset(
        size: CGSize(width: 720, height: 1280),
        fps: 30,
        introSeconds: 2.5,
        outroSeconds: 3.0,
        holdSeconds: 3.0,
        maxAnimationSeconds: 75,
        playbackSpeed: 8,
        bitrate: 6_000_000
    )

    static let quick = RouteVideoExportPreset(
        size: CGSize(width: 720, height: 1280),
        fps: 30,
        introSeconds: 2.0,
        outroSeconds: 2.5,
        holdSeconds: 2.5,
        maxAnimationSeconds: 20,
        playbackSpeed: 128,
        bitrate: 6_000_000
    )
}

// MARK: - Cancellation

private final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled: Bool = false
    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _cancelled
    }
    func cancel() {
        lock.lock(); _cancelled = true; lock.unlock()
    }
}

// MARK: - Easing

private func easeInOutCubic(_ t: Double) -> Double {
    let x = max(0, min(1, t))
    if x < 0.5 { return 4 * x * x * x }
    let f = -2 * x + 2
    return 1 - f * f * f / 2
}

#endif
