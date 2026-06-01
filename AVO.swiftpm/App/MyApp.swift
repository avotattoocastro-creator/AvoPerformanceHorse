import SwiftUI
import UIKit

@main
struct AvoPerformanceApp: App {
    var body: some Scene {
        WindowGroup {
            AVORootLauncherShell()
                .preferredColorScheme(.dark)
        }
    }
}
