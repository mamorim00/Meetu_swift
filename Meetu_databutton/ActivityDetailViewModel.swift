import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - ActivityDetailViewModel
final class ActivityDetailViewModel: ObservableObject {
    @Published var activity: Activity?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = FirestoreService.shared
    private var cancellables = Set<AnyCancellable>()
    private let activityId: String

    init(activityId: String) {
        self.activityId = activityId
        fetchActivity()
    }

    func fetchActivity() {
        isLoading = true
        errorMessage = nil
        service.fetchActivity(withId: activityId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let activity):
                    self?.activity = activity
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func joinOrLeave() {
        guard let activity = activity,
              let uid = Auth.auth().currentUser?.uid else { return }

        if activity.participantIds.contains(uid) {
            leave(activity)
        } else {
            join(activity)
        }
    }

    private func join(_ activity: Activity) {
        guard let id = activity.id else { return }
        service.joinActivity(activityId: id, userId: Auth.auth().currentUser!.uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self?.activity?.participantIds.append(Auth.auth().currentUser!.uid)
                case .failure(let err):
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }

    private func leave(_ activity: Activity) {
        guard let id = activity.id else { return }
        service.leaveActivity(activity: activity, currentUserId: Auth.auth().currentUser!.uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self?.activity?.participantIds.removeAll { $0 == Auth.auth().currentUser!.uid }
                case .failure(let err):
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }
}

// MARK: - ActivityDetailView
struct ActivityDetailView: View {
    @StateObject private var viewModel: ActivityDetailViewModel
    @State private var showError = false

    init(activityId: String) {
        _viewModel = StateObject(wrappedValue: ActivityDetailViewModel(activityId: activityId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let activity = viewModel.activity {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(activity.title)
                            .font(.largeTitle)
                            .bold()

                        if let date = ISO8601DateFormatter().date(from: activity.dateTime) {
                            Text(date, style: .date) + Text(" ") + Text(date, style: .time)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text(activity.description)
                            .font(.body)

                        HStack {
                            Label(activity.category, systemImage: "tag")
                            Spacer()
                            Label(activity.location, systemImage: "mappin.and.ellipse")
                        }
                        .font(.subheadline)
                        .foregroundColor(.gray)

                        Divider()

                        // Participants info
                        Text("Participants: \(activity.participantIds.count)/\(activity.maxParticipants)")
                            .font(.subheadline)

                        Button(action: viewModel.joinOrLeave) {
                            let uid = Auth.auth().currentUser?.uid
                            let title = (uid != nil && activity.participantIds.contains(uid!)) ? "Leave" : "Join"
                            Text(title)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(title == "Join" ? Color.blue : Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(activity.participantIds.count >= activity.maxParticipants && !(Auth.auth().currentUser.map { activity.participantIds.contains($0.uid) } ?? false))
                    }
                    .padding()
                }
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .onAppear { showError = true }
            } else {
                Text("Activity not found.")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Details")
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}
