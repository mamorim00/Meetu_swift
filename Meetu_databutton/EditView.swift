import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import MapKit
import CoreLocation

struct EditView: View {
    @Environment(\.presentationMode) var presentationMode

    var activityId: String
    @State var title: String
    @State var description: String
    @State var location: String
    @State var locationQuery: String
    @State var dateTime: Date
    @State var isPublic: Bool
    @State var maxParticipants: Int
    @State var category: String

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    @StateObject private var completerCoordinator = CompleterCoordinator()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Activity")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    
                    VStack(alignment: .leading) {
                        Text("Category")
                            .font(.headline)

                        Picker("Select a category", selection: $category) {
                            ForEach(["Sports","Dining","Hiking","Gaming","Movies","Travel","Music","Cooking"], id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        Text("Selected: \(category)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading) {
                        TextField("Location", text: $locationQuery)
                            .onChange(of: locationQuery) {
                                completerCoordinator.completer.queryFragment = locationQuery
                            }

                        ForEach(completerCoordinator.results, id: \.self) { result in
                            Button {
                                location = result.title + ", " + result.subtitle
                                locationQuery = location
                                completerCoordinator.results = []

                                let request = MKLocalSearch.Request(completion: result)
                                let search = MKLocalSearch(request: request)
                                search.start { response, error in
                                    if let coordinate = response?.mapItems.first?.placemark.coordinate {
                                        selectedCoordinate = coordinate
                                    } else {
                                        errorMessage = "Could not get coordinates."
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(result.title).fontWeight(.medium)
                                    Text(result.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    DatePicker("Date & Time", selection: $dateTime, displayedComponents: [.date, .hourAndMinute])
                }

                Section(header: Text("Settings")) {
                    Toggle("Public", isOn: $isPublic)
                    Stepper(value: $maxParticipants, in: 2...100) {
                        Text("Max Participants: \(maxParticipants)")
                    }
                }

                Section {
                    Button(action: saveChanges) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Changes")
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
            .navigationTitle("Edit Activity")
            .onAppear {
                locationQuery = location
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        errorMessage = nil

        let db = Firestore.firestore()
        var updateData: [String: Any] = [
            "title": title,
            "title_lowercase": title.lowercased(),
            "description": description,
            "location": location,
            "dateTime": Timestamp(date: dateTime),
            "isPublic": isPublic,
            "maxParticipants": maxParticipants,
            "category": category
        ]

        if let coordinate = selectedCoordinate {
            updateData["latitude"] = coordinate.latitude
            updateData["longitude"] = coordinate.longitude
        }

        db.collection("activities").document(activityId).updateData(updateData) { error in
            isSaving = false
            if let error = error {
                errorMessage = "Failed to update: \(error.localizedDescription)"
            } else {
                print("✅ Activity updated")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
