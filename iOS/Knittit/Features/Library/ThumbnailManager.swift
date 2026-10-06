import QuickLookThumbnailing
import SwiftUI
import Foundation

class ThumbnailManager {
    static let shared = ThumbnailManager()
    
    private init() {}
    
    func getThumbnail(for version: ProjectVersion) async -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let scale = UIScreen.main.scale
        
        let url: URL
        if version.usdzFilePath.hasPrefix("/") {
            url = URL(fileURLWithPath: version.usdzFilePath)
        } else if version.usdzFilePath.hasPrefix("http") {
             // Mock standard fallback for remote
             return nil
        } else {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            url = docDir.appendingPathComponent(version.usdzFilePath)
        }
        
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let thumb = thumbnail {
                    continuation.resume(returning: thumb.uiImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
