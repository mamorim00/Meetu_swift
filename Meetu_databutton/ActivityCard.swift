import SwiftUI

struct ActivityCard: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activity.title)
                .font(.headline)

            Text(activity.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text(activity.category)
                Spacer()
                Text(activity.location)
            }
            .font(.caption)
            .foregroundColor(.gray)

            if let date = ISO8601DateFormatter().date(from: activity.dateTime) {
                Text("Date: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}
