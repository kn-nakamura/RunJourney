import SwiftUI
import CoreLocation

/// 共有カード共通の小さな部品 (背景・ルート描画 SwiftUI View・ロゴ等)。
///
/// MARK の方針:
/// - 全部品は `ShareTheme` から `palette` を引き、`AccentChoice` から `hex` を引く
///   ローカルな静的描画のみ。dynamic 色 (`Color.bgPrimary` 等) には依存しない。
/// - `ShareFormat` に依存するレイアウト計算もここに集約 (各カード本体をすっきり保つため)。
enum ShareCardKit {

    // MARK: - Background

    /// カード全面の背景: 端にアクセントストライプ + 中央寄りの軽い circular 装飾。
    /// Light / Dark 両テーマで自然に映えるよう、円の不透明度をテーマ別に調整する。
    @ViewBuilder
    static func background(palette: SharePalette, accent: Color, format: ShareFormat) -> some View {
        ZStack {
            // 縦方向のグラデーション (上→中央→下)。Light は中央を僅かに沈ませて立体感を出す。
            LinearGradient(
                colors: [palette.bgPrimary, palette.bgSecondary, palette.bgPrimary],
                startPoint: .top,
                endPoint: .bottom
            )

            // アクセント帯。Wide / Landscape は左ストライプ、Portrait / Square は上下ライン。
            stripes(accent: accent, format: format)

            // 装飾円 (画面隅にぼんやり配置)。
            decorativeCircles(accent: accent, format: format)
        }
    }

    @ViewBuilder
    private static func stripes(accent: Color, format: ShareFormat) -> some View {
        if format.isWide {
            HStack(spacing: 0) {
                Rectangle().fill(accent).frame(width: 6).opacity(0.85)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                Rectangle().fill(accent).frame(height: 4).opacity(0.85)
                Spacer()
                Rectangle().fill(accent).frame(height: 4).opacity(0.85)
            }
        }
    }

    @ViewBuilder
    private static func decorativeCircles(accent: Color, format: ShareFormat) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Circle()
                    .fill(accent)
                    .opacity(0.07)
                    .frame(width: w * 0.7, height: w * 0.7)
                    .offset(x: format.isWide ? w * 0.3 : w * 0.25,
                            y: format.isPortrait ? -h * 0.2 : -h * 0.15)
                Circle()
                    .fill(accent)
                    .opacity(0.05)
                    .frame(width: w * 0.5, height: w * 0.5)
                    .offset(x: -w * 0.25, y: h * 0.3)
            }
        }
    }

    // MARK: - Watermark

    @ViewBuilder
    static func watermark(palette: SharePalette, accent: Color, label: String = "RUN JOURNEY") -> some View {
        Text(label)
            .appText(.eyebrow)
            .foregroundStyle(palette.textMuted.opacity(0.65))
    }
}

// MARK: - Route polyline view

/// `[CLLocationCoordinate2D]` を正方領域内にフィットさせて描画するルートビュー。
/// 緯度・経度を線形にスクリーン座標へ写像する (= 簡易メルカトル相当)。
/// 大量座標は最大 2000 点へ間引き、SwiftUI Path のセグメント数を抑えてレンダリングを軽くする。
struct ShareRoutePath: View {
    let coords: [CLLocationCoordinate2D]
    let accent: Color
    let palette: SharePalette
    /// 線の太さ (描画領域の最小辺 × ratio)。
    var lineWidthRatio: CGFloat = 0.012
    /// グロー有無 (Dark テーマでネオン感を出すために有効、Light は控えめに切る)。
    var glow: Bool = true

    var body: some View {
        GeometryReader { geo in
            let bounds = computeBounds()
            let pad: CGFloat = min(geo.size.width, geo.size.height) * 0.08
            let inner = CGRect(
                x: pad,
                y: pad,
                width: max(geo.size.width - pad * 2, 1),
                height: max(geo.size.height - pad * 2, 1)
            )
            let path = makePath(in: inner, bounds: bounds)
            let lineWidth: CGFloat = max(2.5, min(geo.size.width, geo.size.height) * lineWidthRatio)

            ZStack {
                if glow {
                    path
                        .stroke(accent.opacity(0.45),
                                style: StrokeStyle(lineWidth: lineWidth * 2.6, lineCap: .round, lineJoin: .round))
                        .blur(radius: lineWidth * 0.9)
                }
                path
                    .stroke(accent,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                // 始点 (白丸) / 終点 (アクセント丸)
                if let first = coords.first, let last = coords.last {
                    let p1 = project(first, in: inner, bounds: bounds)
                    let p2 = project(last,  in: inner, bounds: bounds)
                    Circle()
                        .fill(palette.textPrimary)
                        .frame(width: lineWidth * 2.4, height: lineWidth * 2.4)
                        .position(p1)
                    Circle()
                        .fill(accent)
                        .frame(width: lineWidth * 2.4, height: lineWidth * 2.4)
                        .position(p2)
                }
            }
        }
    }

    // MARK: bounds & projection

    private struct LatLngBounds {
        let minLat: Double; let maxLat: Double
        let minLng: Double; let maxLng: Double
        var latSpan: Double { max(maxLat - minLat, 0.0001) }
        var lngSpan: Double { max(maxLng - minLng, 0.0001) }
    }

    private func computeBounds() -> LatLngBounds {
        guard !coords.isEmpty else {
            return LatLngBounds(minLat: 0, maxLat: 1, minLng: 0, maxLng: 1)
        }
        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLng = coords[0].longitude
        var maxLng = coords[0].longitude
        for c in coords {
            if c.latitude  < minLat { minLat = c.latitude  }
            if c.latitude  > maxLat { maxLat = c.latitude  }
            if c.longitude < minLng { minLng = c.longitude }
            if c.longitude > maxLng { maxLng = c.longitude }
        }
        return LatLngBounds(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng)
    }

    private func project(_ c: CLLocationCoordinate2D, in rect: CGRect, bounds: LatLngBounds) -> CGPoint {
        // アスペクト保持: 緯度/経度の長辺で揃えてから centering する。
        let scale = min(rect.width / bounds.lngSpan, rect.height / bounds.latSpan)
        let originX = rect.minX + (rect.width  - bounds.lngSpan * scale) / 2
        let originY = rect.minY + (rect.height - bounds.latSpan * scale) / 2
        let x = originX + (c.longitude - bounds.minLng) * scale
        let y = originY + (bounds.maxLat - c.latitude) * scale
        return CGPoint(x: x, y: y)
    }

    private func makePath(in rect: CGRect, bounds: LatLngBounds) -> Path {
        var path = Path()
        guard coords.count >= 2 else { return path }
        let step = max(1, coords.count / 2000)
        var first = true
        var i = 0
        while i < coords.count {
            let p = project(coords[i], in: rect, bounds: bounds)
            if first { path.move(to: p); first = false } else { path.addLine(to: p) }
            i += step
        }
        // 最終点を必ず含める
        let last = project(coords[coords.count - 1], in: rect, bounds: bounds)
        path.addLine(to: last)
        return path
    }
}

// MARK: - Race pin field (for map overall share)

/// 緯度経度群を 2D 平面に正規化して描画する「マップ風」ピン散布図。
/// Mapbox のタイル取得は使わず、簡易メルカトルでカテゴリ色のドットだけ並べる。
struct SharePinField: View {
    struct Pin: Identifiable {
        let id = UUID()
        let coord: CLLocationCoordinate2D
        let color: Color
    }
    let pins: [Pin]
    let palette: SharePalette
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let bounds = computeBounds()
            let pad: CGFloat = min(geo.size.width, geo.size.height) * 0.08
            let inner = CGRect(
                x: pad,
                y: pad,
                width: max(geo.size.width - pad * 2, 1),
                height: max(geo.size.height - pad * 2, 1)
            )

            ZStack {
                // フィールド枠 (薄い)
                RoundedRectangle(cornerRadius: 18)
                    .stroke(palette.border, lineWidth: 1)
                    .padding(8)

                // ピン
                ForEach(pins) { pin in
                    let p = project(pin.coord, in: inner, bounds: bounds)
                    Circle()
                        .fill(pin.color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(palette.bgPrimary, lineWidth: 2)
                        )
                        .shadow(color: pin.color.opacity(0.55), radius: 4)
                        .position(p)
                }
            }
        }
    }

    private struct LatLngBounds {
        let minLat: Double; let maxLat: Double
        let minLng: Double; let maxLng: Double
        var latSpan: Double { max(maxLat - minLat, 0.001) }
        var lngSpan: Double { max(maxLng - minLng, 0.001) }
    }

    private func computeBounds() -> LatLngBounds {
        guard let first = pins.first?.coord else {
            return LatLngBounds(minLat: 0, maxLat: 1, minLng: 0, maxLng: 1)
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLng = first.longitude
        var maxLng = first.longitude
        for p in pins {
            let c = p.coord
            if c.latitude  < minLat { minLat = c.latitude  }
            if c.latitude  > maxLat { maxLat = c.latitude  }
            if c.longitude < minLng { minLng = c.longitude }
            if c.longitude > maxLng { maxLng = c.longitude }
        }
        // 単一点でも見栄え良くするため最小スパンを保証
        let latPad = max((maxLat - minLat) * 0.15, 0.05)
        let lngPad = max((maxLng - minLng) * 0.15, 0.05)
        return LatLngBounds(
            minLat: minLat - latPad, maxLat: maxLat + latPad,
            minLng: minLng - lngPad, maxLng: maxLng + lngPad
        )
    }

    private func project(_ c: CLLocationCoordinate2D, in rect: CGRect, bounds: LatLngBounds) -> CGPoint {
        let scale = min(rect.width / bounds.lngSpan, rect.height / bounds.latSpan)
        let originX = rect.minX + (rect.width  - bounds.lngSpan * scale) / 2
        let originY = rect.minY + (rect.height - bounds.latSpan * scale) / 2
        let x = originX + (c.longitude - bounds.minLng) * scale
        let y = originY + (bounds.maxLat - c.latitude) * scale
        return CGPoint(x: x, y: y)
    }
}
