import Foundation
import SwiftData

@Model
final class ProjectVersion {
    var id: UUID = UUID()
    var scanDate: Date
    var progressPercentage: Int
    var usdzFilePath: String
    var spatialNotes: [SpatialNote]
    
    var project: KnitProject?
    
    init(scanDate: Date, progressPercentage: Int, usdzFilePath: String, spatialNotes: [SpatialNote] = []) {
        self.scanDate = scanDate
        self.progressPercentage = progressPercentage
        self.usdzFilePath = usdzFilePath
        self.spatialNotes = spatialNotes
    }
}