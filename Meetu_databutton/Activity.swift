import Foundation
import FirebaseFirestoreSwift

struct Activity: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var category: String
    var location: String
    var dateTime: String
    var isPublic: Bool
    var createdAt: Date?
    var userId: String
    var displayName: String
    var maxParticipants: Int
    var participantIds: [String]
    var latitude: Double
    var longitude: Double
}
