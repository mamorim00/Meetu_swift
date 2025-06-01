//
//  ChatView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//


//
//  ChatView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore

// MARK: — Chat List Models & ViewModel

struct Chat: Identifiable {
    let id: String             // activityId / chatId
    let name: String           // activity title
    let lastMessage: String?   // Firestore `lastMessage`
    let lastUpdated: Date?     // Firestore `lastMessageTimestamp`
}

final class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []

    private let rtdb = Database.database().reference()
    private let firestore = Firestore.firestore()
    private var rtdbHandle: DatabaseHandle?

    func fetchChats() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("ChatListViewModel: User not authenticated.")
            return
        }

        // Clean up any previous observer
        if let handle = rtdbHandle {
            rtdb.child("user-chats").child(currentUserID)
                .removeObserver(withHandle: handle)
            rtdbHandle = nil
        }

        // 1️⃣ Observe only the current user's chat index
        rtdbHandle = rtdb
            .child("user-chats")
            .child(currentUserID)
            .observe(.value) { [weak self] snap in
                guard let self = self else { return }

                // 2️⃣ Collect the activityIds this user is in
                let chatIds = snap.children
                    .compactMap { ($0 as? DataSnapshot)?.key }
                guard !chatIds.isEmpty else {
                    // No chats: clear UI
                    DispatchQueue.main.async { self.chats = [] }
                    return
                }

                // 3️⃣ Batch-fetch all corresponding Firestore docs
                self.firestore
                    .collection("activities")
                    .whereField(FieldPath.documentID(), in: chatIds)
                    .getDocuments { result, error in
                        if let error = error {
                            print("Error fetching activities:", error)
                            return
                        }
                        guard let docs = result?.documents else { return }

                        // 4️⃣ Map into your Chat model
                        let loaded = docs.map { doc -> Chat in
                            let d = doc.data()
                            let title = d["title"] as? String ?? "Untitled Activity"
                            let lastMsg = (d["lastMessage"] as? String)
                                       ?? (d["lastMessage"] as? [String:Any])?["text"] as? String
                            let ts = (d["lastMessageTimestamp"] as? Timestamp)?.dateValue()
                            return Chat(
                              id: doc.documentID,
                              name: title,
                              lastMessage: lastMsg,
                              lastUpdated: ts
                            )
                        }
                        .sorted {
                            ($0.lastUpdated ?? .distantPast)
                            > ($1.lastUpdated ?? .distantPast)
                        }

                        // 5️⃣ Push to UI
                        DispatchQueue.main.async {
                            self.chats = loaded
                        }
                    }
            }
    }

    deinit {
        if let handle = rtdbHandle {
            rtdb.child("activity-chats").removeObserver(withHandle: handle)
        }
    }
}

// MARK: — Chat List View

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @Environment(\.colorScheme) var colorScheme

    // 1️⃣ Read the binding from the environment that App injects
    @Environment(\.selectedChatId) private var selectedChatId

    // 2️⃣ Local @State to drive NavigationLink
    @State private var navChatId: String? = nil

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.chats) { chat in
                    ZStack {
                        // 3️⃣ Invisible NavigationLink bound to navChatId
                        NavigationLink(
                            destination: ChatView(chatId: chat.id, chatTitle: chat.name),
                            tag: chat.id,
                            selection: $navChatId
                        ) {
                            EmptyView()
                        }
                        .opacity(0)

                        ChatRowView(chat: chat)
                            .onTapGesture {
                                // If user taps manually, navigate to that chat
                                navChatId = chat.id
                            }
                    }
                    .listRowBackground(Color.appBackground(for: colorScheme))
                    .listRowSeparatorTint(Color.appBorder(for: colorScheme))
                }
            }
            .background(Color.appBackground(for: colorScheme).edgesIgnoringSafeArea(.all))
            .navigationTitle("Chats")
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .onAppear {
                viewModel.fetchChats()
            }
            // 4️⃣ Watch for changes to the environment’s selectedChatId
            .onChange(of: selectedChatId.wrappedValue) { newValue in
                if let chatId = newValue {
                    navChatId = chatId
                    // Reset so future notifications work
                    selectedChatId.wrappedValue = nil
                }
            }
        }
        .accentColor(Color.appAccent(for: colorScheme))
    }
}

private struct ChatRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.name)
                    .font(.headline)
                    .foregroundColor(Color.appForeground(for: colorScheme))
                if let last = chat.lastMessage {
                    Text(last)
                        .font(.subheadline)
                        .foregroundColor(Color.appMutedForeground(for: colorScheme))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

// (Leave the rest of your ChatView, ChatViewModel, etc. unchanged.)

// MARK: — Chat ViewModel & Message Model

struct FirestoreChatMessage: Identifiable {
    let id: String
    let senderId: String
    let senderName: String?
    let text: String
    let timestamp: Date?
}

final class ChatViewModel: ObservableObject {
    @Published var messages: [FirestoreChatMessage] = []
    @Published var newMessage: String = ""

    private let chatId: String
    private let rtdbRef: DatabaseReference
    private let firestore = Firestore.firestore()
    private var rtdbHandle: DatabaseHandle?
    @Published var userProfiles: [String: Profile] = [:]


    init(chatId: String) {
        self.chatId = chatId
        self.rtdbRef = Database.database()
            .reference()
            .child("chat-messages")
            .child(chatId)
        subscribeToMessages()
    }

    deinit {
        if let handle = rtdbHandle {
            rtdbRef.removeObserver(withHandle: handle)
        }
    }

    private func subscribeToMessages() {
        rtdbHandle = rtdbRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var loaded: [FirestoreChatMessage] = []

            for case let child as DataSnapshot in snapshot.children {
                guard
                    let dict = child.value as? [String: Any],
                    let senderId = dict["senderId"] as? String,
                    let text     = dict["text"]     as? String,
                    let tsNumber = dict["timestamp"] as? TimeInterval
                   
                else { continue }
                let senderName = dict["senderName"] as? String  // new
                let date = Date(timeIntervalSince1970: tsNumber / 1000)
                let msg = FirestoreChatMessage(
                    id: child.key,
                    senderId: senderId,
                    senderName: senderName,
                    text: text,
                    timestamp: date
                )
                loaded.append(msg)
            }

            loaded.sort {
                ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast)
            }
            DispatchQueue.main.async {
                self.messages = loaded
            }
            
            let toFetch = Set(self.messages.map(\.senderId))
                            .subtracting(self.userProfiles.keys)

            for uid in toFetch {
              Firestore.firestore()
                .collection("userProfiles")
                .document(uid)
                .getDocument { snap, _ in
                  guard
                    let data = snap?.data(),
                    let displayName = data["displayName"] as? String
                  else { return }
                  let photoURL = data["photoURL"] as? String

                  DispatchQueue.main.async {
                    self.userProfiles[uid] = Profile(
                      bio:           data["bio"]          as? String ?? "",
                      createdAt:     Date(), // not used here
                      displayName:   displayName,
                      email:         data["email"]        as? String ?? "",
                      friends:       data["friends"]      as? [String] ?? [],
                      interests:     data["interests"]    as? [String] ?? [],
                      lastLoginAt:   Date(), // not used
                      location:      data["location"]     as? String ?? "",
                      userId:        uid,
                      photoURL:      photoURL
                    )
                  }
                }
            }
        }
    }

    func sendMessage() {
        guard
            let user = Auth.auth().currentUser,
            !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        let text = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let ts = Date().timeIntervalSince1970 * 1000  // ms

        let newRef = rtdbRef.childByAutoId()
        let payload: [String:Any] = [
            "senderId":   user.uid,
            "senderName": user.displayName ?? "Anonymous",
            "text":       text,
            "timestamp":  ts
        ]

        newRef.setValue(payload) { error, _ in
            if let error = error {
                print("❌ RTDB send error:", error.localizedDescription)
                return
            }
            // Update Firestore metadata
            let chatDoc = self.firestore.collection("activities").document(self.chatId)
            chatDoc.updateData([
                "lastMessage":          text,
                "lastMessageTimestamp": Timestamp(date: Date())
            ]) { err in
                if let err = err {
                    print("❌ Firestore metadata update:", err.localizedDescription)
                }
            }
            DispatchQueue.main.async {
                self.newMessage = ""
            }
        }
    }
}
// MARK: — Chat View

struct ChatView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) var colorScheme // << ADDED

    let chatId: String
    let chatTitle: String
    @StateObject private var vm: ChatViewModel

    init(chatId: String, chatTitle: String = "Chat") {
        self.chatId = chatId
        self.chatTitle = chatTitle
        _vm = StateObject(wrappedValue: ChatViewModel(chatId: chatId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.medium))
                        .foregroundColor(Color.appAccent(for: colorScheme)) // << THEMED
                }
                Text(chatTitle)
                    .font(.headline)
                    .foregroundColor(Color.appForeground(for: colorScheme)) // << THEMED
                Spacer()
                // You could add a call button or info button here
            }
            .padding()
            .frame(height: 56) // Consistent header height
            .background(Color.chatHeaderBackground(for: colorScheme).edgesIgnoringSafeArea(.top)) // << THEMED
            .overlay(Divider().background(Color.appBorder(for: colorScheme)), alignment: .bottom) // << THEMED

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) { // Increased spacing between messages
                        ForEach(vm.messages) { msg in
                            messageRow(msg) // Will use colorScheme from environment
                        }
                        Color.clear.frame(height: 1).id("bottom") // Anchor for scrolling
                    }
                    .padding(.horizontal) // Padding for message bubbles from screen edges
                    .padding(.vertical, 10)
                }
                .background(Color.appBackground(for: colorScheme)) // << THEMED
                .onTapGesture { // Dismiss keyboard on tap
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onChange(of: vm.messages.count) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onAppear { // Scroll to bottom when view appears if messages exist
                    if !vm.messages.isEmpty {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            Divider().background(Color.appBorder(for: colorScheme)) // << THEMED

            // Input field
            HStack(spacing: 12) {
                TextField("Type a message…", text: $vm.newMessage, onCommit: vm.sendMessage)
                    .placeholder(when: vm.newMessage.isEmpty) { // Custom placeholder extension needed for color
                        Text("Type a message…").foregroundColor(Color.appInputPlaceholder(for: colorScheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.appInputBackground(for: colorScheme)) // << THEMED
                        // Optional: Add a border
                        // .stroke(Color.appBorder(for: colorScheme), lineWidth: 1)
                    )
                    .foregroundColor(Color.appForeground(for: colorScheme)) // << THEMED Text color
                    .frame(minHeight: 40) // Consistent height

                Button { vm.sendMessage() } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(vm.newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.appMutedForeground(for: colorScheme) : Color.appAccent(for: colorScheme)) // << THEMED
                        .rotationEffect(.degrees(45))
                }
                .disabled(vm.newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.chatInputBarBackground(for: colorScheme).edgesIgnoringSafeArea(.bottom)) // << THEMED
        }
        .background(Color.appBackground(for: colorScheme).edgesIgnoringSafeArea(.all)) // << THEMED Overall background
        .navigationBarHidden(true)
    }
    @ViewBuilder
    private func messageRow(_ msg: FirestoreChatMessage) -> some View {
        let isMine = msg.senderId == Auth.auth().currentUser?.uid

        // Lookup cached profile
        let profile     = vm.userProfiles[msg.senderId]
        let displayName = profile?.displayName
            ?? msg.senderName
            ?? "Anonymous"
        let photoURL    = profile?.photoURL

        HStack(alignment: .bottom, spacing: 8) {
            if !isMine {
                // ◉ Profile picture
                ProfileImageView(urlString: photoURL, size: 36)
                    .padding(.bottom, msg.timestamp != nil ? 4 : 0)

                VStack(alignment: .leading, spacing: 2) {
                    // ◉ Display name
                    Text(displayName)
                        .font(.caption2).bold()
                        .foregroundColor(.secondary)

                    // ◉ Message bubble
                    Text(msg.text)
                        .font(.body)
                        .padding(10)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                // ◉ Own message bubble (no avatar)
                Text(msg.text)
                    .font(.body)
                    .padding(10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}



// MARK: — Simple AvatarView

struct AvatarView: View {
    @Environment(\.colorScheme) var colorScheme // << ADDED
    let name: String
    var body: some View {
        let initials = name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()

        Text(initials.isEmpty ? "?" : initials) // Handle empty names
            .font(.system(size: 16, weight: .medium)) // Slightly larger font for avatar
            .foregroundColor(Color.avatarForeground(for: colorScheme)) // << THEMED
            .frame(width: 36, height: 36) // Standard avatar size
            .background(Color.avatarBackground(for: colorScheme)) // << THEMED
            .clipShape(Circle()) // Use Circle for a perfect circle
    }
}


// MARK: - View Extension for Placeholder
// Add this extension to your project, e.g., in a ViewModifiers.swift file

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
