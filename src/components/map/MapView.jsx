/**
 * MapView.jsx
 * 
 * Leafletを使った地図表示コンポーネント
 */

import React, { useMemo } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { formatDateShort } from '../../utils/dateFormat';
import { calculatePace } from '../../utils/timeUtils';

// マーカーアイコンの修正（Leafletのデフォルトアイコンパス問題を解決）
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

/**
 * カスタムマーカーアイコンを作成
 * @param {string} color - マーカーの色
 */
const createCustomIcon = (color) => {
  const svgIcon = `
    <svg width="25" height="41" viewBox="0 0 25 41" xmlns="http://www.w3.org/2000/svg">
      <path d="M12.5 0C5.596 0 0 5.596 0 12.5c0 9.375 12.5 28.125 12.5 28.125S25 21.875 25 12.5C25 5.596 19.404 0 12.5 0z" fill="${color}"/>
      <circle cx="12.5" cy="12.5" r="5" fill="white"/>
    </svg>
  `;
  
  return L.divIcon({
    html: svgIcon,
    className: 'custom-marker',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34],
  });
};

/**
 * 地図の中心とズームを調整するコンポーネント
 */
const MapController = ({ marathons }) => {
  const map = useMap();

  React.useEffect(() => {
    if (marathons.length > 0) {
      const bounds = marathons.map((m) => [m.location.lat, m.location.lng]);
      if (bounds.length === 1) {
        map.setView(bounds[0], 10);
      } else {
        map.fitBounds(bounds, { padding: [50, 50] });
      }
    }
  }, [marathons, map]);

  return null;
};

/**
 * MapViewコンポーネント
 * @param {Object} props
 * @param {Array} props.marathons - マラソンデータの配列
 * @param {Function} props.onMarkerClick - マーカークリック時のハンドラ
 */
export const MapView = ({ marathons, onMarkerClick }) => {
  const defaultCenter = [35.6812, 139.7671]; // 東京
  const defaultZoom = 5;

  // マーカーアイコンをメモ化
  const pbIcon = useMemo(() => createCustomIcon('#FFD700'), []);
  const sbIcon = useMemo(() => createCustomIcon('#C0C0C0'), []);
  const normalIcon = useMemo(() => createCustomIcon('#3b82f6'), []);

  return (
    <div className="h-full w-full rounded-xl overflow-hidden shadow-lg">
      <MapContainer
        center={defaultCenter}
        zoom={defaultZoom}
        style={{ height: '100%', width: '100%' }}
        className="z-0"
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        <MapController marathons={marathons} />

        {marathons.map((marathon) => {
          // マーカーの色を決定
          let icon = normalIcon;
          if (marathon.isPB) icon = pbIcon;
          else if (marathon.isSB) icon = sbIcon;

          return (
            <Marker
              key={marathon.id}
              position={[marathon.location.lat, marathon.location.lng]}
              icon={icon}
              eventHandlers={{
                click: () => onMarkerClick && onMarkerClick(marathon),
              }}
            >
              <Popup>
                <div className="p-2 min-w-[200px]">
                  <div className="flex items-center gap-2 mb-2">
                    {marathon.isPB && <span className="text-yellow-500 font-bold">🏆 PB</span>}
                    {marathon.isSB && !marathon.isPB && (
                      <span className="text-gray-400 font-bold">📅 SB</span>
                    )}
                    <h3 className="font-bold text-lg">{marathon.name}</h3>
                  </div>
                  <div className="space-y-1 text-sm">
                    <p>📅 {formatDateShort(marathon.date)}</p>
                    <p>📏 {marathon.distance}km</p>
                    <p>⏱️ {marathon.time}</p>
                    <p>📊 ペース: {calculatePace(marathon.time, marathon.distance)}/km</p>
                    {marathon.rank && <p>🏅 {marathon.rank}位</p>}
                    {marathon.weather && (
                      <p>{marathon.weather.icon} {marathon.weather.description}</p>
                    )}
                  </div>
                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>
    </div>
  );
};
