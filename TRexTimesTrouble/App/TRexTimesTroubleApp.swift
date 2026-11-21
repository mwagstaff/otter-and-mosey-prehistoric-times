import SwiftUI
import TimesTroubleCore

@main
struct TRexTimesTroubleApp: App {
    @State private var model: AppModel

    init() {
        #if DEBUG
        // UI regression fixtures have their own save, including across a test relaunch.
        let env = ProcessInfo.processInfo.environment
        if let id = env["CAMP_TEST_ID"].flatMap(UUID.init(uuidString:)),
           let encoded = env["CAMP_TEST_SAVE"], let data = Data(base64Encoded: encoded),
           let seed = try? SaveMigrator.load(data) {
            let store = SaveStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(id.uuidString))
            if !FileManager.default.fileExists(atPath: store.fileURL.path) { try? store.save(seed) }
            _model = State(initialValue: AppModel(store: store))
            return
        }
        #endif
        _model = State(initialValue: AppModel())
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                // Progress is flushed to disk whenever the app leaves the foreground.
                model.persistNow()
                AudioManager.shared.pauseForBackground()
                Narrator.shared.stop()
            case .active:
                AudioManager.shared.resumeFromBackground()
            @unknown default:
                break
            }
        }
    }
}
