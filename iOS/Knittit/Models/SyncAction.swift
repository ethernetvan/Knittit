import Foundation
import SwiftData

enum SyncActionType: String, Codable {
    case uploadProject
    case uploadVersion
    case updateNotes
}

@Model
final class SyncAction {
    var id: UUID = UUID()
    var actionTypeRaw: String = SyncActionType.uploadProject.rawValue
    var entityId: UUID = UUID()
    var createdAt: Date = Date()
    var status: String = "pending"
    
    var type: SyncActionType {
        get { SyncActionType(rawValue: actionTypeRaw) ?? .uploadProject }
        set { actionTypeRaw = newValue.rawValue }
    }
    
    init(type: SyncActionType, entityId: UUID) {
        self.id = UUID()
        self.actionTypeRaw = type.rawValue
        self.entityId = entityId
        self.createdAt = Date()
        self.status = "pending"
    }
}
