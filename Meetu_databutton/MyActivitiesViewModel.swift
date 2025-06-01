
import SwiftUI
import FirebaseAuth
import FirebaseFirestore


// MARK: - ViewModel
class MyActivitiesViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var errorMessage: String?

    private let service = FirestoreService.shared
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening() {
        guard listener == nil else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in"
            return
        }

        listener = service.listenMyActivities(userId: uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let acts):
                    self?.activities = acts
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
}

// MARK: - View
struct MyActivitiesView: View {
    @StateObject private var viewModel = MyActivitiesViewModel()

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { new in if !new { viewModel.errorMessage = nil } }
        )
    }

    var body: some View {
        NavigationView {
            List {
                if viewModel.activities.isEmpty {
                    Text("You haven’t created any activities yet.")
                    
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(viewModel.activities) { activity in
                        ActivityCard(activity: activity)
                            .environmentObject(FeedViewModel())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(.clear))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.secondarySystemGroupedBackground))
            .navigationTitle("My Activities")
            .alert(
                "Error",
                isPresented: isShowingError,
                actions: {
                    Button("OK") { viewModel.errorMessage = nil }
                },
                message: {
                    Text(viewModel.errorMessage ?? "Unknown error")
                }
            )
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }
}
