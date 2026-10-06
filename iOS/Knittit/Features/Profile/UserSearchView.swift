//
//  UserSearchView.swift
//  Knittit
//

import SwiftUI

struct UserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var users: [UserProfile] = []
    @State private var isLoading: Bool = false
    
    private var currentUserId: String? {
        SupabaseAuthManager.currentUserId()
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && users.isEmpty {
                    ProgressView("Searching users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No users found" : "No users matching \"\(searchText)\"")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(users) { user in
                        NavigationLink(destination: ProfileView(
                            targetUserId: user.id,
                            isCurrentUser: user.id.uuidString.lowercased() == currentUserId?.lowercased()
                        )) {
                            HStack(spacing: 14) {
                                // Avatar circle
                                ZStack {
                                    Circle()
                                        .fill(Color(uiColor: .systemGray5))
                                        .frame(width: 44, height: 44)
                                    
                                    if let avatarUrlString = user.avatar_url,
                                       let url = URL(string: avatarUrlString) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .clipShape(Circle())
                                            } else {
                                                avatarInitialView(user.username)
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                    } else {
                                        avatarInitialView(user.username)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.username)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let bio = user.bio, !bio.isEmpty {
                                        Text(bio)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Find Users")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by username")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await performSearch(query: searchText)
            }
        }
    }
    
    private func avatarInitialView(_ username: String) -> some View {
        let initial = username.prefix(1).uppercased()
        return Text(initial.isEmpty ? "U" : initial)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.primary)
    }
    
    private func performSearch(query: String) async {
        isLoading = true
        defer { isLoading = false }
        users = await ProfileManager.shared.searchProfiles(query: query)
    }
}
