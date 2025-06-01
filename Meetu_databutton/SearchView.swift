import SwiftUI
import Combine

enum SearchCategory: String, CaseIterable, Identifiable {
    case activities = "Activities"
    case users      = "Users"
    var id: String { rawValue }
}

final class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var category: SearchCategory = .activities {
        didSet { performSearch() }
    }

    @Published var activities: [Activity] = []
    @Published var users: [UserProfile] = []

    private let service = FirestoreService.shared

    func performSearch() {
        let text = searchText.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            activities = []
            users = []
            return
        }

        switch category {
        case .activities:
            service.searchActivities(by: text) { [weak self] acts in
                DispatchQueue.main.async {
                    self?.activities = acts
                }
            }
        case .users:
            service.searchUsers(by: text) { [weak self] us in
                DispatchQueue.main.async {
                    self?.users = us
                }
            }
        }
    }
}

struct SearchView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var feedVM: FeedViewModel
    @StateObject private var vm = SearchViewModel()

    var body: some View {
        NavigationView {
            Group {
                // Guard: only show content when profile is ready
                if let currentUser = authViewModel.userProfile {
                    contentView(currentUser: currentUser)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading profile…")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $vm.searchText, prompt: "Search \(vm.category.rawValue.lowercased())")
            .onChange(of: vm.searchText) {
                vm.performSearch()
            }
        }
    }

    @ViewBuilder
    private func contentView(currentUser: UserProfile) -> some View {
        VStack {
            Picker("", selection: $vm.category) {
                ForEach(SearchCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                if vm.searchText.isEmpty {
                    Text("Start typing to search \(vm.category.rawValue.lowercased()).")
                        .foregroundColor(.gray)
                } else {
                    switch vm.category {
                    case .activities:
                        if vm.activities.isEmpty {
                            Text("No activities found.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(vm.activities) { activity in
                                ActivityCard(activity: activity)
                                    .environmentObject(feedVM)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    case .users:
                        if vm.users.isEmpty {
                            Text("No users found.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(vm.users) { user in
                                NavigationLink {
                                    OtherUserProfileView(
                                        otherUserId: user.id!,
                                        currentUser: currentUser
                                    )
                                } label: {
                                    UserCard(user: user)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        }

}

struct UserCard: View {
    let user: UserProfile

    var body: some View {
        HStack(alignment: .center) {
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(user.displayName)
                    .font(.headline)
                if let email = user.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}
