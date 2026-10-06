import Foundation

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