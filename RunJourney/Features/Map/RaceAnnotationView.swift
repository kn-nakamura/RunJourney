import SwiftUI

/// 地図上のレースピン1個分のビジュアル。カテゴリ色 + SF Symbol。
struct RaceAnnotationView: View {
    let race: Race
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(race.category.pinColor)
                    .frame(width: isSelected ? 44 : 32, height: isSelected ? 44 : 32)
                    .shadow(radius: 3)
                Image(systemName: race.category.symbolName)
                    .foregroundStyle(.white)
                    .font(.system(size: isSelected ? 22 : 16, weight: .semibold))
            }
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 2)
            )
            .animation(.spring(response: 0.3), value: isSelected)

            if isSelected {
                Text(race.name)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule())
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    let dummy = Race(name: "東京マラソン", category: .fullMarathon, lat: 35.69, lng: 139.69)
    return VStack(spacing: 20) {
        RaceAnnotationView(race: dummy, isSelected: false)
        RaceAnnotationView(race: dummy, isSelected: true)
    }
    .padding()
}
