//
//  Item.swift
//  Knittit
//
//  Created by Evan Thomas on 9/14/26.
//

import Foundation
import SwiftData

struct SpatialNote: Codable {
    var id: UUID = UUID()
    var text: String
    var x: Float
    var y: Float
    var z: Float
    
    init(text: String, x: Float, y: Float, z: Float) {
        self.text = text
        self.x = x
        self.y = y
        self.z = z
    }
}

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
