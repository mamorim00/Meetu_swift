import SwiftUI
import FirebaseAuth
import FirebaseFirestore


// MARK: - Profile Model
struct Profile {
    var bio: String
    var createdAt: Date
    var displayName: String
    var email: String
    var friends: [String]
    var interests: [String]
    var lastLoginAt: Date
    var location: String
    var userId: String
    var photoURL: String?
}

// MARK: - Profile ViewModel
class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var myActivities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let service = FirestoreService.shared
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var activitiesListener: ListenerRegistration?
    
    init() {
        listenForAuth()
    }
    
    func listenForAuth() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            self.activitiesListener?.remove()
            self.myActivities = []

            if let user = user {
                let created   = user.metadata.creationDate ?? Date()
                let lastLogin = user.metadata.lastSignInDate ?? Date()
                self.loadProfile(
                    uid: user.uid,
                    displayName: user.displayName,
                    email: user.email,
                    createdAt: created,
                    lastLoginAt: lastLogin
                )
                self.startMyActivitiesListener(userId: user.uid)
            } else {
                self.profile = nil
            }
        }
    }
    
    func saveProfile(_ updated: Profile, newImage: UIImage? = nil) {
      isLoading = true
      errorMessage = nil

      let group = DispatchGroup()
      var updatedProfile = updated

      // 1) If there's a new image, upload it first:
      if let img = newImage {
        group.enter()
        service.uploadProfileImage(userId: updated.userId, image: img) { result in
          switch result {
          case .success(let url):
            updatedProfile.photoURL = url.absoluteString
          case .failure(let err):
            self.errorMessage = err.localizedDescription
          }
          group.leave()
        }
      }

      // 2) Once done (with or without image), write the rest:
      group.notify(queue: .main) {
        self.service.updateUserProfile(updatedProfile) { error in
          DispatchQueue.main.async {
            self.isLoading = false
            if let error = error {
              self.errorMessage = error.localizedDescription
            } else {
              self.profile = updatedProfile
              // Also update Firebase Auth displayName & photoURL if you like:
              if let user = Auth.auth().currentUser {
                let changeReq = user.createProfileChangeRequest()
                changeReq.displayName = updatedProfile.displayName
                changeReq.photoURL    = URL(string: updatedProfile.photoURL ?? "")
                changeReq.commitChanges { _ in }
              }
            }
          }
        }
      }
    }


    private func loadProfile(uid: String,
                             displayName: String?,
                             email: String?,
                             createdAt: Date,
                             lastLoginAt: Date) {
        isLoading = true
        errorMessage = nil
        
        db.collection("userProfiles")
            .document(uid)
            .getDocument { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    guard let data = snapshot?.data() else {
                        self?.errorMessage = "No user data found."
                        return
                    }
                    let photoURL = data["photoURL"] as? String
                    self?.profile = Profile(
                        bio: data["bio"] as? String ?? "",
                        createdAt: createdAt,
                        displayName: displayName ?? data["displayName"] as? String ?? "",
                        email: email ?? data["email"] as? String ?? "",
                        friends: data["friends"] as? [String] ?? [],
                        interests: data["interests"] as? [String] ?? [],
                        lastLoginAt: lastLoginAt,
                        location: data["location"] as? String ?? "",
                        userId: uid,
                        photoURL: photoURL
                    )
                }
            }
    }
    
    private func startMyActivitiesListener(userId: String) {
        activitiesListener = service.listenMyActivities(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let acts): self?.myActivities = acts
                case .failure(let err): self?.errorMessage = err.localizedDescription
                }
            }
        }
    }
    
    func stopListeners() {
        if let h = authHandle {
            Auth.auth().removeStateDidChangeListener(h)
        }
        activitiesListener?.remove()
    }
    
    deinit {
        stopListeners()
    }
}
// MARK: - Profile View (Modified to include Notification Bell)
struct ProfileView: View {
    @StateObject private var profileVM = ProfileViewModel()
    @State private var isEditing = false

    // This flag determines if the bell icon should be shown.
    // We'll set it to true when ProfileView is used in the context
    // where the tabs were previously.
    var shouldShowNotificationBell: Bool = false

    var body: some View {
        NavigationView { // ProfileView maintains its own NavigationView
            Group {
                if profileVM.isLoading {
                    ProgressView("Loading profile…")
                } else if let profile = profileVM.profile {
                    ProfileContent(profile: profile, isEditing: $isEditing)
                        .environmentObject(profileVM)
                } else if let error = profileVM.errorMessage {
                    Text(error).foregroundColor(.red)
                } else {
                    Text("No user signed in.").foregroundColor(.secondary)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                if shouldShowNotificationBell {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            // Assuming FriendRequestsView is defined elsewhere.
                            // This view will be pushed onto the navigation stack.
                            FriendRequestsView()
                                .navigationTitle("Requests") // Optional: Set a title for the requests screen
                        } label: {
                            Image(systemName: "bell") // Use "bell.fill" for a filled icon
                                .foregroundColor(.accentColor) // Or your preferred color
                        }
                    }
                }
            }
        }
        .onDisappear { profileVM.stopListeners() }
    }
}

// MARK: - ProfileContent (Unchanged, shown for context)
struct ProfileContent: View {
    @State var profile: Profile // Assuming Profile struct exists
    @Binding var isEditing: Bool
    @EnvironmentObject private var profileVM: ProfileViewModel // Assuming ProfileViewModel exists
    @State private var pickedImage: UIImage?
    @State private var showImagePicker = false
    // For editing interests
    @State private var newInterest: String = ""


    private let gridColumns = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader
                profileInfoSection
                Divider()
                interestsSection
                Divider()
                activitiesLink
                editButton
            }
            .padding()
            // 3️⃣ Attach the sheet here:
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(image: $pickedImage)
                    }
                    // 4️⃣ Whenever pickedImage changes, save and exit editing:
                    .onChange(of: pickedImage) {
                        guard let img = pickedImage else { return }
                        profileVM.saveProfile(profile, newImage: img)
                        withAnimation { isEditing = false }
                    }
        }
        
    }

    // MARK: Header
    private var profileHeader: some View {
        ZStack(alignment: .bottomTrailing) {
            ProfileImageView(urlString: profile.photoURL, size: 140) // Assuming ProfileImageView exists
                .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 2))
                .shadow(radius: 4)

            if isEditing {
                // 2️⃣ Tapping this toggles the PHPicker sheet:
                              Button(action: { showImagePicker = true }) {
                                  Image(systemName: "camera.fill")
                                      .padding(10)
                                      .background(Color.white)
                                      .clipShape(Circle())
                                      .shadow(radius: 2)
                }
                .offset(x: -8, y: -8)
            }
        }
    }

    // MARK: Info Section
    private var profileInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Name
            if isEditing {
                TextField("Display Name", text: $profile.displayName)
                    .font(.title2.bold())
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            } else {
                Text(profile.displayName)
                    .font(.title2).bold()
            }

            // Bio
            VStack(alignment: .leading, spacing: 8) {
                Text("About Me")
                    .font(.headline)
                if isEditing {
                    TextEditor(text: $profile.bio)
                        .frame(minHeight: 100, maxHeight: 150)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                } else {
                    Text(profile.bio.isEmpty ? "No bio available." : profile.bio)
                        .foregroundColor(.secondary)
                }
            }

            // Location & Friends
            HStack(spacing: 24) {
                Label(profile.location, systemImage: "mappin.and.ellipse")
                Label("Friends: \(profile.friends.count)", systemImage: "person.2.fill")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Interests Section (Editable)
      private var interestsSection: some View {
          VStack(alignment: .leading, spacing: 12) {
              Text("Interests")
                  .font(.headline)

              if isEditing {
                  // Editable list of tags with removal
                  LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                      ForEach(profile.interests, id: \.self) { interest in
                          HStack(spacing: 4) {
                              Text(interest)
                                  .font(.subheadline)
                              Button(action: {
                                  if let idx = profile.interests.firstIndex(of: interest) {
                                      profile.interests.remove(at: idx)
                                  }
                              }) {
                                  Image(systemName: "xmark.circle.fill")
                                      .font(.subheadline)
                              }
                          }
                          .padding(.vertical, 6)
                          .padding(.horizontal, 12)
                          .background(Color(.systemGray5))
                          .cornerRadius(16)
                      }
                  }

                  // Field to add new interest
                  HStack {
                      TextField("New interest", text: $newInterest)
                          .textFieldStyle(RoundedBorderTextFieldStyle())
                      Button(action: addInterest) {
                          Image(systemName: "plus.circle.fill")
                              .font(.title2)
                      }
                      .disabled(newInterest.trimmingCharacters(in: .whitespaces).isEmpty)
                  }
              } else {
                  // Read-only tags
                  LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                      ForEach(profile.interests, id: \.self) { interest in
                          Text(interest)
                              .font(.subheadline)
                              .padding(.vertical, 6)
                              .padding(.horizontal, 12)
                              .background(Color(.systemGray5))
                              .cornerRadius(16)
                      }
                  }
              }
          }
      }

      private func addInterest() {
          let trimmed = newInterest.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty, !profile.interests.contains(trimmed) else { return }
          profile.interests.append(trimmed)
          newInterest = ""
      }
    
    // MARK: Navigation Link
    private var activitiesLink: some View {
        NavigationLink(destination: MyActivitiesView()) { // Assuming MyActivitiesView exists
            HStack {
                Text("View My Activities")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Edit/Save Button
    private var editButton: some View {
        Button(action: {
            withAnimation { isEditing.toggle() }
            // TODO: Add save logic if isEditing was true and now is false
            // if !isEditing { profileVM.saveProfile(profile) }
        }) {
            Text(isEditing ? "Save Profile" : "Edit Profile")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isEditing ? Color.green : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: Actions
    private func changePhoto() {
        // TODO: implement photo picker & upload logic
        print("Change photo tapped")
    }
}

// MARK: - Profile Container (Simplified to use ProfileView with Bell)
struct ProfileContainerView: View {
    // The Picker, selectedTab, and explicit NavigationStack from the old version are removed.
    // ProfileView now handles its own navigation context and provides the bell icon.

    var body: some View {
        // Pass `true` to `shouldShowNotificationBell` to make ProfileView display the bell icon.
        ProfileView(shouldShowNotificationBell: true)
    }
}

// MARK: - ViewModel for Friend Requests
@MainActor
class FriendRequestsViewModel: ObservableObject {
    @Published var requests: [FriendRequest] = []
    @Published var senders: [String: UserProfile] = [:]     // ← cache of sender profiles
    @Published var errorMessage: String?

    private let service = FirestoreService.shared
    private var requestListener: ListenerRegistration?
    private var profileListeners: [String: ListenerRegistration] = [:]

    func startListening() {
        guard requestListener == nil,
              let uid = Auth.auth().currentUser?.uid
        else { return }

        // 1) Listen for incoming FriendRequest docs
        requestListener = service.listenIncomingFriendRequests(userId: uid) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let reqs):
                    self?.requests = reqs
                    self?.trackSenderProfiles(for: reqs)

                case .failure(let err):
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }

    private func trackSenderProfiles(for requests: [FriendRequest]) {
        // Stop listening to any senders no longer in the list
        let newSenderIds = Set(requests.map(\.senderId))
        for (senderId, listener) in profileListeners where !newSenderIds.contains(senderId) {
            listener.remove()
            profileListeners.removeValue(forKey: senderId)
            senders.removeValue(forKey: senderId)
        }

        // Start listening for any new senders
        for req in requests {
            let senderId = req.senderId
            guard profileListeners[senderId] == nil else { continue }

            let listener = service.listenToUser(userId: senderId) { [weak self] result in
                DispatchQueue.main.async {
                    if case .success(let profile) = result {
                        self?.senders[senderId] = profile
                    }
                }
            }

            profileListeners[senderId] = listener
        }
    }

    func stopListening() {
        // Tear down both sets of listeners
        requestListener?.remove()
        requestListener = nil

        for listener in profileListeners.values {
            listener.remove()
        }
        profileListeners.removeAll()
    }

    func respond(to request: FriendRequest, accept: Bool) {
        service.respondToFriendRequest(request, accept: accept) { [weak self] result in
            if case .failure(let err) = result {
                Task { @MainActor in
                    self?.errorMessage = err.localizedDescription
                }
            }
        }
    }
}


struct FriendRequestsView: View {
    @StateObject private var vm = FriendRequestsViewModel()

    var body: some View {
        VStack {
            if vm.requests.isEmpty {
                Text("No new friend requests.")
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(vm.requests) { req in
                        HStack(spacing: 16) {
                            // 1) Show sender's image if loaded, else placeholder
                            ProfileImageView(
                                urlString: vm.senders[req.senderId]?.photoURL,
                                size: 50
                            )

                            VStack(alignment: .leading) {
                                // 2) Show displayName when known, else raw ID
                                Text(vm.senders[req.senderId]?.displayName
                                     ?? req.senderId)
                                    .font(.headline)
                                Text(req.timestamp.dateValue(), style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            HStack {
                                Button("Accept") {
                                    vm.respond(to: req, accept: true)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .padding(.horizontal)

                                Button("Reject") {
                                    vm.respond(to: req, accept: false)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Requests")
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
    }
}

import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
  @Binding var image: UIImage?

  func makeUIViewController(context: Context) -> PHPickerViewController {
    var config = PHPickerConfiguration(photoLibrary: .shared())
    config.filter = .images
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  class Coordinator: NSObject, PHPickerViewControllerDelegate {
    let parent: ImagePicker
    init(_ parent: ImagePicker) { self.parent = parent }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
      picker.dismiss(animated: true)
      guard let provider = results.first?.itemProvider,
            provider.canLoadObject(ofClass: UIImage.self) else { return }
      provider.loadObject(ofClass: UIImage.self) { image, _ in
        DispatchQueue.main.async {
          self.parent.image = image as? UIImage
        }
      }
    }
  }
}
