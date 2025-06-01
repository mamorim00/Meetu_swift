//
//  FeedView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//



import SwiftUI
import FirebaseAuth
import Combine
import FirebaseFirestore

// ActivityVisibility.swift (or add to your model file)
import Foundation

enum ActivityVisibility: String, CaseIterable, Identifiable {
    case all = "Show All"
    case publicOnly = "Public Only"
    case friendsOnly = "Friends Only" // Assumes !isPublic means friends-only

    var id: String { self.rawValue }
}

import SwiftUI
import FirebaseAuth
import Combine
import FirebaseFirestore

class FeedViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var errorMessage: String?

    // MARK: - Filter Properties
    @Published var selectedLocation: String = ""
    @Published var selectedCategory: String = "All" // Default to "All"
    @Published var selectedVisibility: ActivityVisibility = .all
    @Published var isFilterViewExpanded: Bool = false

    let allCategories: [String] = ["All", "Sports", "Dining", "Hiking", "Gaming", "Movies", "Travel", "Music", "Cooking"]

    var filteredActivities: [Activity] {
        activities.filter { activity in
            // Location Filter (case-insensitive, partial match)
            let locationMatch = selectedLocation.isEmpty ||
                                activity.location.localizedCaseInsensitiveContains(selectedLocation)

            // Category Filter
            let categoryMatch = selectedCategory == "All" ||
                                activity.category == selectedCategory

            // Visibility Filter (assuming Activity has `isPublic: Bool`)
            let visibilityMatch: Bool
            switch selectedVisibility {
            case .all:
                visibilityMatch = true
            case .publicOnly:
                visibilityMatch = activity.isPublic
            case .friendsOnly:
                visibilityMatch = !activity.isPublic // Assumes !isPublic means friends-only
            }
            
            return locationMatch && categoryMatch && visibilityMatch
        }
    }

    private let service = FirestoreService.shared
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening() {
        // Don’t re-attach if already listening
        guard listener == nil else { return }

        // Safely unwrap current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Unable to determine current user"
            return
        }

        // Pass the userId into the “excluding” version of listenActivities
        listener = service.listenActivities(excluding: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let acts):
                    self?.activities = acts
                    print("Received \(acts.count) activities (excluding my own) from Firestore")
                case .failure(let err):
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    func clearFilters() {
        selectedLocation = ""
        selectedCategory = "All"
        selectedVisibility = .all
        // Optionally collapse the filter view when cleared:
        // isFilterViewExpanded = false
    }

    func join(_ activity: Activity) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in"
            return
        }
        service.joinActivity(activityId: activity.id!, userId: uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    if let idx = self?.activities.firstIndex(where: { $0.id == activity.id }) {
                        self?.activities[idx].participantIds.append(uid)
                    }
                case .failure(let err):
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }

    func leave(_ activity: Activity) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in"
            return
        }
        service.leaveActivity(activity: activity, currentUserId: uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    if let idx = self?.activities.firstIndex(where: { $0.id == activity.id }) {
                        self?.activities[idx].participantIds.removeAll { $0 == uid }
                    }
                case .failure(let err):
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }
}

import SwiftUI
import FirebaseAuth // Already imported

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @Environment(\.colorScheme) var colorScheme // For theming filter section if needed

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { new in if !new { viewModel.errorMessage = nil } }
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) { // Use VStack to contain DisclosureGroup and List
                DisclosureGroup(
                    isExpanded: $viewModel.isFilterViewExpanded,
                    content: {
                        VStack(alignment: .leading, spacing: 15) {
                            TextField("Filter by location (e.g., city)", text: $viewModel.selectedLocation)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(10)
                                .background(Color.appInputBackground(for: colorScheme))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.appBorder(for: colorScheme), lineWidth: 1)
                                )


                            Picker("Category", selection: $viewModel.selectedCategory) {
                                ForEach(viewModel.allCategories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(MenuPickerStyle()) // Or .SegmentedPickerStyle() if few options

                            Picker("Show Activities", selection: $viewModel.selectedVisibility) {
                                ForEach(ActivityVisibility.allCases) { visibility in
                                    Text(visibility.rawValue).tag(visibility)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())

                            Button {
                                viewModel.clearFilters()
                            } label: {
                                Text("Clear All Filters")
                                    .font(.footnote)
                                    .foregroundColor(Color.appAccent(for: colorScheme))
                            }
                            .padding(.top, 5)
                        }
                        .padding() // Padding inside the DisclosureGroup content
                        .background(Color.appCardBackground(for: "default", scheme: colorScheme).opacity(0.5)) // Optional subtle background
                    },
                    label: {
                        Text("Filters")
                            .font(.headline)
                            .foregroundColor(Color.appForeground(for: colorScheme))
                    }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.appBackground(for: colorScheme)) // Match overall background or make distinct

                // List of Activities
                if viewModel.filteredActivities.isEmpty && !viewModel.activities.isEmpty &&
                   (!viewModel.selectedLocation.isEmpty || viewModel.selectedCategory != "All" || viewModel.selectedVisibility != .all) {
                    // Show a message if filters result in no activities, but there are activities overall
                    VStack {
                        Spacer()
                        Text("No activities match your current filters.")
                            .font(.headline)
                            .foregroundColor(Color.appMutedForeground(for: colorScheme))
                        Text("Try adjusting or clearing your filters.")
                            .font(.subheadline)
                            .foregroundColor(Color.appMutedForeground(for: colorScheme))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground(for: colorScheme))
                } else if viewModel.activities.isEmpty {
                     // Show a message if there are no activities at all (e.g., loading or empty backend)
                    VStack {
                        Spacer()
                        Text(viewModel.errorMessage == nil ? "No activities yet." : "Could not load activities.")
                            .font(.headline)
                            .foregroundColor(Color.appMutedForeground(for: colorScheme))
                        if viewModel.errorMessage == nil {
                            Text("Check back later or create a new one!")
                                .font(.subheadline)
                                .foregroundColor(Color.appMutedForeground(for: colorScheme))
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground(for: colorScheme))
                } else {
                    List {
                        ForEach(viewModel.filteredActivities) { activity in // Use filteredActivities
                            ActivityCard(activity: activity)
                                .environmentObject(viewModel)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) // Ensure card padding takes effect
                                .listRowBackground(Color.clear) // Keep card background, not row
                                .padding(.vertical, 4) // Add some vertical spacing between cards if needed outside card
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden) // Hides default List background
                }
            }
            .background(Color.appBackground(for: colorScheme)) // Ensure the VStack background is themed
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.isFilterViewExpanded.toggle()
                    } label: {
                        Image(systemName: viewModel.isFilterViewExpanded ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(Color.appAccent(for: colorScheme))
                    }
                }
            }
            .alert(
                "Error",
                isPresented: isShowingError,
                actions: { Button("OK") { viewModel.errorMessage = nil } },
                message: { Text(viewModel.errorMessage ?? "Unknown error") }
            )
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
        .accentColor(Color.appAccent(for: colorScheme)) // Sets default tint for controls like Picker
    }
}
