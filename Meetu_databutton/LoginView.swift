import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingRegister = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
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

                Button("Sign In") {
                    auth.signIn(email: email, password: password)
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty)

                if let err = auth.authError {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button("Create an account") {
                    isShowingRegister = true
                }
                .sheet(isPresented: $isShowingRegister) {
                    RegisterView()
                        .environmentObject(auth)
                }
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}
