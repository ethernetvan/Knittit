//
//  ProfileManager.swift
//  Knittit
//

import Foundation
import Combine

struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    let username: String
    let bio: String?
    let avatar_url: String?
    let created_at: String?
}

struct RemoteProjectResponse: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    let title: String
    let yarn_brand: String?
    let tool_size: String?
    let pattern_source: String?
    let color_palette: [String]?
    let thumbnail_url: String?
    let created_at: String?
    let profiles: ProfileInfo?
    let project_versions: [VersionInfo]?
    
    struct ProfileInfo: Codable {
        let username: String
        let avatar_url: String?
    }
    
    struct VersionInfo: Codable {
        let id: UUID?
        let progress_percentage: Int?
        let usdz_file_path: String?
    }
}

@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    let supabaseURL = "https://nidglxalnqgqibssjmol.supabase.co"
    let supabaseAnonKey = "sb_publishable_WHauEzUFRqivBDGCFH42Qw_q-fvSwrB"
    
    private init() {}
    
    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        if let token = UserDefaults.standard.string(forKey: "supabaseAccessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T? {
        var mutableRequest = request
        do {
            let (data, response) = try await URLSession.shared.data(for: mutableRequest)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                let refreshed = await SupabaseAuthManager.shared.refreshToken()
                if refreshed, let token = UserDefaults.standard.string(forKey: "supabaseAccessToken") {
                    mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    let (retryData, retryResponse) = try await URLSession.shared.data(for: mutableRequest)
                    if let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 {
                        return try JSONDecoder().decode(T.self, from: retryData)
                    } else if let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 401 || retryHttp.statusCode == 403 {
                        SupabaseAuthManager.shared.signOut()
                        return nil
                    }
                } else {
                    SupabaseAuthManager.shared.signOut()
                    return nil
                }
            } else if httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(T.self, from: data)
            }
        } catch {
            print("Request failed: \(error)")
        }
        return nil
    }
    
    /// Fetches a profile by user ID.
    func fetchProfile(userId: UUID) async -> UserProfile? {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/profiles?id=eq.\(userId.uuidString.lowercased())&select=*") else {
            return nil
        }
        let request = makeRequest(url: url)
        do {
            let profiles: [UserProfile]? = try await performRequest(request)
            return profiles?.first
        } catch {
            return nil
        }
    }
    
    /// Searches profiles matching the query string, or returns recent profiles if query is empty.
    func searchProfiles(query: String) async -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint: String
        if trimmed.isEmpty {
            endpoint = "\(supabaseURL)/rest/v1/profiles?select=*&order=created_at.desc&limit=30"
        } else {
            guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return []
            }
            endpoint = "\(supabaseURL)/rest/v1/profiles?username=ilike.*\(encoded)*&select=*&order=created_at.desc&limit=30"
        }
        
        guard let url = URL(string: endpoint) else { return [] }
        let request = makeRequest(url: url)
        
        do {
            let profiles: [UserProfile]? = try await performRequest(request)
            return profiles ?? []
        } catch {
            return []
        }
    }
    
    /// Fetches all remote projects belonging to a user ID.
    func fetchUserProjects(userId: UUID) async -> [KnitProject] {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/projects?user_id=eq.\(userId.uuidString.lowercased())&select=*,profiles(username,avatar_url),project_versions(id,progress_percentage,usdz_file_path)&order=created_at.desc") else {
            return []
        }
        
        let request = makeRequest(url: url)
        do {
            let remoteProjects: [RemoteProjectResponse]? = try await performRequest(request)
            return remoteProjects?.map { makeKnitProject(from: $0) } ?? []
        } catch {
            return []
        }
    }
    
    private func makeKnitProject(from item: RemoteProjectResponse) -> KnitProject {
        let project = KnitProject(
            title: item.title,
            yarnBrand: item.yarn_brand ?? "",
            toolSize: item.tool_size ?? "",
            colorPalette: item.color_palette ?? [],
            thumbnailFilePath: item.thumbnail_url
        )
        
        if let versions = item.project_versions, !versions.isEmpty {
            for v in versions {
                guard let path = v.usdz_file_path, !path.isEmpty else { continue }
                var finalPath = path
                if !path.hasPrefix("http") && !path.hasPrefix("/") {
                    finalPath = "\(supabaseURL)/storage/v1/object/public/scans/\(path)"
                }
                
                let version = ProjectVersion(scanDate: Date(), progressPercentage: v.progress_percentage ?? 100, usdzFilePath: finalPath)
                project.versions.append(version)
            }
        }
        
        if project.versions.isEmpty {
            let fallbackMock = Bundle.main.url(forResource: "boxing_glove_realistic", withExtension: "usdz")?.path ?? ""
            let version = ProjectVersion(scanDate: Date(), progressPercentage: 100, usdzFilePath: fallbackMock)
            project.versions.append(version)
        }
        
        return project
    }
}
