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
        guard Auth.auth().currentUser != nil else { return }

        rtdbHandle = rtdb
            .child("activity-chats")
            .observe(.value) { [weak self] snapshot in
                guard let self = self else { return }
                var loaded: [Chat] = []
                let group = DispatchGroup()

                for case let child as DataSnapshot in snapshot.children {
                    let activityId = child.key
                    group.enter()

                    self.firestore
                        .collection("activities")
                        .document(activityId)
                        .getDocument { docSnap, _ in
                            defer { group.leave() }
                            guard
                                let data = docSnap?.data()
                            else { return }

                            let title = data["title"] as? String ?? "Activity"
                            let lastMsgText = (data["lastMessage"] as? String)
                                ?? (data["lastMessage"] as? [String:Any])?["text"] as? String
                            let ts = (data["lastMessageTimestamp"] as? Timestamp)?
                                .dateValue()

                            loaded.append(
                                Chat(
                                    id: activityId,
                                    name: title,
                                    lastMessage: lastMsgText,
                                    lastUpdated: ts
                                )
                            )
                        }
                }

                group.notify(queue: .main) {
                    self.chats = loaded
                        .sorted {
                            ($0.lastUpdated ?? .distantPast) > ($1.lastUpdated ?? .distantPast)
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

// MARK: — Chat ViewModel & Message Model

struct FirestoreChatMessage: Identifiable {
    let id: String
    let senderId: String
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

                let date = Date(timeIntervalSince1970: tsNumber / 1000)
                let msg = FirestoreChatMessage(
                    id: child.key,
                    senderId: senderId,
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

// MARK: — Chat List View

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()

    var body: some View {
        NavigationView {
            List(viewModel.chats) { chat in
                NavigationLink(destination: ChatView(chatId: chat.id, chatTitle: chat.name)) {
                    ChatRowView(chat: chat)
                }
            }
            .navigationTitle("Chats")
            .onAppear { viewModel.fetchChats() }
        }
    }
}

private struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        HStack {
            Text(chat.name).font(.headline)
            Spacer()
            if let last = chat.lastMessage {
                Text(last)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: — Chat View

struct ChatView: View {
    @Environment(\.presentationMode) private var presentationMode
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
                }
                Text(chatTitle).font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .overlay(Divider(), alignment: .bottom)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.messages) { msg in
                            messageRow(msg)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input field
            HStack {
                TextField("Type a message…", text: $vm.newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 36)

                Button { vm.sendMessage() } label: {
                    Image(systemName: "paperplane.fill")
                        .rotationEffect(.degrees(45))
                }
                .disabled(vm.newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.leading, 4)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func messageRow(_ msg: FirestoreChatMessage) -> some View {
        let isMine = msg.senderId == Auth.auth().currentUser?.uid
        HStack(alignment: .bottom, spacing: 8) {
            if !isMine { AvatarView(name: msg.senderId) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    Text(msg.senderId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(msg.text)
                    .padding(10)
                    .background(isMine ? Color.accentColor : Color(.systemGray5))
                    .foregroundColor(isMine ? .white : .primary)
                    .cornerRadius(12)
                if let date = msg.timestamp {
                    Text(date, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            if isMine { AvatarView(name: "You") }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}

// MARK: — Simple AvatarView

struct AvatarView: View {
    let name: String
    var body: some View {
        let initials = name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()

        Text(initials)
            .font(.caption2)
            .frame(width: 32, height: 32)
            .background(Color(.systemGray4))
            .cornerRadius(16)
    }
}
