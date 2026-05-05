#if os(iOS)
import SwiftUI
import SwiftData
import MapKit

/// マップ操作用のズーム命令。SwiftUI 親が `requestedZoom` バインディングをセットすると、
/// `RaceListMapView.updateUIView` が現在のリージョンに対して係数倍率で `setRegion` を呼ぶ。
enum MapZoomCommand: Equatable { case `in`, out }

/// レース一覧用の MKMapView ラッパー。
///
/// SwiftUI 標準の `Map` ビュー（iOS 17+）は **iOS 26 でタブバーアピアランスを内部的に
/// 壊し、MAP タブだけタブラベル書体がシステムフォントに戻る不具合**を起こすため使えない。
/// MKMapView を `UIViewRepresentable` で直接ラップするとこの副作用が消える。
///
/// ピンの見た目は SwiftUI `RaceAnnotationView` を `ImageRenderer` で UIImage 化して
/// 各 `MKAnnotationView.image` に流し込んでいるので、`PinSettings` の Shape / SymbolMode /
/// ColorSource / Size / Border はすべて反映される。`showName` だけは座標アンカー計算が
/// 複雑になるため snapshot 時に無効化している（ピンタップ時はシートが開くので冗長）。
struct RaceListMapView: UIViewRepresentable {
    let races: [Race]
    /// ピンタップで親に伝える「カメラを動かしたい対象」。シート表示用 `sheetRace`、
    /// ピン拡大用 `iconifiedRace` とは分離。
    @Binding var selectedRace: Race?
    /// 拡大＋アイコン化されるピンの対象レース。親側でズーム & シート出現が
    /// 終わってから少し置いてセットされる。これに合わせてピン画像が
    /// クロスフェードで切り替わる。
    let iconifiedRace: Race?
    /// 親から要求された一回限りのカメラ region 変更。`nil` = 何もしない。
    /// 反映後はバインディング側で `nil` に戻す。
    @Binding var requestedRegion: MKCoordinateRegion?
    /// region をマップビュー全体ではなく **上半分** にフィットさせるか。
    /// `true` のとき bottom edge padding をマップ高さの半分にして、region 中心が
    /// 画面上半分の中央に来るようにする (ピンタップ → ズーム時に使う)。
    /// `false` (既定) は四方均等パディングで通常フィット。
    var requestedRegionUpperHalf: Bool = false
    /// 親から要求された一回限りのズーム指示。`in`/`out` に応じて現在 region の span を
    /// 半分/倍にして `setRegion` する。反映後は nil に戻す。
    @Binding var requestedZoom: MapZoomCommand?
    /// 現在の地図中心座標 (任意)。指定時は `regionDidChangeAnimated` で逐次更新される。
    /// AddRaceSheet 等が「現在の視点」を初期地点にしたいときに使う。
    var currentCenter: Binding<CLLocationCoordinate2D>? = nil
    let mapSettings: MapStyleSettings
    let pinSettings: PinSettings

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = false
        mapView.preferredConfiguration = mapSettings.mapConfiguration
        // 起動時の region は親が onAppear で fitAllRaces を呼ぶ想定。
        // ここではデフォルトとして日本全体を仮置きする。
        mapView.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 138.0),
            span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 13.0)
        ), animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // マップスタイル
        mapView.preferredConfiguration = mapSettings.mapConfiguration

        // 状態変更検知用に最新値を保持。`mapView(_:viewFor:)` から参照される。
        context.coordinator.parent = self

        // adaptive モード切替を検出。cluster ↔ 非cluster 遷移時のみ MapKit に
        // 再クラスタリングを促すため既存 RaceAnnotation を一旦全消去して、
        // 直後の diff 追加で再投入する。`clusteringIdentifier` は viewFor で
        // 再付与される。off ↔ zoom ↔ density 間の遷移ではピン view を保持
        // したまま applyImage の差し替えだけで済むため再生成しない (フリッカ防止)。
        let prevMode = context.coordinator.lastAdaptiveMode
        let curMode = pinSettings.adaptiveSizing
        let clusterToggled = (prevMode == .cluster) != (curMode == .cluster)
        if clusterToggled {
            let existing = mapView.annotations.compactMap { $0 as? RaceAnnotation }
            mapView.removeAnnotations(existing)
        }
        context.coordinator.lastAdaptiveMode = curMode

        // アノテーション diff: 既存と現 races の差分だけ反映する。
        // 全消し再追加だと選択中ピンが消えて再生されてフリッカーするので diff 方式。
        let existingByID = Dictionary(
            uniqueKeysWithValues: mapView.annotations
                .compactMap { $0 as? RaceAnnotation }
                .map { ($0.race.persistentModelID, $0) }
        )
        let currentIDs = Set(races.map(\.persistentModelID))
        let stale = existingByID.filter { !currentIDs.contains($0.key) }.map(\.value)
        mapView.removeAnnotations(stale)

        let existingIDs = Set(existingByID.keys)
        let newAnnotations = races
            .filter { !existingIDs.contains($0.persistentModelID) }
            .map { RaceAnnotation(race: $0) }
        mapView.addAnnotations(newAnnotations)

        // adaptive モード固有の事前計算 (zoom 係数 / density スケール)。
        // applyImage はこのキャッシュを参照する。
        context.coordinator.refreshAdaptiveState(mapView: mapView)

        // 既存ピンの image を最新の状態 (selectedRace / pinSettings) で更新する。
        for annotation in mapView.annotations {
            guard let raceAnno = annotation as? RaceAnnotation,
                  let view = mapView.view(for: annotation) else { continue }
            context.coordinator.applyImage(to: view, for: raceAnno)
        }

        // 親が要求した region 変更があれば反映。
        // upperHalf=true のときは bottom 余白をマップ高さの半分にして、ピンを
        // 画面上半分の中央へ寄せる (ピンタップ後のシートに隠れない位置に置く)。
        // それ以外は四方均等パディングで通常フィット。
        if let region = requestedRegion {
            let mapRect = Self.makeMapRect(region: region)
            let bottom: CGFloat = requestedRegionUpperHalf
                ? max(mapView.bounds.height / 2, 32)
                : 32
            let padding = UIEdgeInsets(top: 32, left: 32, bottom: bottom, right: 32)
            if requestedRegionUpperHalf {
                // ピンへの近接ズーム (fitRace) のときだけ MapKit 既定の硬いカーブを上書きし、
                // 1.6 秒の easeInOut にする。`animated: true` のまま `UIView.animate` で
                // 囲うと、その duration / curve が implicit にマップアニメへ反映される。
                UIView.animate(
                    withDuration: 1.6,
                    delay: 0,
                    options: [.curveEaseInOut, .beginFromCurrentState],
                    animations: {
                        mapView.setVisibleMapRect(mapRect, edgePadding: padding, animated: true)
                    },
                    completion: nil
                )
            } else {
                mapView.setVisibleMapRect(mapRect, edgePadding: padding, animated: true)
            }
            DispatchQueue.main.async {
                self.requestedRegion = nil
            }
        }

        // 親が要求したズーム命令を適用。現在 region の span を係数倍 (0.5 / 2.0) して
        // setRegion(animated:) する。係数は MKMapView の最小・最大 span に丸められる。
        if let zoom = requestedZoom {
            var region = mapView.region
            let factor: CLLocationDegrees = (zoom == .in) ? 0.5 : 2.0
            region.span = MKCoordinateSpan(
                latitudeDelta: max(0.0008, min(170, region.span.latitudeDelta * factor)),
                longitudeDelta: max(0.0008, min(170, region.span.longitudeDelta * factor))
            )
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async {
                self.requestedZoom = nil
            }
        }
    }

    /// `MKCoordinateRegion` (center+span) を `MKMapRect` に変換する。
    /// `setVisibleMapRect:edgePadding:animated:` は `MKMapRect` を要求するため。
    private static func makeMapRect(region: MKCoordinateRegion) -> MKMapRect {
        let topLeft = CLLocationCoordinate2D(
            latitude: region.center.latitude + region.span.latitudeDelta / 2,
            longitude: region.center.longitude - region.span.longitudeDelta / 2
        )
        let bottomRight = CLLocationCoordinate2D(
            latitude: region.center.latitude - region.span.latitudeDelta / 2,
            longitude: region.center.longitude + region.span.longitudeDelta / 2
        )
        let topLeftPoint = MKMapPoint(topLeft)
        let bottomRightPoint = MKMapPoint(bottomRight)
        return MKMapRect(
            x: min(topLeftPoint.x, bottomRightPoint.x),
            y: min(topLeftPoint.y, bottomRightPoint.y),
            width: abs(bottomRightPoint.x - topLeftPoint.x),
            height: abs(bottomRightPoint.y - topLeftPoint.y)
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RaceListMapView

        /// 直前に適用した adaptive モード。`updateUIView` でモード切替を検出して
        /// クラスタリング状態を作り直すために使う。
        var lastAdaptiveMode: PinSettings.AdaptiveSizing? = nil
        /// zoom モード時の現在スケール係数 (1.0 = 通常)。`applyImage` が参照する。
        var lastZoomScale: CGFloat = 1.0
        /// density モード時のピン毎のスケール係数 (1.0 = 通常)。
        var perPinScale: [PersistentIdentifier: CGFloat] = [:]

        init(parent: RaceListMapView) {
            self.parent = parent
        }

        // MARK: Annotation views

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // cluster モードで MapKit が生成する集約アノテーション。
            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "RaceCluster"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? MKAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                view.annotation = cluster
                view.canShowCallout = false
                view.displayPriority = .required
                applyClusterImage(to: view, count: cluster.memberAnnotations.count)
                return view
            }

            guard let raceAnno = annotation as? RaceAnnotation else { return nil }
            let identifier = "RacePin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? RacePinAnnotationView)
                ?? RacePinAnnotationView(annotation: raceAnno, reuseIdentifier: identifier)
            view.annotation = raceAnno
            view.canShowCallout = false
            view.displayPriority = .required
            // cluster モード時のみ clusteringIdentifier をセットして MapKit に集約を委ねる。
            view.clusteringIdentifier = (parent.pinSettings.adaptiveSizing == .cluster) ? "race" : nil
            applyImage(to: view, for: raceAnno)
            return view
        }

        /// 現在の `iconifiedRace` / `pinSettings` で SwiftUI `RaceAnnotationView` を
        /// 描画して `MKAnnotationView.image` に流し込む。アンカー位置も pin 形状で調整。
        ///
        /// `isSelected` のソースは `selectedRace` でも `sheetRace` でもなく
        /// `iconifiedRace` を使う。親側でズーム → シート → 1 秒待ってから
        /// `iconifiedRace` がセットされるので、その瞬間にだけピンがアイコンへ変化する。
        ///
        /// 画像とアンカーは即時差し替える。クロスフェード等のトランジションは挟まない:
        /// 選択時は image / centerOffset / bounds が同時に大きく変わるため、UIView.transition
        /// でスナップショットを撮ると新旧画像のサイズ差ぶん「アイコンが右からスライドして
        /// 出る」ような視覚ズレが発生していた。
        func applyImage(to view: MKAnnotationView, for raceAnno: RaceAnnotation) {
            let isSelected = parent.iconifiedRace?.persistentModelID == raceAnno.race.persistentModelID
            let settings = parent.pinSettings
            // ImageRenderer は SwiftUI の `.shadow()` を view bounds の外側に少し溢れさせるので、
            // 透明 padding を被せて切れないようにする。これは shadow 用の最小余白。
            // (透明 padding を大きくすると MKMapView の hit-test が隣ピンに乗り上げて
            // 「タップしたピンと違うレースが選ばれる」バグの原因になるため、shadow 用に
            // 必要な分だけ最小化する。)
            //
            // cluster モードのときだけ padding をほぼ 0 にする。MKMapView 標準クラスタリングは
            // annotation view の image size 同士が overlap したかで判定するため、透明 padding を
            // 持たせると北海道〜九州まで 1 クラスタに丸めてしまう。shadow がわずかに欠けるが、
            // クラスタモードはピン密集時の代替表示なので許容範囲。
            let padding: CGFloat = (settings.adaptiveSizing == .cluster) ? 1 : 6

            // 可視サイズ: 非選択時 = `dimension`, 選択時 = `selectedDimension`。
            // canvas は可視ピン + (選択時のみ) ラベル領域に絞る。これで MKAnnotationView の
            // frame (= image size) が実際のピン外形にほぼ一致し、隣接ピンの hit area が
            // 透明領域に被られることがなくなる。
            //
            // adaptive モード時は非選択ピンに対して scale 係数を掛ける。選択中ピンは
            // タップ反応として常に selectedDimension のフルサイズを保つ。
            let baseDim: CGFloat = isSelected ? settings.size.selectedDimension : settings.size.dimension
            let adaptiveScale: CGFloat
            if isSelected {
                adaptiveScale = 1.0
            } else {
                switch settings.adaptiveSizing {
                case .off, .cluster: adaptiveScale = 1.0
                case .zoom:          adaptiveScale = lastZoomScale
                case .density:       adaptiveScale = perPinScale[raceAnno.race.persistentModelID] ?? 1.0
                }
            }
            let visibleDim: CGFloat = baseDim * adaptiveScale
            let visibleH: CGFloat = (settings.shape == .pin) ? visibleDim * 1.35 : visibleDim

            let labelExtra: CGFloat = (isSelected && settings.showName) ? (4 + RaceAnnotationView.labelReservedHeight) : 0
            // 選択中＆ラベル ON のときだけ canvas 幅を広げる (英字 ~14 文字想定)。
            let canvasW: CGFloat = (isSelected && settings.showName) ? max(visibleDim, 140) : visibleDim
            let canvasH: CGFloat = visibleH + labelExtra

            let swiftUIView = RaceAnnotationView(
                race: raceAnno.race,
                isSelected: isSelected,
                settings: settings,
                dimensionOverride: visibleDim
            )
            .frame(width: canvasW, height: canvasH, alignment: .top)
            .padding(padding)
            let renderer = ImageRenderer(content: swiftUIView)
            renderer.scale = view.traitCollection.displayScale
            guard let image = renderer.uiImage else { return }

            // shape のアンカー (pin = 尖り先 / dot = 中心) を地図座標に合わせる。
            //   公式: centerOffset.y = imageH/2 - anchorY_in_image
            //     centerOffset.y > 0 → view 中心が coord の下 (画面 y は下が正)
            // shape は canvas の最上段に貼り付く。
            //   pin (teardrop): tip = padding + visibleH (shape の底辺)
            //   dot/ring/square: 中心 = padding + visibleH/2
            let imageH: CGFloat = image.size.height
            let imageW: CGFloat = image.size.width
            let anchorY: CGFloat
            if settings.shape == .pin {
                anchorY = padding + visibleH
            } else {
                anchorY = padding + visibleH / 2
            }
            let centerOffsetY: CGFloat = imageH / 2 - anchorY
            let newCenterOffset = CGPoint(x: 0, y: centerOffsetY)

            // 画像とアンカーは即時差し替える (トランジションなし)。
            // UIKit / MapKit の暗黙的アニメーション (bounds 変化によるスライド効果) を
            // 抑止するため performWithoutAnimation で囲む。
            UIView.performWithoutAnimation {
                view.image = image
                view.centerOffset = newCenterOffset
            }

            // hit-test 矩形: 透明 padding を除いた、実際の可視ピン本体。
            // canvas が可視ピンサイズに絞られているので、image 全面 (= view bounds) も
            // ほぼ可視ピン外形になる。それでも 6pt の shadow padding ぶん隣に乗り上げる
            // 余地は残るので、point(inside:) で更にタイトに絞る。
            let hitOriginX: CGFloat = imageW / 2 - visibleDim / 2
            let hitOriginY: CGFloat
            if settings.shape == .pin {
                hitOriginY = anchorY - visibleH
            } else {
                hitOriginY = anchorY - visibleH / 2
            }
            (view as? RacePinAnnotationView)?.visibleHitRect = CGRect(
                x: hitOriginX,
                y: hitOriginY,
                width: visibleDim,
                height: visibleH
            )
        }

        // MARK: Region

        /// 地図の region 変更が落ち着いたタイミングで親 (SwiftUI) に現在中心を返す。
        /// `currentCenter` バインディングが指定されているときだけ通知する。
        /// AddRaceSheet 等で「いま見えている視点」を初期地点に使うのに利用。
        ///
        /// adaptive モード (zoom / density) のときは、ここで scale を再計算して
        /// 必要なら全ピンを再描画する。`regionDidChangeAnimated` はジェスチャ完了時
        /// に 1 回だけ呼ばれるので、ピンチ中の連続呼び出しによるスループット低下は
        /// 起きない。
        nonisolated func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.region.center
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.currentCenter?.wrappedValue = center
                self.handleRegionChanged(mapView: mapView)
            }
        }

        // MARK: Adaptive sizing

        /// region 変動時のスケール再計算 + 必要なら全ピン再描画。
        private func handleRegionChanged(mapView: MKMapView) {
            switch parent.pinSettings.adaptiveSizing {
            case .off, .cluster:
                return
            case .zoom:
                let span = mapView.region.span.latitudeDelta
                let newScale = Self.zoomScale(span: span)
                guard newScale != lastZoomScale else { return }
                lastZoomScale = newScale
                reapplyAllPinImages(mapView: mapView)
            case .density:
                recomputeDensity(mapView: mapView)
                reapplyAllPinImages(mapView: mapView)
            }
        }

        /// `updateUIView` 末尾から呼ばれる事前計算。adaptive モードに応じて
        /// `lastZoomScale` または `perPinScale` を最新化する。
        func refreshAdaptiveState(mapView: MKMapView) {
            switch parent.pinSettings.adaptiveSizing {
            case .off, .cluster:
                lastZoomScale = 1.0
                perPinScale.removeAll()
            case .zoom:
                lastZoomScale = Self.zoomScale(span: mapView.region.span.latitudeDelta)
                perPinScale.removeAll()
            case .density:
                lastZoomScale = 1.0
                recomputeDensity(mapView: mapView)
            }
        }

        /// 既存ピン全ての image を最新の adaptive スケールで再描画する。
        /// 新規追加直後のピンは `mapView.view(for:)` がまだ nil を返す可能性が
        /// あるが、それらは MapKit が改めて `viewFor` を呼んで `applyImage` を
        /// 通すのでこのループでは触れなくて問題ない。
        private func reapplyAllPinImages(mapView: MKMapView) {
            for anno in mapView.annotations {
                guard let raceAnno = anno as? RaceAnnotation,
                      let view = mapView.view(for: anno) else { continue }
                applyImage(to: view, for: raceAnno)
            }
        }

        /// `latitudeDelta` を 5 段階の tier に snap して scale 係数を返す。
        /// tier snap によりピンチ中の細かい region 変動でも tier 跨ぎ時しか
        /// ピン再描画が走らない。
        ///   ~0.02° (街区) → 1.00x
        ///   ~0.2°  (市)   → 0.85x
        ///   ~2°    (県)   → 0.70x
        ///   ~10°   (地方) → 0.55x
        ///   それ以上 (国全体) → 0.45x
        static func zoomScale(span: CLLocationDegrees) -> CGFloat {
            switch span {
            case ..<0.02:  return 1.00
            case ..<0.2:   return 0.85
            case ..<2.0:   return 0.70
            case ..<10.0:  return 0.55
            default:       return 0.45
            }
        }

        /// density モード: 各ピンを 80×80pt のスクリーン格子バケットに割り当て、
        /// 自セル + 周辺 8 セル合計の件数から scale を決める。O(N) で 200+ ピン
        /// でも毎回 region 変更時に走らせて問題ない。
        private func recomputeDensity(mapView: MKMapView) {
            perPinScale.removeAll()
            let cellSize: CGFloat = 80
            struct GridKey: Hashable { let x: Int; let y: Int }
            var grid: [GridKey: Int] = [:]
            var pinCells: [(PersistentIdentifier, GridKey)] = []
            pinCells.reserveCapacity(mapView.annotations.count)
            for anno in mapView.annotations {
                guard let raceAnno = anno as? RaceAnnotation else { continue }
                let pt = mapView.convert(raceAnno.coordinate, toPointTo: mapView)
                let key = GridKey(x: Int(floor(pt.x / cellSize)), y: Int(floor(pt.y / cellSize)))
                grid[key, default: 0] += 1
                pinCells.append((raceAnno.race.persistentModelID, key))
            }
            for (id, key) in pinCells {
                var count = 0
                for dx in -1...1 {
                    for dy in -1...1 {
                        count += grid[GridKey(x: key.x + dx, y: key.y + dy)] ?? 0
                    }
                }
                let scale: CGFloat
                switch count {
                case ...1:   scale = 1.0
                case 2...3:  scale = 0.75
                case 4...7:  scale = 0.55
                default:     scale = 0.40
                }
                perPinScale[id] = scale
            }
        }

        /// cluster モードで MapKit が生成する `MKClusterAnnotation` 用の image を
        /// SwiftUI `RaceClusterAnnotationView` から ImageRenderer で生成する。
        private func applyClusterImage(to view: MKAnnotationView, count: Int) {
            let padding: CGFloat = 6
            let dim: CGFloat = 44
            let swiftUI = RaceClusterAnnotationView(count: count)
                .frame(width: dim, height: dim)
                .padding(padding)
            let renderer = ImageRenderer(content: swiftUI)
            renderer.scale = view.traitCollection.displayScale
            guard let image = renderer.uiImage else { return }
            view.image = image
            view.centerOffset = .zero
        }

        // MARK: Selection

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let raceAnno = view.annotation as? RaceAnnotation else { return }
            // 親 SwiftUI 状態を更新。次のランループで sheet が開く。
            DispatchQueue.main.async {
                self.parent.selectedRace = raceAnno.race
            }
            // MKMapView 側の selection は即座に解除して、再タップ時にもう一度
            // didSelect が走るようにしておく (sheet 閉じた後の挙動を素直にする)。
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
    }
}

// MARK: - RacePinAnnotationView

/// `MKAnnotationView` のサブクラス。タップ判定を「実際に見えているピンの矩形」だけに
/// 絞る。`point(inside:with:)` と `hitTest(_:with:)` の両方を override する:
/// - `point(inside:)` は UIKit ヒット判定の標準 API。
/// - `hitTest(_:)` は MKMapView 内部の annotation ピックアップが直接呼ぶ場合に備える。
/// 両者を上書きすることで、image の透明 padding 領域が隣接ピンのタップを横取りしないよう
/// 二重に防御する。
private final class RacePinAnnotationView: MKAnnotationView {
    /// 可視ピンの bounding rect (本ビューの bounds 座標系)。
    /// `.null` のときは super の挙動に委譲する。
    var visibleHitRect: CGRect = .null

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if visibleHitRect.isNull {
            return super.point(inside: point, with: event)
        }
        return visibleHitRect.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if visibleHitRect.isNull {
            return super.hitTest(point, with: event)
        }
        // 可視矩形外は nil を返して、隣接ピンや地図本体側にタップを譲る。
        return visibleHitRect.contains(point) ? self : nil
    }
}

// MARK: - Annotation model

final class RaceAnnotation: NSObject, MKAnnotation {
    let race: Race
    init(race: Race) { self.race = race }
    var coordinate: CLLocationCoordinate2D { race.coordinate }
    var title: String? { race.name.isEmpty ? "Race" : race.name }
}
#endif
