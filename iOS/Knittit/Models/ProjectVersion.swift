import Foundation
import SwiftData

@Model
final class ProjectVersion {
    var id: UUID = UUID()
    var scanDate: Date
    var progressPercentage: Int
    var usdzFilePath: String
    var thumbnailFilePath: String? // Local/Remote path to the thumbnail image
    var spatialNotes: [SpatialNote]
    
    var project: KnitProject?
    
    init(scanDate: Date, progressPercentage: Int, usdzFilePath: String, spatialNotes: [SpatialNote] = [], thumbnailFilePath: String? = nil) {
        self.scanDate = scanDate
        self.progressPercentage = progressPercentage
        self.usdzFilePath = usdzFilePath
        self.spatialNotes = spatialNotes
        self.thumbnailFilePath = thumbnailFilePath
    }
}