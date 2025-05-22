//
//  FirestoreService.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//


import Foundation
import FirebaseFirestore
import FirebaseFirestore

enum FirestoreServiceError: Error {
    case noData
    case decodingFailed(Error)
    case underlying(Error)
}


class FirestoreService {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private init() {}
     
    
    // Send a friend request
    func sendFriendRequest(from sender: UserProfile, to receiver: UserProfile, completion: @escaping(Result<Void, Error>) -> Void) {
        let req = FriendRequest(
            id: nil,
            senderId: sender.id!,
            receiverId: receiver.id!,
            status: "pending",
            timestamp: Timestamp(date: Date())
        )
        do {
            _ = try db.collection("friendRequests").addDocument(from: req)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    // Observe incoming requests
    func observeIncomingRequests(for userId: String, handler: @escaping([FriendRequest]) -> Void) -> ListenerRegistration {
        return db.collection("friendRequests")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, _ in
                let requests = snapshot?.documents.compactMap { try? $0.data(as: FriendRequest.self) } ?? []
                handler(requests)
            }
    }

    // Update request status (accept or reject)
    func updateRequest(_ request: FriendRequest, to newStatus: String, completion: @escaping(Result<Void, Error>) -> Void) {
        guard let requestId = request.id else { return }
        db.collection("friendRequests").document(requestId).updateData([
            "status": newStatus
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // Check for a pending friend request between two users
    func checkPendingRequest(from senderId: String, to receiverId: String, completion: @escaping(Bool) -> Void) {
        db.collection("friendRequests")
            .whereField("senderId", isEqualTo: senderId)
            .whereField("receiverId", isEqualTo: receiverId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, _ in
                let hasPending = (snapshot?.documents.count ?? 0) > 0
                completion(hasPending)
            }
    }

    func fetchUser(withId id: String,
                   completion: @escaping (Result<UserProfile, Error>) -> Void)
    {
      db.collection("userProfiles")       // ← make sure this matches your actual collection
        .document(id)
        .getDocument { snapshot, error in
          if let error = error {
            completion(.failure(error))
            return
          }
          guard let snapshot = snapshot else {
            completion(.failure(FirestoreServiceError.noData))
            return
          }
          do {
            let user = try snapshot.data(as: UserProfile.self)
            completion(.success(user))
          } catch {
            completion(.failure(FirestoreServiceError.decodingFailed(error)))
          }
        }
    }
    
    /// Search activities by title prefix (case-sensitive).
        func searchActivities(by text: String,
                              completion: @escaping ([Activity]) -> Void)
        {
            let endText = text + "\u{f8ff}"
            db.collection("activities")
              .order(by: "title")
              .start(at: [text])
              .end(at: [endText])
              .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ searchActivities error:", error)
                    completion([])
                    return
                }
                let acts = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Activity.self)
                } ?? []
                completion(acts)
            }
        }

        /// Search users by displayName prefix.
    func searchUsers(by text: String, completion: @escaping ([UserProfile]) -> Void) {
      let db = Firestore.firestore()
      db.collection("userProfiles")
        .whereField("displayName_lowercase", isGreaterThanOrEqualTo: text)
        .whereField("displayName_lowercase", isLessThanOrEqualTo: text + "\u{f8ff}")
        .getDocuments { snapshot, error in
          guard let docs = snapshot?.documents else {
            completion([])
            return
          }

          let users: [UserProfile] = docs.compactMap { doc in
            try? doc.data(as: UserProfile.self)
          }

          DispatchQueue.main.async {
            completion(users)
          }
        }
    }


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
