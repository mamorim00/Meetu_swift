// MyActivitiesViewModel.swift

import Combine
import FirebaseAuth
import FirebaseFirestore

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
