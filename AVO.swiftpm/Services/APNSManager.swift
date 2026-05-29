import Foundation
import UserNotifications
import UIKit

final class APNSManager: NSObject, ObservableObject {
    
    static let shared = APNSManager()
    
    @Published var deviceToken: String = ""
    
    func setup() {
        
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                
                DispatchQueue.main.async {
                    
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
    }
    
    func updateToken(_ token: Data) {
        
        let tokenParts = token.map {
            data in String(format: "%02.2hhx", data)
        }
        
        let tokenString = tokenParts.joined()
        
        DispatchQueue.main.async {
            
            self.deviceToken = tokenString
            
            UserDefaults.standard.set(tokenString, forKey: "AVO_APNS_TOKEN")
            
            print("APNS TOKEN:")
            print(tokenString)
        }
    }
}

