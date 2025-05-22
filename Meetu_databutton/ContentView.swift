//  ContentView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    
    @StateObject private var feedViewModel = FeedViewModel()
   

    var body: some View {
        TabView {
            // Feed Tab
            FeedView()
                .environmentObject(feedViewModel)
                .tabItem {
                    Label("Feed", systemImage: "house")
                }

            // Search Tab
            SearchView()
                .environmentObject(feedViewModel)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            // Create Tab
            CreateView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle")
                }

            // Chats Tab
            ChatListView()
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }

            // Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}
