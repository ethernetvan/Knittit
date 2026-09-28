import Foundation
import Supabase

struct Profile: Codable, Identifiable {
    let id: UUID
    let createdAt: Date?
    let username: String
    let bio: String?
    let avatarUrl: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case username
        case bio
        case avatarUrl = "avatar_url"
    }
}

struct SupabaseProject: Codable, Identifiable {
    let id: UUID
    let ownerId: UUID
    let createdAt: Date?
    let title: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case createdAt = "created_at"
        case title
        case description
    }
}

struct SupabaseProjectVersion: Codable, Identifiable {
    let id: UUID
    let projectId: UUID
    let createdAt: Date?
    let usdzUrl: URL?
    let versionNotes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case createdAt = "created_at"
        case usdzUrl = "usdz_url"
        case versionNotes = "version_notes"
    }
}

struct Follow: Codable, Identifiable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
}
