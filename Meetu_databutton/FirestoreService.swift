//
//  FirestoreService.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//


import Foundation
import FirebaseFirestore
import FirebaseFirestore

class FirestoreService {
    private let db = Firestore.firestore()

    func fetchActivities(completion: @escaping ([Activity]) -> Void) {
        print("📡 Starting fetchActivities()…")
        db.collection("activities")
          .order(by: "createdAt", descending: true)
          .getDocuments { snapshot, error in

            if let error = error {
                print("❌ Error fetching activities: \(error)")
                completion([])
                return
            }

            guard let snapshot = snapshot else {
                print("⚠️ No snapshot returned.")
                completion([])
                return
            }

            print("✅ Fetched snapshot, documents.count = \(snapshot.documents.count)")

            let activities: [Activity] = snapshot.documents.compactMap { doc in
                do {
                    let activity = try doc.data(as: Activity.self)
                    print("   • decoded Activity id=\(doc.documentID) → \(activity.title)")
                    return activity
                } catch {
                    print("   ‼️ Failed to decode doc id=\(doc.documentID), data=\(doc.data()), error=\(error)")
                    return nil
                }
            }

            print("🏁 Parsed activities.count = \(activities.count)")
            completion(activities)
          }
    }
    /// Join an activity by adding the current userId to participantIds
      func joinActivity(activityId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
          let ref = db.collection("activities").document(activityId)
          ref.updateData([
              "participantIds": FieldValue.arrayUnion([userId])
          ]) { err in
              if let err = err {
                  print("❌ Failed to join: \(err)")
                  completion(.failure(err))
              } else {
                  print("✅ Joined activity \(activityId)")
                  completion(.success(()))
              }
          }
      }

      /// Leave an activity by removing the current userId from participantIds
      func leaveActivity(activity: Activity, currentUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
          // Prevent creator from leaving
          guard activity.createdBy.userId != currentUserId else {
              let err = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Creator cannot leave their own activity"])
              completion(.failure(err))
              return
          }
          
          let ref = db.collection("activities").document(activity.id!)
          ref.updateData([
              "participantIds": FieldValue.arrayRemove([currentUserId])
          ]) { err in
              if let err = err {
                  print("❌ Failed to leave: \(err)")
                  completion(.failure(err))
              } else {
                  print("✅ Left activity \(activity.id!)")
                  completion(.success(()))
              }
          }
      }

}
