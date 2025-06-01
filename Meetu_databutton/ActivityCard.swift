import SwiftUI
import FirebaseAuth

struct ActivityCard: View {
    @EnvironmentObject var viewModel: FeedViewModel
    @Environment(\.colorScheme) var colorScheme

    let activity: Activity
    @State private var isDetailActive = false

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        return f
    }()

    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    private var isFull: Bool { activity.participantIds.count >= activity.maxParticipants }

    private var isUserParticipant: Bool {
        guard let uid = currentUserId else { return false }
        return activity.participantIds.contains(uid)
    }

    private var isOwner: Bool {
        guard let uid = currentUserId else { return false }
        return activity.userId == uid
    }

    private var formattedDateTime: String {
        guard let date = Self.isoFormatter.date(from: activity.dateTime) else { return "—" }
        return Self.displayDateFormatter.string(from: date)
    }

    private var daysUntil: String {
        guard let date = Self.isoFormatter.date(from: activity.dateTime) else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days > 0 { return "in \(days) day\(days>1 ? "s": "")" }
        else if days == 0 { return "today" }
        else { return "\(-days) day(s) ago" }
    }
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                // Badges at top-right inside card
                HStack {
                    Spacer()
                    Text(activity.category)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appAccent(for: colorScheme).opacity(0.2))
                        .foregroundColor(Color.appAccent(for: colorScheme))
                        .clipShape(Capsule())

                    HStack(spacing: 4) {
                        Image(systemName: activity.isPublic ? "globe" : "lock.fill")
                        Text(activity.isPublic ? "Public" : "Private")
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appMutedForeground(for: colorScheme).opacity(0.1))
                    .foregroundColor(Color.appMutedForeground(for: colorScheme))
                    .clipShape(Capsule())
                }

                // Title + Creator
                Text(activity.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(Color.appForeground(for: colorScheme))
                    .lineLimit(2)

                Text("Created by \(activity.displayName)")
                    .font(.footnote)
                    .foregroundColor(Color.appMutedForeground(for: colorScheme))

                // Description
                if !activity.description.isEmpty {
                    Text(activity.description)
                        .font(.subheadline)
                        .foregroundColor(Color.appMutedForeground(for: colorScheme))
                        .lineLimit(3)
                }

                Divider()

                // Quick info rows
                InfoRow(icon: "location.fill", text: activity.location, colorScheme: colorScheme)

                // Date indicator + view details
                HStack(spacing: 4) {
                    Text(daysUntil)
                        .font(.caption.weight(.medium))
                    Spacer()
                    Button("View details") {
                        isDetailActive = true
                    }
                    .font(.caption.weight(.semibold))
                }
                .foregroundColor(Color.appAccent(for: colorScheme))
            }
            .padding(16)
            .background(
                Color.appCardBackground(for: activity.category, scheme: colorScheme)
                    .opacity(0.15)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appAccent(for: colorScheme), lineWidth: 1)
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 6, x: 0, y: 3)
            .contentShape(Rectangle())
            .onTapGesture {
                isDetailActive = true
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .navigationDestination(isPresented: $isDetailActive) {
            ActivityDetailView(activityId: activity.id!)
        }
    }
}

// Helper View for Icon + Text Row
private struct InfoRow: View {
    let icon: String
    let text: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(Color.appAccent(for: colorScheme))
                .frame(width: 22, alignment: .center)
            Text(text)
                .font(.caption)
                .foregroundColor(Color.appMutedForeground(for: colorScheme))
                .lineLimit(1)
        }
    }
}


// MARK: - Helper View for Status Pill (like "Full")
private struct StatusPill: View {
    let text: String
    let textColor: Color
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(textColor)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}

// MARK: — Minimalistic Capsule Button
struct MinimalCapsuleButton: View {
    @Environment(\.colorScheme) var colorScheme // << ADDED for theming

    enum Style {
        case primary, destructive, muted

        func color(for scheme: ColorScheme) -> Color {
            switch self {
            case .primary:
                return Color.appAccent(for: scheme)
            case .destructive:
                return Color.appDestructive(for: scheme)
            case .muted:
                return Color.appMutedForeground(for: scheme)
            }
        }
    }

    let title: String
    let style: Style // << UPDATED
    let action: () -> Void

    var body: some View {
        let activeColor = style.color(for: colorScheme)
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12) // Increased padding slightly
                .padding(.vertical, 8)
                .frame(minHeight: 30) // Adjusted height
        }
        .buttonStyle(.plain) // To remove default button styling
        .foregroundColor(activeColor)
        .overlay(
            Capsule().stroke(activeColor, lineWidth: 1.5) // Slightly thicker border
        )
    }
}
