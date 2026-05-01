import SwiftUI
import SwiftData

@main
struct RunJourneyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Race.self,
            RaceResult.self,
        ])
        // MVP初期はローカルのみ。Apple Developer Program加入後に
        // ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.kn-nakamura.RunJourney"))
        // へ切り替えてiCloud同期を有効化する。
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)        // Webアプリと同じダークテーマ固定
                .tint(.accentPrimary)               // 蛍光イエローグリーン (#E8FF47)
                .background(Color.bgPrimary)
        }
        .modelContainer(sharedModelContainer)
    }
}
