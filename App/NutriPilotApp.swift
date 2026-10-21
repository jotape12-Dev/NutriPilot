import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif
#if canImport(NutriPilotApp)
import NutriPilotApp
#endif

@main
struct NutriPilotMainApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
