import Foundation
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var user: User?            // Firebase `User`
    @Published var authError: String?

    private var handle: AuthStateDidChangeListenerHandle?

    func listen() {
        // Start listening to auth changes
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
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
                    // Optionally set display name
                    let change = user.createProfileChangeRequest()
                    change.displayName = displayName
                    change.commitChanges { _ in }
                    self?.authError = nil
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            self.authError = error.localizedDescription
        }
    }
}
