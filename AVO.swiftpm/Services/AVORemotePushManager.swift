import Foundation
import UIKit
import UserNotifications

// MARK: - AVO Remote Push Manager
// Native APNs flow: iOS obtains the APNs device token and registers it in the Raspberry backend.
// No Firebase SDK dependency is required inside Swift Playgrounds.

@MainActor
final class AVORemotePushManager: NSObject, ObservableObject {
    static let shared = AVORemotePushManager()

    private let registerURL = URL(string: "https://live.avoperformance.org/api/push/register")!
    private let avoToken = "AVO2026"

    @Published private(set) var permissionGranted: Bool = false
    @Published private(set) var apnsTokenHex: String = UserDefaults.standard.string(forKey: "AVO_APNS_TOKEN_HEX") ?? ""
    @Published private(set) var lastRegisterStatus: String = "PUSH NOT REGISTERED"

    private var didRequestAuthorization = false
    private var didAskRemoteRegistration = false

    private override init() { super.init() }

    func configureAndRegister() {
        guard !didRequestAuthorization else {
            uploadStoredTokenIfAvailable()
            return
        }
        didRequestAuthorization = true

        UNUserNotificationCenter.current().delegate = AVOTrainingPushBridge.shared
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]) { granted, error in
            DispatchQueue.main.async {
                self.permissionGranted = granted
                if let error {
                    self.lastRegisterStatus = "PUSH PERMISSION ERROR: \(error.localizedDescription)"
                    return
                }

                if granted {
                    self.lastRegisterStatus = "PUSH PERMISSION OK"
                    self.registerForRemoteNotificationsOnce()
                } else {
                    self.lastRegisterStatus = "PUSH PERMISSION DENIED"
                }
            }
        }
    }

    func registerForRemoteNotificationsOnce() {
        guard !didAskRemoteRegistration else { return }
        didAskRemoteRegistration = true
        UIApplication.shared.registerForRemoteNotifications()
    }

    func updateDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        apnsTokenHex = token
        UserDefaults.standard.set(token, forKey: "AVO_APNS_TOKEN_HEX")
        print("APNS TOKEN:", token)
        Task { await uploadToken(token) }
    }

    func uploadStoredTokenIfAvailable() {
        guard !apnsTokenHex.isEmpty else { return }
        Task { await uploadToken(apnsTokenHex) }
    }

    private func uploadToken(_ token: String) async {
        var request = URLRequest(url: registerURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(avoToken, forHTTPHeaderField: "X-AVO-TOKEN")

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UserDefaults.standard.string(forKey: "AVO_DEVICE_ID") ?? UUID().uuidString
        UserDefaults.standard.set(deviceId, forKey: "AVO_DEVICE_ID")

        let horseId = UserDefaults.standard.string(forKey: "AVO_ACTIVE_HORSE_ID") ?? "HORSE_001"
        let vestId = UserDefaults.standard.string(forKey: "AVO_ACTIVE_VEST_ID") ?? "VEST_001"

        let payload: [String: Any] = [
            "deviceToken": token,
            "apnsToken": token,
            "deviceId": deviceId,
            "platform": "ios",
            "horseId": horseId,
            "vestId": vestId,
            "bundleId": Bundle.main.bundleIdentifier ?? "com.avoperformance.horse",
            "deviceName": UIDevice.current.name,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "environment": "auto",
            "app": "AVO Performance Horse"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""

            await MainActor.run {
                if (200...299).contains(code) {
                    self.lastRegisterStatus = "PUSH TOKEN REGISTERED"
                    print("PUSH REGISTER RESPONSE:", text)
                } else {
                    self.lastRegisterStatus = "PUSH TOKEN ERROR HTTP \(code): \(text.prefix(120))"
                    print("PUSH REGISTER ERROR HTTP \(code):", text)
                }
            }
        } catch {
            await MainActor.run {
                self.lastRegisterStatus = "PUSH TOKEN UPLOAD ERROR: \(error.localizedDescription)"
                print("PUSH REGISTER ERROR:", error.localizedDescription)
            }
        }
    }
}

// MARK: - UIApplication Delegate for native APNs

final class AVOPushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AVOTrainingPushBridge.shared.configureNotificationSystem()
        Task { @MainActor in
            AVORemotePushManager.shared.configureAndRegister()
            AVORemotePushManager.shared.uploadStoredTokenIfAvailable()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            AVORemotePushManager.shared.updateDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("AVO APNs registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("AVO remote push received: \(userInfo)")
        completionHandler(.newData)
    }
}
