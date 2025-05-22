//
//  CreateView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//



import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct CreateView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var dateTime = Date()
    @State private var isPublic = true
    @State private var maxParticipants = 10
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Activity Info")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    TextField("Location", text: $location)
                    DatePicker("Date & Time", selection: $dateTime, displayedComponents: [.date, .hourAndMinute])
                }

                Section(header: Text("Settings")) {
                    Toggle("Public", isOn: $isPublic)
                    Stepper(value: $maxParticipants, in: 2...100) {
                        Text("Max Participants: \(maxParticipants)")
                    }
                }

                Section {
                    Button(action: createActivity) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create Activity")
                        }
                    }
                    .disabled(title.isEmpty || description.isEmpty || location.isEmpty)
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Activity")
        }
    }

    private func createActivity() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You must be logged in."
            return
        }

        isCreating = true
        errorMessage = nil

        let db = Firestore.firestore()
        let activityId = UUID().uuidString
        let activityData: [String: Any] = [
            "id": activityId,
            "title": title,
            "title_lower": title.lowercased(),
            "description": description,
            "location": location,
            "latitude": 0.0,  // Optional: update later with MapKit
            "longitude": 0.0,
            "dateTime": Timestamp(date: dateTime),
            "isPublic": isPublic,
            "maxParticipants": maxParticipants,
            "participantIds": [user.uid],
            "createdBy": user.uid,
            "displayName": user.displayName ?? "Unknown",
            "createdAt": Timestamp(date: Date())
        ]

        db.collection("activities").document(activityId).setData(activityData) { error in
            isCreating = false
            if let error = error {
                errorMessage = "Failed to create activity: \(error.localizedDescription)"
            } else {
                print("✅ Activity created")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
