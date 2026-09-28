import SwiftUI
import Supabase

struct ProfileView: View {
    @State var profile: Profile?
    let isCurrentUser: Bool
    
    @State private var userProjects: [SupabaseProject] = []
    @State private var isFollowing = false
    @State private var isLoading = true
    
    @State private var searchQuery = ""
    @State private var searchResults: [Profile] = []
    @State private var isSearching = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationView {
            VStack {
                if isSearching {
                    List(searchResults) { result in
                        NavigationLink(destination: ProfileView(profile: result, isCurrentUser: false)) {
                            Text(result.username)
                        }
                    }
                    .searchable(text: $searchQuery, prompt: "Search users...")
                    .onChange(of: searchQuery) { _, newValue in
                        Task { await performSearch(query: newValue) }
                    }
                } else {
                    ScrollView {
                        if let profile = profile {
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(String(profile.username.prefix(1)).uppercased())
                                            .font(.largeTitle)
                                    )
                                
                                Text(profile.username)
                                    .font(.title)
                                    .bold()
                                
                                if let bio = profile.bio {
                                    Text(bio)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !isCurrentUser {
                                    Button(action: {
                                        Task { await toggleFollow() }
                                    }) {
                                        Text(isFollowing ? "Unfollow" : "Follow")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(isFollowing ? Color.gray : Color.blue)
                                            .cornerRadius(10)
                                    }
                                    .padding(.horizontal)
                                }
                                
                                Divider()
                                
                                Text("Projects")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                
                                if isLoading {
                                    ProgressView()
                                } else {
                                    LazyVGrid(columns: columns, spacing: 16) {
                                        ForEach(userProjects) { project in
                                            VStack {
                                                Rectangle()
                                                    .fill(Color.secondary.opacity(0.2))
                                                    .aspectRatio(1, contentMode: .fit)
                                                    .cornerRadius(8)
                                                
                                                Text(project.title)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        } else {
                            ProgressView("Loading Profile...")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isSearching.toggle() }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .task {
                if !isSearching {
                    await loadProfileData()
                }
            }
        }
    }
    
    private func loadProfileData() async {
        isLoading = true
        do {
            if profile == nil && isCurrentUser {
                if let user = try? await SupabaseManager.shared.client.auth.session.user {
                    let fetchedProfile: Profile = try await SupabaseManager.shared.client
                        .from("profiles")
                        .select()
                        .eq("id", value: user.id)
                        .single()
                        .execute()
                        .value
                    
                    await MainActor.run {
                        self.profile = fetchedProfile
                    }
                }
            }
            
            if let targetProfile = profile {
                let projects: [SupabaseProject] = try await SupabaseManager.shared.client
                    .from("projects")
                    .select()
                    .eq("owner_id", value: targetProfile.id)
                    .execute()
                    .value
                
                await MainActor.run {
                    self.userProjects = projects
                }
                
                if !isCurrentUser, let me = try? await SupabaseManager.shared.client.auth.session.user {
                    let followResult: [Follow] = try await SupabaseManager.shared.client
                        .from("follows")
                        .select()
                        .eq("follower_id", value: me.id)
                        .eq("following_id", value: targetProfile.id)
                        .execute()
                        .value
                    
                    await MainActor.run {
                        self.isFollowing = !followResult.isEmpty
                    }
                }
            }
            
            await MainActor.run { isLoading = false }
        } catch {
            print("Error loading profile: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    private func toggleFollow() async {
        guard let myUser = try? await SupabaseManager.shared.client.auth.session.user,
              let targetProfile = profile else { return }
        
        do {
            if isFollowing {
                try await SupabaseManager.shared.client
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: myUser.id)
                    .eq("following_id", value: targetProfile.id)
                    .execute()
                
                await MainActor.run { self.isFollowing = false }
            } else {
                let follow = Follow(id: UUID(), followerId: myUser.id, followingId: targetProfile.id, createdAt: Date())
                try await SupabaseManager.shared.client
                    .from("follows")
                    .insert(follow)
                    .execute()
                
                await MainActor.run { self.isFollowing = true }
            }
        } catch {
            print("Error toggling follow: \(error)")
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run { self.searchResults = [] }
            return
        }
        
        do {
            let results: [Profile] = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .ilike("username", value: "%\(query)%")
                .execute()
                .value
            
            await MainActor.run {
                self.searchResults = results
            }
        } catch {
            print("Search failed: \(error)")
        }
    }
}
