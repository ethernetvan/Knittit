//
//  SupabaseLoginView.swift
//  Knittit
//

import SwiftUI
import Foundation
import Combine

/// A lightweight manager for Supabase Authentication using URLSession.
@MainActor
class SupabaseAuthManager: ObservableObject {
    static let shared = SupabaseAuthManager()
    
    // MARK: - SUPABASE CREDENTIALS
    let supabaseURL = "https://nidglxalnqgqibssjmol.supabase.co"
    let supabaseAnonKey = "sb_publishable_WHauEzUFRqivBDGCFH42Qw_q-fvSwrB"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    static func currentUserId() -> String? {
        if let stored = UserDefaults.standard.string(forKey: "currentUserId"), !stored.isEmpty {
            return stored
        }
        if let token = UserDefaults.standard.string(forKey: "supabaseAccessToken") {
            let parts = token.split(separator: ".")
            if parts.count > 1 {
                var base64 = String(parts[1])
                while base64.count % 4 != 0 {
                    base64.append("=")
                }
                if let data = Data(base64Encoded: base64),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let sub = json["sub"] as? String {
                    UserDefaults.standard.set(sub, forKey: "currentUserId")
                    return sub
                }
            }
        }
        return nil
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "supabaseAccessToken")
        UserDefaults.standard.removeObject(forKey: "supabaseRefreshToken")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "currentUserEmail")
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
    }
    
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password") else {
            errorMessage = "Invalid Supabase URL configured."
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server."
                return false
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String,
                   let refreshToken = json["refresh_token"] as? String {
                    UserDefaults.standard.set(accessToken, forKey: "supabaseAccessToken")
                    UserDefaults.standard.set(refreshToken, forKey: "supabaseRefreshToken")
                    
                    if let userObj = json["user"] as? [String: Any] {
                        if let userId = userObj["id"] as? String {
                            UserDefaults.standard.set(userId, forKey: "currentUserId")
                        }
                        if let userEmail = userObj["email"] as? String {
                            UserDefaults.standard.set(userEmail, forKey: "currentUserEmail")
                        }
                    }
                    return true
                } else {
                    errorMessage = "Failed to parse authentication tokens."
                    return false
                }
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDescription = json["error_description"] as? String {
                    errorMessage = errorDescription
                } else {
                    errorMessage = "Sign in failed with status code \(httpResponse.statusCode)."
                }
                return false
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            return false
        }
    }
}

struct SupabaseLoginView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var authManager = SupabaseAuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.24, green: 0.8, blue: 0.54)) // Supabase green
                        .padding(.bottom, 10)
                    
                    Text("Welcome to Knittit")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sign in to your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                Button(action: login) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.24, green: 0.8, blue: 0.54)) // Supabase green
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                
                Spacer()
                Spacer()
            }
            .padding()
        }
    }
    
    private func login() {
        Task {
            let success = await authManager.signIn(email: email, password: password)
            if success {
                withAnimation {
                    self.isLoggedIn = true
                }
            }
        }
    }
}
