import SwiftUI

@main
struct MacMojiApp: App {
    var body: some Scene {
        MenuBarExtra("MacMoji", systemImage: "face.smiling") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
