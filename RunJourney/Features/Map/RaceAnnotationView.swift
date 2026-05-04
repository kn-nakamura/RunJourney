import SwiftUI

/// 地図上のレースピン1個分のビジュアル。`PinSettings` で見た目を切替可能。
struct RaceAnnotationView: View {
    let race: Race
    var isSelected: Bool = false
    var settings: PinSettings = .default

    var body: some View {
        VStack(spacing: 4) {
            // shape は自然なサイズ (isSelected で大きさが変わる) で描画する。
            // 透明 padding でキャンバスを膨らませると MKMapView の annotation hit-test が
            // 隣ピンに乗り上げてしまうため、コンテナはここで作らず applyImage 側で
            // ImageRenderer の `.padding()` (= shadow 余白 8pt) のみに留める。
            shape

            if isSelected && settings.showName {
                Text(race.name.isEmpty ? "Race" : race.name)
                    .font(.caption2.bold())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.bgPrimary.opacity(0.82))
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.accentPrimary.opacity(0.55), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }

    /// showName 時のラベル予約高さ。caption2 (~12pt) + 上下 padding(3+3) + capsule の余裕。
    /// `applyImage` から canvasH 計算で参照する。
    static let labelReservedHeight: CGFloat = 22

    // MARK: - Geometry

    private var dimension: CGFloat {
        isSelected ? settings.size.selectedDimension : settings.size.dimension
    }

    private var fillColor: Color {
        settings.resolvedColor(category: race.category)
    }

    private var symbolForeground: Color {
        switch settings.colorSource {
        case .category, .accent: return .white
        case .mono:              return .black
        }
    }

    private var showsSymbol: Bool {
        switch settings.symbolMode {
        case .never:        return false
        case .selectedOnly: return isSelected
        case .always:       return true
        }
    }

    // MARK: - Shape rendering

    @ViewBuilder
    private var shape: some View {
        switch settings.shape {
        case .dot:    dotShape
        case .ring:   ringShape
        case .pin:    pinShape
        case .square: squareShape
        }
    }

    private var dotShape: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .overlay {
                    if settings.showBorder {
                        Circle().strokeBorder(.white, lineWidth: max(1.5, dimension * 0.09))
                    }
                }
            symbolOverlay
        }
        .frame(width: dimension, height: dimension)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
    }

    private var ringShape: some View {
        ZStack {
            Circle()
                .fill(Color.bgPrimary.opacity(0.55))
            Circle()
                .strokeBorder(fillColor, lineWidth: max(2.5, dimension * 0.18))
            if settings.showBorder {
                Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1)
            }
            symbolOverlay
        }
        .frame(width: dimension, height: dimension)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
    }

    private var squareShape: some View {
        let radius = dimension * 0.22
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fillColor)
                .overlay {
                    if settings.showBorder {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(.white, lineWidth: max(1.5, dimension * 0.09))
                    }
                }
            symbolOverlay
        }
        .frame(width: dimension, height: dimension)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
    }

    /// ティアドロップ型ピン。バルブ＋下に向けて尖るシルエットを単一 Path で描画する。
    private var pinShape: some View {
        let bulbDiameter = dimension
        let totalHeight = bulbDiameter * 1.35
        return ZStack {
            Teardrop()
                .fill(fillColor)
                .overlay {
                    if settings.showBorder {
                        Teardrop().stroke(.white, lineWidth: max(1.5, dimension * 0.09))
                    }
                }
            // シンボルはバルブ部分（上半分）の中心に
            if showsSymbol {
                Image(systemName: race.category.symbolName)
                    .font(.system(size: bulbDiameter * 0.45, weight: .semibold))
                    .foregroundStyle(symbolForeground)
                    .offset(y: -totalHeight * 0.5 + bulbDiameter * 0.5)
            }
        }
        .frame(width: bulbDiameter, height: totalHeight)
        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        // 尖り先がアノテーション座標を指すよう、RaceMapView 側で `anchor: .bottom` を指定している。
    }

    @ViewBuilder
    private var symbolOverlay: some View {
        if showsSymbol {
            Image(systemName: race.category.symbolName)
                .font(.system(size: dimension * 0.5, weight: .semibold))
                .foregroundStyle(symbolForeground)
        }
    }
}

// MARK: - Teardrop path

/// ティアドロップ（雨滴）形状。上半分は円、下半分は接線で尖るシルエット。
struct Teardrop: Shape {
    func path(in rect: CGRect) -> Path {
        let bulbDiameter = rect.width
        let bulbRadius = bulbDiameter / 2
        let bulbCenter = CGPoint(x: rect.midX, y: rect.minY + bulbRadius)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)

        let dy = tip.y - bulbCenter.y
        // tip が円の中に来てしまう異常ケースは円で代用
        guard dy > bulbRadius else {
            return Path(ellipseIn: CGRect(
                x: bulbCenter.x - bulbRadius,
                y: bulbCenter.y - bulbRadius,
                width: bulbDiameter,
                height: bulbDiameter
            ))
        }

        // tip から円への接線がなす中心からの角度 α
        let alpha = asin(bulbRadius / dy)

        var p = Path()
        // 左接点 → 円弧で上を通って右接点 (CCW = clockwise:false で y-down 上回り)
        p.addArc(
            center: bulbCenter,
            radius: bulbRadius,
            startAngle: Angle(radians: .pi - alpha),
            endAngle: Angle(radians: alpha),
            clockwise: false
        )
        // 右接点 → tip → 左接点
        p.addLine(to: tip)
        p.closeSubpath()
        return p
    }
}

// MARK: - Cluster annotation

/// `PinSettings.AdaptiveSizing == .cluster` のとき MapKit が生成する
/// `MKClusterAnnotation` 用のバッジ。集約された件数を中央に表示する。
struct RaceClusterAnnotationView: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentPrimary)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
                }
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.bgPrimary)
                .minimumScaleFactor(0.7)
                .padding(2)
        }
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }
}

#Preview("Pin shapes") {
    let dummy = Race(name: "Tokyo Marathon", category: .fullMarathon, lat: 35.69, lng: 139.69)
    return ScrollView {
        VStack(spacing: 24) {
            ForEach(PinSettings.Shape.allCases) { shape in
                VStack(spacing: 8) {
                    Text(shape.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        RaceAnnotationView(race: dummy, isSelected: false, settings: PinSettings(shape: shape))
                        RaceAnnotationView(race: dummy, isSelected: true, settings: PinSettings(shape: shape))
                    }
                }
            }
        }
        .padding()
    }
    .background(Color.bgPrimary)
}
