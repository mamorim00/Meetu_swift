//
//  FirestoreService.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//


import Foundation
import FirebaseFirestore
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import FirebaseDatabase

enum FirestoreServiceError: Error {
    case noData
    case decodingFailed(Error)
    case underlying(Error)
}


class FirestoreService {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Listener storage
    private var listeners: [ListenerRegistration] = []

    /// Remove all active listeners (call on view disappear)
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: - Real-time Listeners

    /// Listen to a user profile document in real time
    @discardableResult
    func listenToUser(
        userId: String,
        callback: @escaping (Result<UserProfile, Error>) -> Void
    ) -> ListenerRegistration {
        let ref = db.collection("userProfiles").document(userId)
        let listener = ref.addSnapshotListener { snapshot, error in
            if let error = error {
                callback(.failure(error))
                return
            }
            guard let snap = snapshot else { return }
            do {
                let user = try snap.data(as: UserProfile.self)
                callback(.success(user))
            } catch {
                callback(.failure(error))
            }
        }
        listeners.append(listener)
        return listener
    }

    /// Listen to the friend-request between two users in real time
    // MARK: – Outgoing single friend‐request listener
    @discardableResult
    func listenToOutgoingFriendRequest(
        from senderId: String,
        to receiverId: String,
        callback: @escaping (Result<FriendRequest?, Error>) -> Void
    ) -> ListenerRegistration {
        let query = db.collection("friendRequests")
            .whereField("senderId",   isEqualTo: senderId)
            .whereField("receiverId", isEqualTo: receiverId)
            .limit(to: 1)

        let listener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                callback(.failure(error))
                return
            }
            guard let doc = snapshot?.documents.first else {
                callback(.success(nil))  // no outgoing request
                return
            }
            do {
                let req = try doc.data(as: FriendRequest.self)
                callback(.success(req))
            } catch {
                callback(.failure(error))
            }
        }
        listeners.append(listener)
        return listener
    }

    // MARK: – Incoming single friend‐request listener
    @discardableResult
    func listenToIncomingFriendRequest(
        from senderId: String,
        to receiverId: String,
        callback: @escaping (Result<FriendRequest?, Error>) -> Void
    ) -> ListenerRegistration {
        let query = db.collection("friendRequests")
            .whereField("senderId",   isEqualTo: senderId)
            .whereField("receiverId", isEqualTo: receiverId)
            .whereField("status",     isEqualTo: "pending")
            .limit(to: 1)

        let listener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                callback(.failure(error))
                return
            }
            guard let doc = snapshot?.documents.first else {
                callback(.success(nil))  // no pending incoming request
                return
            }
            do {
                let req = try doc.data(as: FriendRequest.self)
                callback(.success(req))
            } catch {
                callback(.failure(error))
            }
        }
        listeners.append(listener)
        return listener
    }


    // MARK: - Friend Request Operations

    func sendFriendRequest(
        from sender: UserProfile,
        to receiver: UserProfile,
        completion: @escaping(Result<Void, Error>) -> Void
    ) {
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

    func observeIncomingRequests(
        for userId: String,
        handler: @escaping([FriendRequest]) -> Void
    ) -> ListenerRegistration {
        return db.collection("friendRequests")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, _ in
                let requests = snapshot?.documents.compactMap { try? $0.data(as: FriendRequest.self) } ?? []
                handler(requests)
            }
    }

    func updateRequest(
        _ request: FriendRequest,
        to newStatus: String,
        completion: @escaping(Result<Void, Error>) -> Void
    ) {
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

    func checkPendingRequest(
        from senderId: String,
        to receiverId: String,
        completion: @escaping(Bool) -> Void
    ) {
        db.collection("friendRequests")
            .whereField("senderId", isEqualTo: senderId)
            .whereField("receiverId", isEqualTo: receiverId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, _ in
                let hasPending = (snapshot?.documents.count ?? 0) > 0
                completion(hasPending)
            }
    }

       // MARK: – Real-time Friend-Request Listener
       func listenToFriendRequest(
           from senderId: String,
           to receiverId: String,
           callback: @escaping (Result<FriendRequest?, Error>) -> Void
       ) {
           let query = db.collection("friendRequests")
               .whereField("senderId",   isEqualTo: senderId)
               .whereField("receiverId", isEqualTo: receiverId)
               .limit(to: 1)

           let listener = query.addSnapshotListener { snapshot, error in
               if let error = error {
                   callback(.failure(error)); return
               }
               // if no docs, there's no pending request
               guard let doc = snapshot?.documents.first else {
                   callback(.success(nil))
                   return
               }
               do {
                   let req = try doc.data(as: FriendRequest.self)
                   callback(.success(req))
               } catch {
                   callback(.failure(error))
               }
           }
           listeners.append(listener)
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
    
    func searchActivities(by text: String,
                          completion: @escaping ([Activity]) -> Void)
    {
        let queryText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !queryText.isEmpty else {
            completion([])
            return
        }
        // highest Unicode char to cap the prefix range
        let endText = queryText + "\u{f8ff}"

        db.collection("activities")
          .order(by: "title_lowercase")
          .start(at: [queryText])
          .end(at: [endText])
          .getDocuments { snapshot, error in
            if let error = error {
                print("❌ searchActivities error:", error)
                completion([])
                return
            }
            let acts = snapshot?.documents.compactMap { try? $0.data(as: Activity.self) } ?? []
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
    
    func uploadProfileImage(userId: String, image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
      let storageRef = Storage.storage().reference()
        .child("profile_images/\(userId).jpg")

      guard let data = image.jpegData(compressionQuality: 0.8) else {
        return completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Image conversion failed"])))
      }

      storageRef.putData(data, metadata: nil) { _, error in
        if let error = error { return completion(.failure(error)) }
        storageRef.downloadURL { url, error in
          if let url = url { completion(.success(url)) }
          else { completion(.failure(error!)) }
        }
      }
    }

    func updateUserProfile(_ profile: Profile, completion: @escaping (Error?) -> Void) {
      let data: [String: Any] = [
        "displayName": profile.displayName,
        "bio":          profile.bio,
        "location":     profile.location,
        "interests":    profile.interests,
        "photoURL":     profile.photoURL ?? ""
      ]
      Firestore.firestore()
        .collection("userProfiles")
        .document(profile.userId)
        .setData(data, merge: true, completion: completion)
    }

    /// Fetch a single Activity by its document ID
       func fetchActivity(withId id: String,
                          completion: @escaping (Result<Activity, Error>) -> Void)
       {
           let docRef = db.collection("activities").document(id)
           docRef.getDocument { snapshot, error in
               if let error = error {
                   print("❌ Error fetching activity \(id):", error)
                   completion(.failure(error))
                   return
               }
               guard let snapshot = snapshot else {
                   print("⚠️ No snapshot returned for activity \(id).")
                   completion(.failure(FirestoreServiceError.noData))
                   return
               }
               do {
                   let activity = try snapshot.data(as: Activity.self)
                   print("✅ Fetched activity id=\(id) → \(activity.title)")
                   completion(.success(activity))
               } catch {
                   print("‼️ Failed to decode activity \(id), data=\(snapshot.data() ?? [:]), error=\(error)")
                   completion(.failure(FirestoreServiceError.decodingFailed(error)))
               }
           }
       }
    

    func listenActivities(
        excluding userId: String,
        completion: @escaping (Result<[Activity], Error>) -> Void
    ) -> ListenerRegistration {
        return db.collection("activities")
            .whereField("archived", isEqualTo: false)
            .order(by: "dateTime", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                // decode & filter out your own activities
                let activities: [Activity] = snapshot!.documents.compactMap { doc in
                    do {
                        var a = try doc.data(as: Activity.self)
                        a.id = doc.documentID
                        return a
                    } catch {
                        print("Decoding error: \(error)")
                        return nil
                    }
                }
                let filtered = activities.filter { $0.createdBy.userId != userId }
                completion(.success(filtered))
            }
    }

    func listenMyActivities(userId: String,
                                completion: @escaping (Result<[Activity], Error>) -> Void
        ) -> ListenerRegistration {
            let query = db.collection("activities")
                .whereField("createdBy.userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)

            return query.addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                let docs = snapshot?.documents ?? []
                let acts = docs.compactMap { doc -> Activity? in
                    try? doc.data(as: Activity.self)
                }
                completion(.success(acts))
            }
        }
    
    func listenIncomingFriendRequests(userId: String,
                                      completion: @escaping (Result<[FriendRequest], Error>) -> Void
    ) -> ListenerRegistration {
        let query = db.collection("friendRequests")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "timestamp", descending: true)

        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let docs = snapshot?.documents ?? []
            let requests = docs.compactMap { doc -> FriendRequest? in
                try? doc.data(as: FriendRequest.self)
            }
            completion(.success(requests))
        }
    }

    func respondToFriendRequest(_ request: FriendRequest, accept: Bool,
                                completion: @escaping (Result<Void, Error>) -> Void) {
        guard let requestId = request.id else { return }
        let ref = db.collection("friendRequests").document(requestId)
        ref.updateData(["status": accept ? "accepted" : "rejected"]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
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
    /// Delete an activity by its document ID
    func deleteActivity(activityId: String,
                        completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("activities")
          .document(activityId)
          .delete { error in
            if let error = error {
                print("❌ Failed to delete activity \(activityId): \(error)")
                completion(.failure(error))
            } else {
                print("✅ Deleted activity \(activityId)")
                completion(.success(()))
            }
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
    
    // MARK: - NEW: Update an existing activity
    /// Updates fields of an existing Activity document
    func updateActivity(_ activity: Activity, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let docId = activity.id else {
            completion(.failure(FirestoreServiceError.noData))
            return
        }
        do {
            let data = try Firestore.Encoder().encode(activity)
            db.collection("activities").document(docId).setData(data, merge: true) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    print("✅ Updated activity \(docId)")
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(FirestoreServiceError.decodingFailed(error)))
        }
    }

}
