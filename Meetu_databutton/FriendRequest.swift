//
//  FriendRequest.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 22.5.2025.
//


//
//  UserProfile.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 22.5.2025.
//


import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - Models


struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String?
    var senderId: String
    var receiverId: String
    var status: String // "pending", "accepted", "rejected"
    var timestamp: Timestamp
}
import SwiftUI

struct OtherUserProfileView: View {
    @State private var profile: UserProfile?
    @State private var requestState: RequestState = .none

    let otherUserId: String
    let currentUser: UserProfile

    enum RequestState {
        case none, pending, friends
    }

    var body: some View {
        VStack(spacing: 16) {
            if let profile = profile {
                // 1) Show either the downloaded image or a default avatar
                if let urlString = profile.photoUrl,
                   let url = URL(string: urlString)
                {
                    AsyncImage(url: url) { img in
                        img
                          .resizable()
                          .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                } else {
                    // Fallback avatar
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                }

                Text(profile.displayName)
                    .font(.title)

                Button(action: handleButton) {
                    Text(buttonTitle)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(requestState == .none ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(requestState != .none)
            } else {
                // Still loading
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading user…")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .onAppear(perform: loadData)
    }

    private var buttonTitle: String {
        switch requestState {
        case .none:    return "Add Friend"
        case .pending: return "Request Sent"
        case .friends: return "Friends"
        }
    }

    private func loadData() {
        FirestoreService.shared.fetchUser(withId: otherUserId) { result in
            switch result {
            case .success(let user):
                DispatchQueue.main.async {
                    self.profile = user
                    self.determineRequestState(user)
                }
            case .failure(let err):
                print("Error loading user: \(err)")
            }
        }
    }

    private func determineRequestState(_ user: UserProfile) {
        // Now that id is non-optional, we can safely unwrap:
        let otherId   = user.id
        let currentId = currentUser.id

        if currentUser.friends.contains(otherId!) {
            self.requestState = .friends
        } else {
            FirestoreService.shared.checkPendingRequest(
                from: currentId!,
                to: otherId!
            ) { isPending in
                DispatchQueue.main.async {
                    self.requestState = isPending ? .pending : .none
                }
            }
        }
    }

    private func handleButton() {
        guard let target = profile else { return }
        FirestoreService.shared.sendFriendRequest(
            from: currentUser,
            to: target
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.requestState = .pending
                case .failure(let err):
                    print("Send request failed:", err)
                }
            }
        }
    }
}
