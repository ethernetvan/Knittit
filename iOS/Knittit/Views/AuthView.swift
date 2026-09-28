import SwiftUI
import Supabase

struct AuthView: View {
    @Binding var isAuthenticated: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isSignUp = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Knittit")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 15) {
                if isSignUp {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                    .textInputAutocapitalization(.never)
                        #endif
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView()
            } else {
                Button(action: {
                    Task {
                        if isSignUp {
                            await signUp()
                        } else {
                            await signIn()
                        }
                    }
                }) {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    isSignUp.toggle()
                    errorMessage = nil
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            let _ = try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
            await MainActor.run {
                self.isAuthenticated = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
            let user = response.user
            let finalUsername = username.isEmpty ? "User \(_targetPrefix(user.id.uuidString))" : username
            
            let profile = Profile(
                id: user.id,
                createdAt: Date(),
                username: finalUsername,
                bio: "",
                avatarUrl: nil
            )
            
            try await SupabaseManager.shared.client.from("profiles").upsert(profile).execute()
            
            await MainActor.run {
                self.isAuthenticated = true
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func _targetPrefix(_ str: String) -> String {
        return String(str.prefix(4))
    }
}
