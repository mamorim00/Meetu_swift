//
//  RegisterView.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 21.5.2025.
//


import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.presentationMode) var presentation
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Full Name", text: $displayName)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                Button("Register") {
                    auth.register(email: email, password: password, displayName: displayName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(displayName.isEmpty || email.isEmpty || password.isEmpty)

                if let err = auth.authError {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentation.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
