import SwiftUI

@main
struct K589ConfigApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Redragon K589 Config") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
