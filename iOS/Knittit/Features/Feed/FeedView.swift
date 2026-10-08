import SwiftUI
import Combine

struct RemoteFeedItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let yarn_brand: String?
    let thumbnail_url: String?
    let user_id: UUID
    let profiles: UserProfile?
    let project_versions: [ProjectVersionRemote]
    
    struct UserProfile: Codable {
        let username: String
        let avatar_url: String?
    }
    
    struct ProjectVersionRemote: Codable {
        let usdz_file_path: String?
        let thumbnail_url: String?
    }
}

class FeedManager: ObservableObject {
    @Published var items: [RemoteFeedItem] = []
    @Published var isLoading = false
    
    @MainActor
    func fetchFeed() async {
        isLoading = true
        defer { isLoading = false }
        
        let supabaseURL = "https://nidglxalnqgqibssjmol.supabase.co"
        let supabaseAnonKey = "sb_publishable_WHauEzUFRqivBDGCFH42Qw_q-fvSwrB"
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/projects?select=*,profiles(username,avatar_url),project_versions(usdz_file_path,thumbnail_url)&order=created_at.desc") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        if let token = UserDefaults.standard.string(forKey: "supabaseAccessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Failed to fetch feed: HTTP \(httpResponse.statusCode)")
                return
            }
            let decoded = try JSONDecoder().decode([RemoteFeedItem].self, from: data)
            self.items = decoded
        } catch {
            print("Failed to fetch feed: \(error)")
        }
    }
    
    func tryCreateProject(from item: RemoteFeedItem) -> KnitProject {
        let p = KnitProject(title: item.title, yarnBrand: item.yarn_brand ?? "", toolSize: "")
        
        if let thumb = item.thumbnail_url {
            p.thumbnailFilePath = thumb
        }
        
        if let firstVersion = item.project_versions.first, let path = firstVersion.usdz_file_path, !path.isEmpty {
            var finalPath = path
            if !path.hasPrefix("http") && !path.hasPrefix("/") {
                finalPath = "https://nidglxalnqgqibssjmol.supabase.co/storage/v1/object/public/scans/\(path)"
            }
            
            var thumbnailPath = item.thumbnail_url
            if let vThumb = firstVersion.thumbnail_url {
                 thumbnailPath = vThumb
            }
            
            let version = ProjectVersion(scanDate: Date(), progressPercentage: 100, usdzFilePath: finalPath, thumbnailFilePath: thumbnailPath)
            p.versions.append(version)
        } else {
            let fallbackMock = Bundle.main.url(forResource: "boxing_glove_realistic", withExtension: "usdz")?.path ?? ""
            let version = ProjectVersion(scanDate: Date(), progressPercentage: 100, usdzFilePath: fallbackMock, thumbnailFilePath: item.thumbnail_url)
            p.versions.append(version)
        }
        
        return p
    }
}

struct FeedView: View {
    @StateObject private var feedManager = FeedManager()
    
    var body: some View {
        NavigationStack {
            Group {
                if feedManager.isLoading && feedManager.items.isEmpty {
                    ProgressView()
                } else if feedManager.items.isEmpty {
                    Text("No posts found. Follow some users or check back later.")
                        .foregroundColor(.secondary)
                } else {
                    List(feedManager.items) { item in
                        ZStack {
                            FeedCardView(item: item)
                            NavigationLink(destination: ProjectDetailView(project: feedManager.tryCreateProject(from: item), belongsToUser: false)) {
                                EmptyView()
                            }
                            .opacity(0)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 8)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await feedManager.fetchFeed()
                    }
                }
            }
            .navigationTitle("Feed")
            .task {
                if feedManager.items.isEmpty {
                    await feedManager.fetchFeed()
                }
            }
        }
    }
}

struct FeedCardView: View {
    let item: RemoteFeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Group {
                            if let avatarUrl = item.profiles?.avatar_url, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill().clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.fill").foregroundColor(.white)
                                    }
                                }
                            } else {
                                Image(systemName: "person.fill").foregroundColor(.white)
                            }
                        }
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.profiles?.username ?? "Unknown User")
                        .font(.headline)
                    Text("Just now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Content
            ZStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .aspectRatio(4/3, contentMode: .fit)
                
                if let thumb = item.thumbnail_url, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                    .clipped()
                } else {
                    Image(systemName: "cube.transparent")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.secondary)
                }
            }
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Footer
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                if let brand = item.yarn_brand, !brand.isEmpty {
                    Text("Yarn: \(brand)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
