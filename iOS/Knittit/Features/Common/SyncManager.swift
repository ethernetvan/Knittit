import Foundation
import SwiftData
import Network
import Combine
import os

@MainActor
enum SyncResult {
    case success
    case unauthorized // Indicates we should grab a new token and retry
    case failed
}

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    @Published var isOnline: Bool = true
    
    let supabaseURL = SupabaseAuthManager.shared.supabaseURL
    let apikey = SupabaseAuthManager.shared.supabaseAnonKey
    
    private let logger = Logger(subsystem: "com.knittit", category: "SyncManager")
    
    private var isSyncing = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    self?.triggerSync()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    func triggerSync() {
        guard isOnline, !isSyncing else { return }
        logger.info("Triggering sync...")
        Task {
            await runSyncProcess()
        }
    }
    
    private func runSyncProcess() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        guard let userIdRaw = UserDefaults.standard.string(forKey: "currentUserId"),
              let userId = UUID(uuidString: userIdRaw) else {
            logger.warning("No authentication found, skipping sync.")
            return
        }
        
        let container = try? ModelContainer(for: SyncAction.self, KnitProject.self, ProjectVersion.self)
        guard let modelContext = container?.mainContext else { return }
        
        // Fetch all pending or errored actions
        let fetchDescriptor = FetchDescriptor<SyncAction>(
            predicate: #Predicate { $0.status == "pending" || $0.status == "error" },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        do {
            let actions = try modelContext.fetch(fetchDescriptor)
            for action in actions {
                logger.info("Processing action: \(action.type.rawValue) for \(action.entityId)")
                
                var token = UserDefaults.standard.string(forKey: "supabaseAccessToken") ?? ""
                
                var result = await executeAction(action, userId: userId, context: modelContext, token: token)
                
                if result == .unauthorized {
                    // Try to refresh token
                    logger.warning("Token expired, attempting refresh...")
                    let refreshed = await SupabaseAuthManager.shared.refreshToken()
                    if refreshed {
                        token = UserDefaults.standard.string(forKey: "supabaseAccessToken") ?? ""
                        result = await executeAction(action, userId: userId, context: modelContext, token: token)
                    } else {
                        logger.error("Token refresh failed. Aborting sync.")
                        SupabaseAuthManager.shared.signOut()
                        break // Break out and stop if we are unauthorized and cannot refresh
                    }
                }
                
                if result == .success {
                    action.status = "completed"
                    modelContext.delete(action)
                    try? modelContext.save()
                } else if result == .failed {
                    logger.error("Failed action: \(action.type.rawValue) for \(action.entityId)")
                    action.status = "error"
                    try? modelContext.save()
                    break // Stop processing to keep chronological order if a dependent upload fails
                }
            }
        } catch {
            logger.error("Error fetching actions: \(error.localizedDescription)")
        }
    }
    
    private func executeAction(_ action: SyncAction, userId: UUID, context: ModelContext, token: String) async -> SyncResult {
        switch action.type {
        case .uploadProject:
            return await handleUploadProject(action: action, userId: userId, context: context, token: token)
        case .uploadVersion:
            return await handleUploadVersion(action: action, userId: userId, context: context, token: token)
        case .updateNotes:
            return await handleUpdateNotes(action: action, context: context, token: token)
        }
    }
    
    // MARK: - Handlers
    
    private func handleUploadProject(action: SyncAction, userId: UUID, context: ModelContext, token: String) async -> SyncResult {
        let projectId = action.entityId
        let desc = FetchDescriptor<KnitProject>(predicate: #Predicate { $0.id == projectId })
        guard let project = try? context.fetch(desc).first else { return .success }

        var thumbnailUrl: String? = nil
        if let localThumb = project.thumbnailFilePath {
            let fileURL = AppFolder.documentDirectory.appendingPathComponent(localThumb)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let objectPath = "\(userId.uuidString)/\(project.id.uuidString)_thumbnail.jpg"
                let uploadResult = await uploadStorageData(fileURL: fileURL, bucket: "scans", objectPath: objectPath, contentType: "image/jpeg", token: token)
                if uploadResult == .success {
                    thumbnailUrl = "\(supabaseURL)/storage/v1/object/public/scans/\(objectPath)"
                } else if uploadResult == .unauthorized {
                    return .unauthorized
                }
            } else if localThumb.starts(with: "http") {
                thumbnailUrl = localThumb
            }
        }
        
        let payload: [String: Any] = [
            "id": project.id.uuidString,
            "user_id": userId.uuidString,
            "title": project.title,
            "yarn_brand": project.yarnBrand,
            "tool_size": project.toolSize,
            "color_palette": project.colorPalette,
            "thumbnail_url": thumbnailUrl ?? NSNull()
        ]
        
        return await upsertRow(table: "projects", payload: payload, token: token)
    }
    
    private func handleUploadVersion(action: SyncAction, userId: UUID, context: ModelContext, token: String) async -> SyncResult {
        let versionId = action.entityId
        let desc = FetchDescriptor<ProjectVersion>(predicate: #Predicate { $0.id == versionId })
        guard let version = try? context.fetch(desc).first, let project = version.project else { return .success }
        
        var usdzUrlPath: String? = nil
        let fileURL = AppFolder.documentDirectory.appendingPathComponent(version.usdzFilePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let objectPath = "\(userId.uuidString)/\(version.id.uuidString)_scan.usdz"
            let uploadResult = await uploadStorageData(fileURL: fileURL, bucket: "scans", objectPath: objectPath, contentType: "model/vnd.pixar.usd", token: token)
            if uploadResult == .success {
                usdzUrlPath = "\(supabaseURL)/storage/v1/object/public/scans/\(objectPath)"
            } else if uploadResult == .unauthorized {
                return .unauthorized
            }
        } else if version.usdzFilePath.starts(with: "http") {
             usdzUrlPath = version.usdzFilePath
        }
        
        let encodedNotes = (try? JSONEncoder().encode(version.spatialNotes)) ?? Data()
        let notesJson = (try? JSONSerialization.jsonObject(with: encodedNotes, options: [])) ?? []
        
        let payload: [String: Any] = [
            "id": version.id.uuidString,
            "project_id": project.id.uuidString,
            "progress_percentage": version.progressPercentage,
            "usdz_file_path": usdzUrlPath ?? NSNull(),
            "spatial_notes": notesJson
        ]
        
        return await upsertRow(table: "project_versions", payload: payload, token: token)
    }
    
    private func handleUpdateNotes(action: SyncAction, context: ModelContext, token: String) async -> SyncResult {
        let versionId = action.entityId
        let desc = FetchDescriptor<ProjectVersion>(predicate: #Predicate { $0.id == versionId })
        guard let version = try? context.fetch(desc).first else { return .success }
        
        let encodedNotes = (try? JSONEncoder().encode(version.spatialNotes)) ?? Data()
        let notesJson = (try? JSONSerialization.jsonObject(with: encodedNotes, options: [])) ?? []
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/project_versions?id=eq.\(version.id.uuidString)") else { return .failed }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = ["spatial_notes": notesJson]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return .failed }
        req.httpBody = body
        
        do {
            let (_, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse {
                if httpRes.statusCode == 401 || httpRes.statusCode == 403 {
                    return .unauthorized
                }
                return httpRes.statusCode < 300 ? .success : .failed
            }
            return .failed
        } catch {
            return .failed
        }
    }
    
    // MARK: - Networking Utilities
    
    private func upsertRow(table: String, payload: [String: Any], token: String) async -> SyncResult {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)") else { return .failed }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return .failed }
        req.httpBody = body
        
        do {
            let (data, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse, httpRes.statusCode >= 300 {
                if httpRes.statusCode == 401 || httpRes.statusCode == 403 {
                    return .unauthorized
                }
                let errString = String(data: data, encoding: .utf8) ?? ""
                logger.error("Upsert failed \(table): \(httpRes.statusCode) - \(errString)")
                return .failed
            }
            return .success
        } catch {
            return .failed
        }
    }
    
    private func uploadStorageData(fileURL: URL, bucket: String, objectPath: String, contentType: String, token: String) async -> SyncResult {
        guard let url = URL(string: "\(supabaseURL)/storage/v1/object/\(bucket)/\(objectPath)") else { return .failed }
        guard let data = try? Data(contentsOf: fileURL) else { return .failed }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST" 
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        
        do {
            let (dataRes, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse, httpRes.statusCode >= 300 {
                if httpRes.statusCode == 401 || httpRes.statusCode == 403 {
                    return .unauthorized
                }
                if httpRes.statusCode == 409 || httpRes.statusCode == 400 { // 400 might be object exists in some edge cases or just bad req. Actually 400 with "already exists" happens in Postgres storage? Usually 409. 
                    req.httpMethod = "PUT"
                    let (dataRes2, res2) = try await URLSession.shared.data(for: req)
                    if let httpRes2 = res2 as? HTTPURLResponse, httpRes2.statusCode >= 300 {
                         if httpRes2.statusCode == 401 || httpRes2.statusCode == 403 { return .unauthorized }
                         let errString = String(data: dataRes2, encoding: .utf8) ?? ""
                         logger.error("Storage PUT failed: \(httpRes2.statusCode) - \(errString)")
                         return .failed
                    }
                    return .success
                }
                
                let errString = String(data: dataRes, encoding: .utf8) ?? ""
                logger.error("Storage POST failed: \(httpRes.statusCode) - \(errString)")
                return .failed
            }
            return .success
        } catch {
            return .failed
        }
    }
}

class AppFolder {
    static var documentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}