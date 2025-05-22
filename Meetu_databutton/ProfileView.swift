import SwiftUI
import FirebaseAuth
import FirebaseStorage

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
    
}

// MARK: - Profile View
struct ProfileView: View {
    @StateObject private var authVM = AuthViewModel()
    @State private var isEditing = false
    
    var body: some View {
        Group {
            if authVM.user == nil {
                ProgressView("Loading profile...")
            } else if let user = authVM.user {
                let createdAt = user.metadata.creationDate ?? Date()
                let lastLoginAt = user.metadata.lastSignInDate ?? Date()
                let profile = Profile(
                    bio: "", // Load from Firestore if needed
                    createdAt: createdAt,
                    displayName: user.displayName ?? "",
                    email: user.email ?? "",
                    friends: [], // Populate from Firestore
                    interests: [], // Populate from Firestore
                    lastLoginAt: lastLoginAt,
                    location: "", // Load if stored
                    userId: user.uid
                )
                ProfileContent(profile: profile, isEditing: $isEditing)
            } else if let error = authVM.authError {
                Text(error)
                    .foregroundColor(.red)
            } else {
                Text("No user signed in.")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            authVM.listen()
        }
    }
}

// MARK: - Profile Content
struct ProfileContent: View {
    @State var profile: Profile
    @Binding var isEditing: Bool
    @State private var imageURL: URL?
    @State private var isLoadingImage = false
    @State private var imageError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let url = imageURL {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                        } else if isLoadingImage {
                            ProgressView()
                        } else if let _ = imageError {
                            Image(systemName: "exclamationmark.triangle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .shadow(radius: 8)
                    
                    if isEditing {
                        Button(action: changePhoto) {
                            Image(systemName: "camera.fill")
                                .padding(8)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .offset(x: -10, y: -10)
                    }
                }
                .onAppear(perform: fetchProfileImage)
                
                Group {
                    if isEditing {
                        TextField("Display Name", text: $profile.displayName)
                            .font(.title)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    } else {
                        Text(profile.displayName)
                            .font(.title)
                            .bold()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Me")
                        .font(.headline)
                    if isEditing {
                        TextEditor(text: $profile.bio)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    } else {
                        Text(profile.bio.isEmpty ? "No bio available." : profile.bio)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 20) {
                    Label(profile.location, systemImage: "mappin.and.ellipse")
                    Label("Friends: \(profile.friends.count)", systemImage: "person.2.fill")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interests")
                        .font(.headline)
                    FlexibleView(data: profile.interests, spacing: 8, alignment: .leading) { interest in
                        Text(interest)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Joined: \(formatted(date: profile.createdAt))")
                    Text("Last Login: \(formatted(date: profile.lastLoginAt))")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                
                Button(action: { withAnimation { isEditing.toggle() } }) {
                    Text(isEditing ? "Save" : "Edit Profile")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isEditing ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func changePhoto() {
        // Implement photo picker logic
    }
    
    private func fetchProfileImage() {
        isLoadingImage = true
        if let url = Auth.auth().currentUser?.photoURL {
            self.imageURL = url
            self.isLoadingImage = false
        } else {
            self.imageError = "No photo URL found."
            self.isLoadingImage = false
        }
    }

}

// MARK: - FlexibleView for Interests Chips
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    
    init(data: Data,
         spacing: CGFloat = 8,
         alignment: HorizontalAlignment = .leading,
         @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
    }
    
    private func generateContent(in g: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(Array(data), id: \ .self) { item in
                content(item)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading) { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        width -= d.width + spacing
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        return result
                    }
            }
        }
        .frame(height: -height)
    }
}
