//
//  ActivityCard.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import SwiftUI
import FirebaseAuth

struct ActivityCard: View {
    @EnvironmentObject var viewModel: FeedViewModel
    let activity: Activity
    
    // Computed so it doesn’t affect the init’s visibility
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    /// True when the activity has reached its capacity
    private var isFull: Bool {
        activity.participantIds.count >= activity.maxParticipants
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
                Text(date, style: .date) + Text(" ") + Text(date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            // Join/Leave button, Full badge, and participant count
            HStack {
                if let uid = currentUserId {
                    if activity.participantIds.contains(uid) {
                        // You're in—allow leaving
                        Button("Leave") {
                            viewModel.leave(activity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                    } else if isFull {
                        // Full and you're not in—show badge
                        Text("Full")
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemRed).opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)

                    } else {
                        // Not full and not in—allow joining
                        Button("Join") {
                            viewModel.join(activity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFull)
                    }
                }

                Spacer()

                // Always show count / capacity
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
