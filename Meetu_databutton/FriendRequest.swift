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
                ProfileImageView(urlString: profile.photoURL, size: 120)
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
                ProgressView("Loading user…")
            }
        }
        .padding()
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
    }

    private var buttonTitle: String {
        switch requestState {
        case .none:    return "Add Friend"
        case .pending: return "Request Sent"
        case .friends: return "Friends"
        }
    }

    // MARK: - Real-time listeners

    private func startListening() {
        // 1. Listen to the other user's profile doc
        FirestoreService.shared.listenToUser(userId: otherUserId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.profile = user
                    self.updateRequestState(basedOn: user)
                case .failure(let err):
                    print("Profile listener error:", err)
                }
            }
        }

        FirestoreService.shared.listenToOutgoingFriendRequest(
            from: currentUser.id!,
            to: otherUserId,
            callback: { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let req):
                        if let req = req {
                            self.requestState = req.status == "accepted" ? .friends : .pending
                        } else {
                            self.requestState = .none
                        }
                    case .failure(let err):
                        print("Request listener error:", err)
                    }
                }
            }
        )
    }

    private func stopListening() {
        FirestoreService.shared.removeAllListeners()
    }

    // MARK: - Helpers

    private func updateRequestState(basedOn otherProfile: UserProfile) {
        // If they've already added you as a friend on their end,
        // reflect that immediately, even without waiting for the request doc.
        if otherProfile.friends.contains(currentUser.id!) {
            requestState = .friends
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

