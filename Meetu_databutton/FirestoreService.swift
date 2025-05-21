import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class FirestoreService {
    private let db = Firestore.firestore()

    func fetchActivities(completion: @escaping ([Activity]) -> Void) {
        db.collection("activities")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching activities: \(error)")
                    completion([])
                    return
                }

                let activities = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Activity.self)
                } ?? []

                completion(activities)
            }
    }
}
