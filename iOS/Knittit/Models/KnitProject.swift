import Foundation
import SwiftData

@Model
final class KnitProject {
    var id: UUID = UUID()
    var title: String
    var yarnBrand: String
    var toolSize: String
    var colorPalette: [String] // Array of Hex Strings
    
    @Relationship(deleteRule: .cascade, inverse: \ProjectVersion.project)
    var versions: [ProjectVersion]
    
    init(title: String, yarnBrand: String, toolSize: String, colorPalette: [String] = [], versions: [ProjectVersion] = []) {
        self.title = title
        self.yarnBrand = yarnBrand
        self.toolSize = toolSize
        self.colorPalette = colorPalette
        self.versions = versions
    }
}