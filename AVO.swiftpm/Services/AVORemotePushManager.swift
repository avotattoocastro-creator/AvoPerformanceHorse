import Foundation
import UIKit
import UserNotifications

// MARK: - AVO Remote Push Manager
// v1.3.5 build 50
// Push-only update. No CoreML changes.
// Registers the real APNs token and uploads it to the public Raspberry endpoint:
// https://live.avoperformance.org/api/push/register
//
// IMPORTANT:
// Real background push delivery requires an Apple provisioning profile with Push Notifications enabled.
// This build keeps CODE_SIGN_ENTITLEMENTS disabled to compile with the current Codemagic profile.
// If iOS returns "no valid aps-environment entitlement", regenerate the App Store profile with Push enabled.

@MainActor
final class AVORemotePushManager: NSObject, ObservableObject {
    static let shared = AVORemotePushManager()

    private let registerURL = URL(string: "https://live.avoperformance.org/api/push/register")!
    private let statusURL = URL(string: "https://live.avoperformance.org/api/push/status")!
    private let avoToken = "AVO2026"

    @Published private(set) var permissionGranted: Bool = false
    @Published private(set) var apnsTokenHex: String = UserDefaults.standard.string(forKey: "AVO_APNS_TOKEN_HEX") ?? ""
    @Published private(set) var lastRegisterStatus: String = UserDefaults.standard.string(forKey: "AVO_PUSH_LAST_STATUS") ?? "PUSH NOT REGISTERED"
    @Published private(set) var lastServerStatus: String = UserDefaults.standard.string(forKey: "AVO_PUSH_SERVER_STATUS") ?? "PUSH SERVER UNKNOWN"
    @Published private(set) var lastRegisterDate: Date? = UserDefaults.standard.object(forKey: "AVO_PUSH_LAST_REGISTER_DATE") as? Date

    private var didRequestAuthorization = false
    private var didAskRemoteRegistration = false
    private var uploadInProgress = false

    private override init() { super.init() }

    func configureAndRegister() {
        print("AVO PUSH BUILD50: configureAndRegister")
        UNUserNotificationCenter.current().delegate = AVOTrainingPushBridge.shared

        // Always re-check server status and retry stored token.
        Task {
            await self.refreshServerStatus()
            await self.uploadStoredTokenIfAvailableAsync()
        }

        guard !didRequestAuthorization else {
            registerForRemoteNotificationsOnce(force: true)
            return
        }
        didRequestAuthorization = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]) { granted, error in
            DispatchQueue.main.async {
                self.permissionGranted = granted

                if let error {
                    self.setStatus("PUSH PERMISSION ERROR: \(error.localizedDescription)")
                    print("AVO PUSH BUILD50 permission error:", error.localizedDescription)
                    return
                }

                if granted {
                    self.setStatus("PUSH PERMISSION OK - REQUESTING APNS TOKEN")
                    print("AVO PUSH BUILD50 permission OK")
                    self.registerForRemoteNotificationsOnce(force: true)
                } else {
                    self.setStatus("PUSH PERMISSION DENIED")
                    print("AVO PUSH BUILD50 permission denied")
                }
            }
        }
    }

    func registerForRemoteNotificationsOnce(force: Bool = false) {
        if didAskRemoteRegistration && !force { return }
        didAskRemoteRegistration = true

        DispatchQueue.main.async {
            print("AVO PUSH BUILD50: UIApplication.registerForRemoteNotifications()")
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func updateDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        apnsTokenHex = token
        UserDefaults.standard.set(token, forKey: "AVO_APNS_TOKEN_HEX")
        UserDefaults.standard.set(Date(), forKey: "AVO_APNS_TOKEN_DATE")
        print("AVO PUSH BUILD50 APNS TOKEN:", token)

        Task { await uploadToken(token, reason: "didRegisterForRemoteNotifications") }
    }

    func uploadStoredTokenIfAvailable() {
        Task { await uploadStoredTokenIfAvailableAsync() }
    }

    private func uploadStoredTokenIfAvailableAsync() async {
        let stored = UserDefaults.standard.string(forKey: "AVO_APNS_TOKEN_HEX") ?? apnsTokenHex
        guard !stored.isEmpty else {
            print("AVO PUSH BUILD50: no stored APNS token yet")
            return
        }
        await uploadToken(stored, reason: "stored-token-retry")
    }

    func refreshServerStatus() async {
        var request = URLRequest(url: statusURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue(avoToken, forHTTPHeaderField: "X-AVO-TOKEN")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            await MainActor.run {
                self.lastServerStatus = "HTTP \(code): \(body.prefix(120))"
                UserDefaults.standard.set(self.lastServerStatus, forKey: "AVO_PUSH_SERVER_STATUS")
                print("AVO PUSH BUILD50 server status:", self.lastServerStatus)
            }
        } catch {
            await MainActor.run {
                self.lastServerStatus = "PUSH SERVER ERROR: \(error.localizedDescription)"
                UserDefaults.standard.set(self.lastServerStatus, forKey: "AVO_PUSH_SERVER_STATUS")
                print("AVO PUSH BUILD50 server status error:", error.localizedDescription)
            }
        }
    }

    private func uploadToken(_ token: String, reason: String) async {
        if uploadInProgress {
            print("AVO PUSH BUILD50: upload already in progress")
            return
        }
        uploadInProgress = true
        defer { uploadInProgress = false }

        var request = URLRequest(url: registerURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(avoToken, forHTTPHeaderField: "X-AVO-TOKEN")

        let deviceId = UIDevice.current.identifierForVendor?.uuidString
            ?? UserDefaults.standard.string(forKey: "AVO_DEVICE_ID")
            ?? UUID().uuidString
        UserDefaults.standard.set(deviceId, forKey: "AVO_DEVICE_ID")

        let horseId = UserDefaults.standard.string(forKey: "AVO_ACTIVE_HORSE_ID") ?? "HORSE_001"
        let vestId = UserDefaults.standard.string(forKey: "AVO_ACTIVE_VEST_ID") ?? "VEST_001"

        let payload: [String: Any] = [
            "deviceToken": token,
            "apnsToken": token,
            "token": token,
            "deviceId": deviceId,
            "platform": "ios",
            "horseId": horseId,
            "vestId": vestId,
            "bundleId": Bundle.main.bundleIdentifier ?? "com.avoperformance.horse",
            "deviceName": UIDevice.current.name,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "environment": "production",
            "app": "AVO Performance Horse",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.5",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "50",
            "reason": reason
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            print("AVO PUSH BUILD50 uploading APNS token to:", registerURL.absoluteString, "reason:", reason)

            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""

            await MainActor.run {
                if (200...299).contains(code) {
                    self.lastRegisterDate = Date()
                    UserDefaults.standard.set(Date(), forKey: "AVO_PUSH_LAST_REGISTER_DATE")
                    self.setStatus("PUSH TOKEN REGISTERED BUILD50 HTTP \(code)")
                    print("AVO PUSH BUILD50 REGISTER OK:", text)
                } else {
                    self.setStatus("PUSH TOKEN ERROR BUILD50 HTTP \(code): \(text.prefix(160))")
                    print("AVO PUSH BUILD50 REGISTER HTTP ERROR \(code):", text)
                }
            }
        } catch {
            await MainActor.run {
                self.setStatus("PUSH TOKEN UPLOAD ERROR BUILD50: \(error.localizedDescription)")
                print("AVO PUSH BUILD50 REGISTER ERROR:", error.localizedDescription)
            }
        }
    }

    private func setStatus(_ status: String) {
        lastRegisterStatus = status
        UserDefaults.standard.set(status, forKey: "AVO_PUSH_LAST_STATUS")
    }
}

// MARK: - UIApplication Delegate for native APNs

final class AVOPushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("AVO PUSH BUILD50: didFinishLaunching")
        AVOTrainingPushBridge.shared.configureNotificationSystem()
        Task { @MainActor in
            AVORemotePushManager.shared.configureAndRegister()
            AVORemotePushManager.shared.uploadStoredTokenIfAvailable()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("AVO PUSH BUILD50: didRegisterForRemoteNotificationsWithDeviceToken")
        Task { @MainActor in
            AVORemotePushManager.shared.updateDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("AVO PUSH BUILD50 APNs registration failed:", error.localizedDescription)
        Task { @MainActor in
            AVORemotePushManager.shared.configureAndRegister()
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("AVO PUSH BUILD50 remote push received:", userInfo)
        completionHandler(.newData)
    }
}
