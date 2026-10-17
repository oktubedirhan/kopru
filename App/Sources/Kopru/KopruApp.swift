import SwiftUI

@main
struct KopruApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Köprü") {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 520)
                .task {
                    model.start()
                    if let path = WindowSnapshot.requestedPath {
                        try? await Task.sleep(for: .seconds(5))
                        WindowSnapshot.save(to: path)
                    }
                }
        }

        Settings {
            SettingsView().environment(model)
        }
    }
}
