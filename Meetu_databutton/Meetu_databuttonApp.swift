//
//  Meetu_databuttonApp.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth



// Only one FirebaseApp.configure() call in AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        print("✅ Firebase has been configured successfully.")
        return true
    }
}

@main
struct Meetu_databuttonApp: App {
    // Wire up the AppDelegate so configure runs at launch
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
   

    // Auth view model observes FirebaseAuth state
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                
                if authViewModel.user != nil {
                    // Signed in → main TabView
                    ContentView()
                      .environmentObject(authViewModel)

                } else {
                    // Not signed in → show login/register flow
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
            .onAppear {
                // Start listening to auth changes
                authViewModel.listen()
            }
            .onReceive(authViewModel.$userProfile) { _ in
                // nothing else needed, simply the published var will update
            }
      }
    }
}
