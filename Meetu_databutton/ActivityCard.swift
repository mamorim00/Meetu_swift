//
//  ActivityCard.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//
//
//  ActivityCard.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import SwiftUI
import FirebaseAuth

// No `private` on the struct
struct ActivityCard: View {
    @EnvironmentObject var viewModel: FeedViewModel
    let activity: Activity
    
    // Make this a computed property so it isn't part of the memberwise init
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(activity.title)
                .font(.headline)
                .foregroundColor(.primary)

            // Description
            Text(activity.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Category & Location
            HStack {
                Text(activity.category)
                Spacer()
                Text(activity.location)
            }
            .font(.caption)
            .foregroundColor(.gray)

            // Date & Time
            if let date = ISO8601DateFormatter().date(from: activity.dateTime) {
                Text("\(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            // Join/Leave button and participant count
            HStack {
                if let uid = currentUserId {
                    if activity.participantIds.contains(uid) {
                        Button("Leave") {
                            viewModel.leave(activity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    } else {
                        Button("Join") {
                            viewModel.join(activity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer()

                Text("\(activity.participantIds.count)/\(activity.maxParticipants)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
