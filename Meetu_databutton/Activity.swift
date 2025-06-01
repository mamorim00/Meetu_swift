import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable, Equatable {
    @DocumentID var id: String?   
    var displayName: String
    var email: String?
    var photoURL: String?
    var friends: [String] // list of user IDs
    var displayName_lowercase: String? // <-- Add this line
}


struct Activity: Identifiable, Codable {
    @DocumentID var id: String?
    
    // Firestore fields
    var title: String
    var description: String
    var category: String
    var location: String
    var dateTime: String
    var isPublic: Bool
    var bio: String?
    var title_lowercase: String
    
    var archived: Bool
    // nested under `createdBy`
    var createdBy: Creator
    
    var maxParticipants: Int
    var participantIds: [String]
    var latitude: Double
    var longitude: Double
    
    struct Creator: Codable {
        var displayName: String
        var userId: String
    }
    
    // Only needed if you want convenience flat access:
    var displayName: String { createdBy.displayName }
    var userId: String       { createdBy.userId }
    
    
}


