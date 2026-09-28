import SwiftUI
import RealityKit
import Supabase

struct SocialFeedView: View {
    @State private var feedItems: [FeedSupabaseProjectVersion] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    if isLoading {
                        ProgressView("Loading Feed...")
                    } else if feedItems.isEmpty {
                        Text("No projects in your feed yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(feedItems) { item in
                            FeedItemView(item: item)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await reportItem(item) }
                                    } label: {
                                        Label("Report Post", systemImage: "exclamationmark.bubble")
                                    }
                                }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Knittit Feed")
            .task {
                await loadFeed()
            }
            .refreshable {
                await loadFeed()
            }
        }
    }
    
    private func loadFeed() async {
        isLoading = true
        do {
            let items: [FeedSupabaseProjectVersion] = try await SupabaseManager.shared.client
                .from("project_versions")
                .select("*, projects(*)")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.feedItems = items
                self.isLoading = false
            }
        } catch {
            print("Failed to load feed: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func reportItem(_ item: FeedSupabaseProjectVersion) async {
        do {
            guard let user = try? await SupabaseManager.shared.client.auth.session.user else { return }
            
            let targetId = item.id
            let report = Report(
                id: UUID(),
                reporterId: user.id,
                targetId: targetId,
                createdAt: Date()
            )
            
            try await SupabaseManager.shared.client
                .from("reports")
                .insert(report)
                .execute()
            
        } catch {
            print("Failed to report item: \(error)")
        }
    }
}

struct Report: Codable {
    let id: UUID
    let reporterId: UUID
    let targetId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case targetId = "target_id"
        case createdAt = "created_at"
    }
}

struct FeedSupabaseProjectVersion: Codable, Identifiable {
    let id: UUID
    let projectId: UUID
    let createdAt: Date?
    let usdzUrl: URL?
    let versionNotes: String?
    let projects: SupabaseProject?
    
    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case createdAt = "created_at"
        case usdzUrl = "usdz_url"
        case versionNotes = "version_notes"
        case projects
    }
}

struct FeedItemView: View {
    let item: FeedSupabaseProjectVersion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.projects?.title ?? "Unknown SupabaseProject")
                    .font(.headline)
                Spacer()
                if let date = item.createdAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let url = item.usdzUrl {
                VStack {
                    Image(systemName: "arkit")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)
                        .foregroundColor(.blue)
                    Text("Tap to View 3D Model")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(height: 300)
                    .cornerRadius(12)
                    .overlay(Text("No 3D Model Available").foregroundColor(.secondary))
            }
            
            if let notes = item.versionNotes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
