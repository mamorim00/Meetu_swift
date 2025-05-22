//
//  FeedView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//


import SwiftUI
import FirebaseAuth
import Combine

class FeedViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var errorMessage: String?
    
    private let service = FirestoreService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchActivities()
    }

    func fetchActivities() {
        service.fetchActivities { [weak self] acts in
            DispatchQueue.main.async { self?.activities = acts }
        }
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
                    // Optimistically update local state
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
                    // Optimistically update local state
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



struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    // A computed binding that’s true when there’s an error message
    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }

    var body: some View {
      NavigationView {
        List {
          ForEach(viewModel.activities) { activity in
            ActivityCard(activity: activity)
              .environmentObject(viewModel)
              .listRowSeparator(.hidden)
              .listRowBackground(Color(.clear))
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)   // iOS 16+: let our own backgrounds show through
        .background(Color(.secondarySystemGroupedBackground))
        .navigationTitle("Feed")
            // Use isPresented instead of item:
            .alert(
                "Error",
                isPresented: isShowingError,
                actions: {
                    Button("OK") {
                        viewModel.errorMessage = nil
                    }
                },
                message: {
                    Text(viewModel.errorMessage ?? "Unknown error")
                }
            )
        }
    }
}
