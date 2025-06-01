//  ActivityDetailViewModel.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 23.5.2025.
//  Updated: Real-time updates using Firestore SDK with debug prints

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - ActivityDetailViewModel
final class ActivityDetailViewModel: ObservableObject {
    @Published var activity: Activity?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var didDelete = false

    private var listener: ListenerRegistration?
    private let activityId: String
    private let db = Firestore.firestore()
   
    init(activityId: String) {
        self.activityId = activityId
        print("[ViewModel] init with activityId: \(activityId)")
        listenToActivityChanges()
    }

    deinit {
        listener?.remove()
        print("[ViewModel] listener removed for \(activityId)")
    }

    private func listenToActivityChanges() {
        isLoading = true
        errorMessage = nil
        print("[ViewModel] start listening to activity changes...")

        listener = db.collection("activities")
            .document(activityId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        print("[ViewModel] snapshot error: \(error)")
                        return
                    }
                    guard let snapshot = snapshot,
                          var updatedActivity = try? snapshot.data(as: Activity.self) else {
                        self?.errorMessage = "Activity data unavailable."
                        print("[ViewModel] unable to parse activity data.")
                        return
                    }
                    updatedActivity.id = snapshot.documentID
                    print("[ViewModel] received updated activity: \(updatedActivity)")
                    self?.activity = updatedActivity
                }
            }
    }

    func deleteActivity() {
        guard let id = activity?.id else { return }
        print("[ViewModel] deleteActivity called for id: \(id)")
        isLoading = true
        db.collection("activities").document(id).delete { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[ViewModel] delete error: \(error)")
                } else {
                    self?.didDelete = true
                    print("[ViewModel] delete success for id: \(id)")
                }
            }
        }
    }

    func joinOrLeave() {
        guard let activity = activity,
              let uid = Auth.auth().currentUser?.uid,
              let id = activity.id else { return }

        let isLeaving = activity.participantIds.contains(uid)
        print("[ViewModel] joinOrLeave called. isLeaving: \(isLeaving)")
        let ref = db.collection("activities").document(id)
        let update: [String: Any] = isLeaving
            ? ["participantIds": FieldValue.arrayRemove([uid])]
            : ["participantIds": FieldValue.arrayUnion([uid])]

        ref.updateData(update) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("[ViewModel] joinOrLeave error: \(error)")
                } else {
                    print("[ViewModel] joinOrLeave success for id: \(id)")
                }
                // UI updates via listener
            }
        }
    }
}

// A simple identifiable enum or struct to represent destinations
enum ActivityDetailNavigation: Hashable {
    case chat(activityId: String, title: String)
}


import SwiftUI
import FirebaseAuth
import SwiftUI
import FirebaseAuth

struct ActivityDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @StateObject private var viewModel: ActivityDetailViewModel
    @State private var showErrorAlert = false
    @State private var isChatViewActive = false
    @State private var showDeleteConfirmation = false
    @State private var showEditView = false    // New state to present edit screen
    @State private var navigationSelection: ActivityDetailNavigation?



    private static let isoFormatter = ISO8601DateFormatter()
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    init(activityId: String) {
        _viewModel = StateObject(wrappedValue: ActivityDetailViewModel(activityId: activityId))
    }

    // parser: accept ISO strings with or without fractional seconds
    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [
            .withFullDate,            // e.g. “2025‐05‐31”
            .withFullTime,            // hours, minutes, seconds
            .withFractionalSeconds,   // allow parsing “.123” if present
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withTimeZone             // “Z” or “+02:00”
        ]
        return f
    }()


    // outputter: include fractional seconds
    private static let isoOutputter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [
            .withInternetDateTime,       // full date + time + zone
            .withFractionalSeconds       // “.123”
        ]
        return f
    }()

    private func formattedDisplayDateTime(from isoString: String) -> String {
        // optional: log what you actually got
       

        guard let date = Self.isoParser.date(from: isoString) else {
            return "Date/Time not available"
        }
        // Use the displayDateFormatter here
        return Self.displayDateFormatter.string(from: date)
    }

    var body: some View {
        let activity = viewModel.activity
        let currentUid = Auth.auth().currentUser?.uid
        let isOwner = activity?.userId == currentUid

        Group {
            if viewModel.isLoading {
                CenteredProgressView(colorScheme: colorScheme)
            } else if let activity = activity {
                contentView(for: activity, isOwner: isOwner)
            } else if let error = viewModel.errorMessage {
                ErrorStateView(message: error, showErrorAlert: $showErrorAlert, colorScheme: colorScheme)
            } else {
                NotFoundStateView(colorScheme: colorScheme)
            }
        }
        .navigationTitle(activity?.title ?? "Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this activity?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.deleteActivity()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditView) {
            // if the activity is non-nil, we can unwrap it safely here
            if let act = viewModel.activity {
                EditView(
                  activityId:       act.id!,
                  title:            act.title,
                  description:      act.description,
                  location:         act.location,
                  locationQuery:    act.location,      // seed the search field
                  dateTime:         ISO8601DateFormatter()
                                       .date(from: act.dateTime) ?? Date(),
                  isPublic:         act.isPublic,
                  maxParticipants:  act.maxParticipants,
                  category:         act.category
                )
            } else {
                Text("Loading…")
            }
        }

        .onChange(of: viewModel.didDelete) {
            if viewModel.didDelete { dismiss() }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error.")
        }
    }



    @ViewBuilder
    private func contentView(for activity: Activity, isOwner: Bool) -> some View {
        let currentUid = Auth.auth().currentUser?.uid
        let isUserParticipant = currentUid.map { activity.participantIds.contains($0) } ?? false
        let isActivityFull = activity.participantIds.count >= activity.maxParticipants

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(activity.title)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(Color.appForeground(for: colorScheme))

                VStack(alignment: .leading, spacing: 16) {
                    DetailItemView(iconName: "calendar.badge.clock", label: "When", value: formattedDisplayDateTime(from: activity.dateTime), colorScheme: colorScheme)
                    DetailItemView(iconName: "location.fill", label: "Where", value: activity.location, colorScheme: colorScheme)
                    DetailItemView(iconName: "tag.fill", label: "Category", value: activity.category.uppercased(), colorScheme: colorScheme)
                }
                .padding(.bottom, 8)

                Divider().background(Color.appBorder(for: colorScheme))

                if !activity.description.isEmpty {
                    SectionHeaderView(title: "About this Activity", colorScheme: colorScheme)
                    Text(activity.description)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundColor(Color.appForeground(for: colorScheme))
                        .padding(.bottom, 8)
                    Divider().background(Color.appBorder(for: colorScheme))
                }

                SectionHeaderView(title: "Participants", colorScheme: colorScheme)
                HStack {
                    Image(systemName: "person.3.fill")
                    Text("\(activity.participantIds.count) / \(activity.maxParticipants) attending")
                    Spacer()
                }
                .font(.callout)
                .foregroundColor(Color.appMutedForeground(for: colorScheme))

                Spacer(minLength: 20)

                if isUserParticipant {
                    // Button triggers navigation by setting the navigationSelection
                    Button {
                        navigationSelection = .chat(activityId: activity.id!, title: activity.title)
                    } label: {
                        Label("Open Activity Chat", systemImage: "message.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appSecondary(for: colorScheme))
                            .foregroundColor(Color.appSecondaryForeground(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                if isActivityFull && !isUserParticipant {
                    FullStatusView(colorScheme: colorScheme)
                } else if !isOwner {
                    Button(action: viewModel.joinOrLeave) {
                        Text(isUserParticipant ? "Leave Activity" : "Join Activity")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isUserParticipant ? Color.appDestructive(for: colorScheme) : Color.appAccent(for: colorScheme))
                            .foregroundColor(isUserParticipant ? Color.appDestructiveForeground(for: colorScheme) : Color.appAccentForeground(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                Spacer(minLength: 5)

                if isOwner {
                    VStack(spacing: 12) {
                        Button {
                            showEditView = true
                        } label: {
                            Text("Edit Activity")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent(for: colorScheme))
                                .foregroundColor(Color.appAccentForeground(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Activity")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appDestructive(for: colorScheme))
                                .foregroundColor(Color.appDestructiveForeground(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding()
        }
        // Add navigationDestination modifier here:
        .navigationDestination(for: ActivityDetailNavigation.self) { nav in
            switch nav {
            case .chat(let activityId, let title):
                ChatView(chatId: activityId, chatTitle: title)
            }
        }
    }
}


// MARK: - Helper Subviews (DetailItemView, SectionHeaderView, FullStatusView, CenteredProgressView, ErrorStateView, NotFoundStateView)
// These should be the same as defined in the previous step. I'll include them here for completeness.

private struct DetailItemView: View {
    let iconName: String
    let label: String
    let value: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(Color.appAccent(for: colorScheme))
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.appMutedForeground(for: colorScheme))
                Text(value)
                    .font(.callout)
                    .foregroundColor(Color.appForeground(for: colorScheme))
            }
        }
    }
}

private struct SectionHeaderView: View {
    let title: String
    let colorScheme: ColorScheme

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundColor(Color.appForeground(for: colorScheme))
            .padding(.top, 8)
    }
}

private struct FullStatusView: View {
    let colorScheme: ColorScheme
    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
            Text("This activity is full")
            Spacer()
        }
        .font(.headline)
        .padding()
        .foregroundColor(Color.appDestructive(for: colorScheme))
        .background(Color.appDestructive(for: colorScheme).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CenteredProgressView: View {
    let colorScheme: ColorScheme
    var body: some View {
        VStack {
            Spacer()
            ProgressView("Loading Details...")
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appAccent(for: colorScheme)))
                .foregroundColor(Color.appForeground(for: colorScheme))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErrorStateView: View {
    let message: String
    @Binding var showErrorAlert: Bool
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.appDestructive(for: colorScheme))
            Text("Oops! Something went wrong.")
                .font(.title2.bold())
                .foregroundColor(Color.appForeground(for: colorScheme))
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color.appMutedForeground(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear { showErrorAlert = true }
    }
}

private struct NotFoundStateView: View {
    let colorScheme: ColorScheme
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "questionmark.diamond.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.appMutedForeground(for: colorScheme))
            Text("Activity Not Found")
                .font(.title2.bold())
                .foregroundColor(Color.appForeground(for: colorScheme))
            Text("Sorry, we couldn't find the details for this activity.")
                .font(.subheadline)
                .foregroundColor(Color.appMutedForeground(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
