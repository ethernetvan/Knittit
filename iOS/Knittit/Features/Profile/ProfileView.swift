//
//  ProfileView.swift
//  Knittit
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    var targetUserId: UUID? = nil
    var isCurrentUser: Bool = true
    var isTabRoot: Bool = false
    
    @Query private var localProjects: [KnitProject]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var profile: UserProfile?
    @State private var remoteProjects: [KnitProject] = []
    @State private var isLoading: Bool = false
    @State private var showSearch: Bool = false
    @State private var showSignOutConfirmation: Bool = false
    
    private var resolvedUserId: UUID? {
        if let target = targetUserId {
            return target
        }
        if let currentIdString = SupabaseAuthManager.currentUserId(),
           let uuid = UUID(uuidString: currentIdString) {
            return uuid
        }
        return nil
    }
    
    private var displayName: String {
        if let profile = profile, !profile.username.isEmpty {
            return profile.username
        }
        if let id = resolvedUserId {
            let short = id.uuidString.prefix(4).uppercased()
            return "User \(short)"
        }
        return "User AD44"
    }
    
    private var avatarInitial: String {
        let initial = displayName.prefix(1).uppercased()
        return initial.isEmpty ? "U" : initial
    }
    
    /// Aggregates local and remote projects for current user, or remote-only for others.
    private var displayedProjects: [KnitProject] {
        if isCurrentUser {
            // Include local projects
            var combined: [KnitProject] = localProjects
            let localTitles = Set(localProjects.map { $0.title.lowercased() })
            // Append remote projects that don't already exist locally by title
            for remote in remoteProjects {
                if !localTitles.contains(remote.title.lowercased()) {
                    combined.append(remote)
                }
            }
            return combined
        } else {
            // Strictly remote projects only when viewing another profile
            return remoteProjects
        }
    }
    
    var body: some View {
        if isTabRoot {
            NavigationStack {
                contentView
            }
        } else {
            contentView
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top Header with Title and Floating Action Buttons
                HStack(alignment: .center) {
                    Text("Profile")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // User Search floating button
                        Button(action: {
                            showSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color(uiColor: .systemBackground))
                                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                                )
                        }
                        
                        // Settings / Cog floating button (shown on own profile)
                        if isCurrentUser {
                            Button(action: {
                                showSignOutConfirmation = true
                            }) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(Color(uiColor: .systemBackground))
                                            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Profile Avatar & Username
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: .systemGray4))
                            .frame(width: 104, height: 104)
                        
                        if let avatarUrlString = profile?.avatar_url,
                           let url = URL(string: avatarUrlString) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 104, height: 104)
                                        .clipShape(Circle())
                                } else {
                                    Text(avatarInitial)
                                        .font(.system(size: 42, weight: .regular))
                                        .foregroundColor(.primary)
                                }
                            }
                        } else {
                            Text(avatarInitial)
                                .font(.system(size: 42, weight: .regular))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Text(displayName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 24)
                
                // Divider line across the screen
                Divider()
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                
                // Projects Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Projects")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    if displayedProjects.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text(isCurrentUser ? "No projects yet. Tap Scan to create your first knit!" : "No projects to display.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(displayedProjects) { project in
                                NavigationLink(destination: ProjectDetailView(project: project, belongsToUser: isCurrentUser)) {
                                    ProjectThumbnail(project: project)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if isCurrentUser && isLocal(project: project) {
                                        Button(role: .destructive) {
                                            modelContext.delete(project)
                                        } label: {
                                            Label("Delete Project", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Bottom spacing for custom floating tab bar
                Spacer(minLength: 100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showSearch) {
            UserSearchView()
        }
        .confirmationDialog(
            "Account Settings",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                SupabaseAuthManager.shared.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func isLocal(project: KnitProject) -> Bool {
        localProjects.contains(where: { $0.id == project.id })
    }
    
    private func loadData() async {
        guard let userId = resolvedUserId else { return }
        isLoading = true
        defer { isLoading = false }
        
        async let fetchedProfile = ProfileManager.shared.fetchProfile(userId: userId)
        async let fetchedProjects = ProfileManager.shared.fetchUserProjects(userId: userId)
        
        let (prof, proj) = await (fetchedProfile, fetchedProjects)
        self.profile = prof
        self.remoteProjects = proj
    }
}
