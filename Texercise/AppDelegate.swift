import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var lastShortcut: UIApplicationShortcutItem?
    
    // Orientation lock — set by AppOrientationHelper
    static var orientationLock: UIInterfaceOrientationMask = .portrait
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("🚀 AppDelegate didFinishLaunching")
        
        // Set notification delegate so alerts show even when app is foregrounded
        UNUserNotificationCenter.current().delegate = self
        
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            print("⚡️ Cold launch shortcut: \(shortcut.type)")
            lastShortcut = shortcut
        } else {
            print("📱 Normal launch")
        }
        
        return true
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Allow notifications to display as banners even when app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle tap on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        print("⚡️ performActionFor: \(shortcutItem.type)")
        lastShortcut = shortcutItem
        completionHandler(true)
    }
    
    // Support orientation locking
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
