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
    let userId: UUID
    let createdAt: Date?
    let title: String
    let yarnBrand: String?
    let toolSize: String?
    let patternSource: String?
    let colorPalette: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case title
        case yarnBrand = "yarn_brand"
        case toolSize = "tool_size"
        case patternSource = "pattern_source"
        case colorPalette = "color_palette"
    }
}

struct SupabaseProjectVersion: Codable, Identifiable {
    let id: UUID
    let projectId: UUID
    let createdAt: Date?
    let usdzFilePath: String?
    let progressPercentage: Int?
    // Let's omit spatial_notes for now if they aren't using them, or define a basic struct

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case createdAt = "created_at"
        case usdzFilePath = "usdz_file_path"
        case progressPercentage = "progress_percentage"
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
