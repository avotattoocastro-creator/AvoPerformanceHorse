import SwiftUI
import UIKit
import UserNotifications

@main
struct AvoPerformanceApp: App {
    @UIApplicationDelegateAdaptor(AVOPushAppDelegate.self) private var pushAppDelegate

    var body: some Scene {
        WindowGroup {
            AVORootLauncherShell()
                .preferredColorScheme(.dark)
                .onAppear {
                    AVOTrainingPushBridge.shared.configureNotificationSystem()
                    AVORemotePushManager.shared.configureAndRegister()
                }
        }
    }
}
