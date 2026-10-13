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
    
    func refreshToken() async -> Bool {
        guard let refreshToken = UserDefaults.standard.string(forKey: "supabaseRefreshToken") else { return false }
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["refresh_token": refreshToken]
        guard let httpBody = try? JSONEncoder().encode(body) else { return false }
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accToken = json["access_token"] as? String,
                   let refToken = json["refresh_token"] as? String {
                    UserDefaults.standard.set(accToken, forKey: "supabaseAccessToken")
                    UserDefaults.standard.set(refToken, forKey: "supabaseRefreshToken")
                    return true
                }
            } else {
                // If it fails, sign out
                signOut()
            }
        } catch {}
        return false
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
                   let errorDescription = (json["error_description"] as? String) ?? (json["msg"] as? String) ?? (json["message"] as? String) {
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
    
    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/signup") else {
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
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let accessToken = json["access_token"] as? String,
                       let refreshToken = json["refresh_token"] as? String {
                        UserDefaults.standard.set(accessToken, forKey: "supabaseAccessToken")
                        UserDefaults.standard.set(refreshToken, forKey: "supabaseRefreshToken")
                    }
                    if let userObj = (json["user"] as? [String: Any]) ?? (json as? [String: Any]) {
                        if let userId = userObj["id"] as? String {
                            UserDefaults.standard.set(userId, forKey: "currentUserId")
                        }
                        if let userEmail = userObj["email"] as? String {
                            UserDefaults.standard.set(userEmail, forKey: "currentUserEmail")
                        }
                    }
                    return true
                } else {
                    errorMessage = "Failed to parse authentication response."
                    return false
                }
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDescription = (json["error_description"] as? String) ?? (json["msg"] as? String) ?? (json["message"] as? String) {
                    errorMessage = errorDescription
                } else {
                    errorMessage = "Sign up failed with status code \(httpResponse.statusCode)."
                }
                return false
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            return false
        }
    }
}

private extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: 1.0
        )
    }
}

struct SupabaseLoginView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var authManager = SupabaseAuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isSignUp = false
    @AppStorage("rememberMe") private var rememberMe = true
    @AppStorage("savedEmail") private var savedEmail = ""
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Background gradient colors: #dad299 → #b0dab9
    private let gradientStart = Color(hexString: "dad299")
    private let gradientEnd = Color(hexString: "b0dab9")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full screen gradient background
                LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer(minLength: 32)
                        
                        // Center White Card
                        VStack(spacing: 20) {
                            // Top Logo: Yarn Emoji by itself
                            Text("🧶")
                                .font(.system(size: 52))
                                .padding(.top, 8)
                            
                            // Header Text
                            VStack(spacing: 6) {
                                Text("Knittit")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(red: 0.12, green: 0.14, blue: 0.2))
                                
                                Text(isSignUp ? "Enter your email and password to sign up" : "Enter your email and password to log in")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.45, green: 0.48, blue: 0.54))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                            }
                            
                            if let errorMessage = authManager.errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                            
                            // Text Fields
                            VStack(spacing: 14) {
                                // Email Field
                                HStack {
                                    ZStack(alignment: .leading) {
                                        if email.isEmpty {
                                            Text("Email")
                                                .font(.system(size: 15))
                                                .foregroundColor(Color(red: 0.32, green: 0.35, blue: 0.42))
                                                .allowsHitTesting(false)
                                        }
                                        TextField("", text: $email)
                                            .keyboardType(.emailAddress)
                                            .textContentType(.emailAddress)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .font(.system(size: 15))
                                            .foregroundColor(Color(red: 0.12, green: 0.14, blue: 0.2))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.97, green: 0.98, blue: 0.99))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
                                )
                                
                                // Password Field with Eye Toggle
                                HStack {
                                    ZStack(alignment: .leading) {
                                        if password.isEmpty {
                                            Text("Password")
                                                .font(.system(size: 15))
                                                .foregroundColor(Color(red: 0.32, green: 0.35, blue: 0.42))
                                                .allowsHitTesting(false)
                                        }
                                        if isPasswordVisible {
                                            TextField("", text: $password)
                                                .textContentType(isSignUp ? .newPassword : .password)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                                .font(.system(size: 15))
                                                .foregroundColor(Color(red: 0.12, green: 0.14, blue: 0.2))
                                        } else {
                                            SecureField("", text: $password)
                                                .textContentType(isSignUp ? .newPassword : .password)
                                                .font(.system(size: 15))
                                                .foregroundColor(Color(red: 0.12, green: 0.14, blue: 0.2))
                                        }
                                    }
                                    
                                    Button(action: {
                                        isPasswordVisible.toggle()
                                    }) {
                                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(red: 0.45, green: 0.48, blue: 0.54))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.97, green: 0.98, blue: 0.99))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
                                )
                            }
                            
                            // Remember Me & Forgot Password Row
                            HStack {
                                Button(action: {
                                    rememberMe.toggle()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 16))
                                            .foregroundColor(rememberMe ? Color.accentColor : Color(red: 0.75, green: 0.78, blue: 0.82))
                                        
                                        Text("Remember me")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(red: 0.45, green: 0.48, blue: 0.54))
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Button(action: {
                                    alertTitle = "Forgot Password"
                                    alertMessage = "Coming Soon"
                                    showAlert = true
                                }) {
                                    Text("Forgot Password ?")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.accentColor)
                                }
                            }
                            .padding(.top, -2)
                            
                            // Primary Action Button (Comforting Brown Accent Color)
                            Button(action: authenticate) {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text(isSignUp ? "Sign Up" : "Log In")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                            }
                            .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                            .opacity((email.isEmpty || password.isEmpty || authManager.isLoading) ? 0.65 : 1.0)
                            
                            // "Or login with" Divider
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(Color(red: 0.88, green: 0.90, blue: 0.94))
                                    .frame(height: 1)
                                
                                Text("Or login with")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 0.45, green: 0.48, blue: 0.54))
                                
                                Rectangle()
                                    .fill(Color(red: 0.88, green: 0.90, blue: 0.94))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 4)
                            
                            // Third-Party Login Options (Google and Apple - Greyed out)
                            HStack(spacing: 16) {
                                // Google (Greyed out)
                                Button(action: {
                                    alertTitle = "Sign in with Google"
                                    alertMessage = "Coming Soon"
                                    showAlert = true
                                }) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.97, green: 0.98, blue: 0.99))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
                                        )
                                        .overlay(
                                            Text("G")
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundColor(Color(red: 0.55, green: 0.58, blue: 0.64))
                                        )
                                        .frame(width: 68, height: 48)
                                        .opacity(0.55)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Sign in with Google")
                                
                                // Apple (Greyed out)
                                Button(action: {
                                    alertTitle = "Sign in with Apple"
                                    alertMessage = "Coming Soon"
                                    showAlert = true
                                }) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.97, green: 0.98, blue: 0.99))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
                                        )
                                        .overlay(
                                            Image(systemName: "apple.logo")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color(red: 0.55, green: 0.58, blue: 0.64))
                                        )
                                        .frame(width: 68, height: 48)
                                        .opacity(0.55)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Sign in with Apple")
                            }
                            
                            // Toggle between Sign In and Sign Up
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don’t have an account?")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 0.45, green: 0.48, blue: 0.54))
                                
                                Button(action: {
                                    withAnimation {
                                        isSignUp.toggle()
                                        authManager.errorMessage = nil
                                    }
                                }) {
                                    Text(isSignUp ? "Log In" : "Sign Up")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.accentColor)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 10)
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 32)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .tint(Color.accentColor)
        .onAppear {
            if rememberMe && !savedEmail.isEmpty {
                email = savedEmail
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func authenticate() {
        Task {
            let success: Bool
            if isSignUp {
                success = await authManager.signUp(email: email, password: password)
            } else {
                success = await authManager.signIn(email: email, password: password)
            }
            if success {
                if rememberMe {
                    savedEmail = email
                } else {
                    savedEmail = ""
                }
                withAnimation {
                    self.isLoggedIn = true
                }
            }
        }
    }
}

#Preview {
    SupabaseLoginView(isLoggedIn: .constant(false))
}
