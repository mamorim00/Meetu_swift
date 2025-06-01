import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import MapKit
import CoreLocation

struct CreateView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var locationQuery = ""
    @State private var dateTime = Date()
    @State private var isPublic = true
    @State private var maxParticipants = 10
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var category: String = "Sports"

    
    // at the top of your struct…
    @StateObject private var completerCoordinator = CompleterCoordinator()
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Activity Info")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    VStack(alignment: .leading) {
                        Text("Category")
                            .font(.headline)

                        Picker("Select a category", selection: $category) {
                            ForEach([  "Sports","Dining","Hiking","Gaming","Movies","Travel","Music","Cooking",], id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(MenuPickerStyle()) // use .wheelPickerStyle() for iOS-style scrolling
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
                            Button(action: {
                                // Set the display string
                                location = result.title + ", " + result.subtitle
                                locationQuery = location
                                completerCoordinator.results = []

                                // Fetch coordinates
                                let request = MKLocalSearch.Request(completion: result)
                                let search = MKLocalSearch(request: request)
                                search.start { response, error in
                                    if let coordinate = response?.mapItems.first?.placemark.coordinate {
                                        selectedCoordinate = coordinate
                                    } else {
                                        errorMessage = "Could not get coordinates for location."
                                    }
                                }
                            }) {
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
                    Button(action: createActivity) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create Activity")
                        }
                    }
                    .disabled(
                        title.isEmpty ||
                        description.isEmpty ||
                        location.isEmpty ||
                        selectedCoordinate == nil
                    )
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
        guard let coordinate = selectedCoordinate else {
            errorMessage = "Location coordinates missing."
            return
        }

        isCreating = true
        errorMessage = nil

        let db = Firestore.firestore()

        // 1️⃣ Configure formatter to output fractional seconds in UTC
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // 2️⃣ Format your chosen dateTime, not `Date()`
        let dateTimeString = isoFormatter.string(from: dateTime)
        let createdAtString = isoFormatter.string(from: Date())

        let createdBy: [String: Any] = [
            "userId": user.uid,
            "displayName": user.displayName ?? user.email ?? "Unknown"
        ]

        let activityData: [String: Any] = [
            "title": title,
            "title_lowercase": title.lowercased(),
            "description": description,
            "location": location,
            "category": category,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "dateTime": dateTimeString,      // ← use dateTimeString here
            "isPublic": isPublic,
            "maxParticipants": maxParticipants,
            "participantIds": [user.uid],
            "createdBy": createdBy,
            "createdAt": createdAtString   // ← optional consistency
        ]

        db.collection("activities")
          .addDocument(data: activityData) { error in
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

// MARK: - Completer Coordinator (ObservableObject wrapper for MKLocalSearchCompleter)
class CompleterCoordinator: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    static let shared = CompleterCoordinator()
    @Published var results: [MKLocalSearchCompletion] = []
    let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

