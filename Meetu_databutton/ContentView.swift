//  ContentView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//
import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var feedViewModel = FeedViewModel()
    @State private var selectedTab: Tab = .feed

    enum Tab: Hashable {
        case feed, search, create, chats, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Feed Tab
            FeedView()
                .environmentObject(feedViewModel)
                .tabItem { Label("Feed", systemImage: "house") }
                .tag(Tab.feed)

            // Search Tab
            SearchView()
                .environmentObject(feedViewModel)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            // Create Tab
            CreateView()
                .tabItem { Label("Create", systemImage: "plus.circle") }
                .tag(Tab.create)

            // Chats Tab
            ChatListView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
                .tag(Tab.chats)

            // Profile Tab
            ProfileContainerView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(Tab.profile)
        }
    }
}
