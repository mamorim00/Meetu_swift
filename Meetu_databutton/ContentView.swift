//
//  ContentView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "house")
                }
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            CreateView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle")
                }
            
            ChatView()
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

#Preview {
    // Create an AuthViewModel for the preview
    let authVM = AuthViewModel()
    // (Optional) Pre-set a dummy user so you preview the logged-in state
    authVM.user = Auth.auth().currentUser  // or leave nil to preview the login screen

    return ContentView()
        .environmentObject(authVM)
}
