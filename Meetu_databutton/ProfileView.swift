//
//  ProfileView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//



import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let user = auth.user {
                    Text("Hello, \(user.displayName ?? user.email ?? "User")")
                        .font(.title)
                }

                Button("Sign Out") {
                    auth.signOut()
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}
