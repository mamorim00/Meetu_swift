import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var user: User?            // Firebase `User`
    @Published var authError: String?
    @Published var userProfile: UserProfile?  // your app's user model

    private var handle: AuthStateDidChangeListenerHandle?

    // Start listening to Auth state changes
    func listen() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
            }
            if let uid = user?.uid {
                self?.fetchUserProfile(uid: uid)
            } else {
                DispatchQueue.main.async {
                    self?.userProfile = nil
                }
            }
        }
    }

    // Clean up listener
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func fetchUserProfile(uid: String) {
        let db = Firestore.firestore()
        db.collection("userProfiles")
          .document(uid)
          .getDocument(as: UserProfile.self) { result in
              switch result {
              case .success(let profile):
                  DispatchQueue.main.async {
                      self.userProfile = profile
                  }
              case .failure(let error):
                  print("Error loading user: \(error)")
              }
          }
    }


    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let err = error {
                    self?.authError = err.localizedDescription
                } else {
                    self?.authError = nil
                }
            }
        }
    }

    func register(email: String, password: String, displayName: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let err = error {
                    self?.authError = err.localizedDescription
                } else if let user = result?.user {
                    // 1) Set the Firebase Auth displayName
                    let change = user.createProfileChangeRequest()
                    change.displayName = displayName
                    change.commitChanges { _ in }

                    // 2) Create your `UserProfile` model and write it to Firestore
                    let profile = UserProfile(
                        id: user.uid,
                        displayName: displayName,
                        email: user.email,
                        photoUrl: nil,
                        friends: []
                    )
                    let db = Firestore.firestore()
                    do {
                        try db.collection("userProfiles")
                            .document(user.uid)
                            .setData(from: profile) { writeError in
                                if let writeError = writeError {
                                    print("❌ Failed writing user profile: \(writeError)")
                                    self?.authError = writeError.localizedDescription
                                } else {
                                    // Immediately update `userProfile` so UI flips over without round-trip
                                    DispatchQueue.main.async {
                                        self?.userProfile = profile
                                        self?.authError = nil
                                    }
                                }
                            }
                    } catch {
                        print("❌ Serialization error: \(error)")
                        self?.authError = error.localizedDescription
                    }
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.user = nil
                self.userProfile = nil
            }
        } catch {
            self.authError = error.localizedDescription
        }
    }
}
