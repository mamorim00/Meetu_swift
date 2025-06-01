//
//  Meetu_databuttonApp.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import FirebaseMessaging


//
//  AppDelegate.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: — Application Launch
    func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 1️⃣ Configure Firebase
        FirebaseApp.configure()
        print("✅ Firebase has been configured successfully.")

        // 2️⃣ Set Messaging and Notification delegates
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // 3️⃣ Request user authorization for notifications
        registerForPushNotifications(application)

        return true
    }

    // MARK: — Request Notification Permission & Register
    private func registerForPushNotifications(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification authorization error: \(error.localizedDescription)")
                return
            }
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ User denied push notification permission.")
            }
        }
    }

    // MARK: — APNs Registration Callbacks
    func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass the APNs device token to FCM
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNs device token set in Messaging.")
    }

    func application(
      _ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: — UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Called when a notification arrives while the app is in the foreground.
    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Display banner, sound, and badge even if app is foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Called when the user taps on a notification (background or closed).
    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // If your payload included "chatId", post a NotificationCenter event so SwiftUI can navigate
        if let chatId = userInfo["chatId"] as? String {
            NotificationCenter.default.post(
                name: .didTapChatNotification,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }

        completionHandler()
    }
}

// MARK: — MessagingDelegate
extension AppDelegate: MessagingDelegate {
    // Called when FCM issues a new registration token (initial launch or refresh).
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("✅ FCM registration token: \(token)")

        // Save this token to Firestore under the current user's profile
        if let uid = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            let userRef = db.collection("userProfiles").document(uid)
            userRef.setData(["fcmToken": token], merge: true) { error in
                if let error = error {
                    print("❌ Error saving FCM token to Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ FCM token saved to Firestore.")
                }
            }
        }
    }

}



// MARK: — Notification.Name Extension
extension Notification.Name {
    static let didTapChatNotification = Notification.Name("didTapChatNotification")
}

//
//  Meetu_databuttonApp.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

@main
struct Meetu_databuttonApp: App {
    // Wire up our custom AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Auth view model observes FirebaseAuth state
    @StateObject private var authViewModel = AuthViewModel()

    // For handling programmatic navigation on notification tap:
    @State private var selectedChatId: String? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.user != nil {
                    // Signed in → main TabView (or your ContentView)
                    ContentView()
                      .environmentObject(authViewModel)
                      .onReceive(NotificationCenter.default.publisher(for: .didTapChatNotification)) { note in
                          if let chatId = note.userInfo?["chatId"] as? String {
                              selectedChatId = chatId
                          }
                      }
                      // Pass binding down so you can navigate from ContentView into ChatListView/ChatView
                      .environment(\.selectedChatId, $selectedChatId)

                } else {
                    // Not signed in → show login/register flow
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
            .onAppear {
                authViewModel.listen()
            }
        }
    }
}
