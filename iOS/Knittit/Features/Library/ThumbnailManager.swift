import QuickLookThumbnailing
import SwiftUI
import Foundation
import SceneKit
import SceneKit.ModelIO

class ThumbnailManager {
    static let shared = ThumbnailManager()
    
    private init() {}
    
    func getThumbnail(for version: ProjectVersion) async -> UIImage? {
        // If there's a pre-rendered thumbnail, try to load it first
        if let thumbPath = version.project?.thumbnailFilePath, !thumbPath.isEmpty {
            if thumbPath.hasPrefix("http") {
                // If it's remote, handle asynchronously or just let UI handle it with AsyncImage
                // Returning nil means the UI might want to load it themselves or fallback
                // For a quick fix, let's keep it returning UIImage from local if possible
            } else {
                var url = URL(fileURLWithPath: thumbPath)
                if !thumbPath.hasPrefix("/") {
                    let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    url = docDir.appendingPathComponent(thumbPath)
                }
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    return image
                }
            }
        }
        
        let size = CGSize(width: 300, height: 300)
        let scale = await MainActor.run {
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.scale ?? 2.0
        }
        
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
        
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        
        var uiImage: UIImage? = await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let thumb = thumbnail {
                    continuation.resume(returning: thumb.uiImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        
        if uiImage == nil {
            uiImage = await MainActor.run {
                return generateSceneKitSnapshot(for: url, size: size, scale: scale)
            }
        }
        
        return uiImage
    }
    
    /// Generates a thumbnail for a USDZ file, saves it to the Documents directory as a JPEG,
    /// and returns the relative file path.
    func generateAndSaveThumbnail(for usdzURL: URL) async -> String? {
        let size = CGSize(width: 500, height: 500)
        let scale = await MainActor.run {
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.scale ?? 2.0
        }
        
        let request = QLThumbnailGenerator.Request(fileAt: usdzURL, size: size, scale: scale, representationTypes: .thumbnail)
        
        var uiImage: UIImage? = await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let thumb = thumbnail {
                    continuation.resume(returning: thumb.uiImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        
        // If QuickLook fails (which happens on Simulator with some USDZ files), generate a fallback image representing a snapshot
        if uiImage == nil {
            uiImage = await MainActor.run {
                return generateSceneKitSnapshot(for: usdzURL, size: size, scale: scale)
            }
        }
        
        if uiImage == nil {
            let config = UIImage.SymbolConfiguration(pointSize: 150, weight: .regular)
            if let cubeIcon = UIImage(systemName: "cube.fill", withConfiguration: config) {
                // Draw a nice colored background square with the cube in the middle
                UIGraphicsBeginImageContextWithOptions(size, false, scale)
                UIColor.systemGray5.setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
                
                UIColor.systemGray.set()
                let iconRect = CGRect(
                    x: (size.width - cubeIcon.size.width) / 2,
                    y: (size.height - cubeIcon.size.height) / 2,
                    width: cubeIcon.size.width,
                    height: cubeIcon.size.height
                )
                cubeIcon.draw(in: iconRect)
                uiImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
        }
        
        guard let img = uiImage, let jpegData = img.jpegData(compressionQuality: 0.8) else { return nil }
        
        let filename = UUID().uuidString + ".jpg"
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let thumbnailsDir = docDir.appendingPathComponent("Thumbnails", isDirectory: true)
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: thumbnailsDir.path) {
            try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
        }
        
        let fileURL = thumbnailsDir.appendingPathComponent(filename)
        
        do {
            try jpegData.write(to: fileURL)
            return "Thumbnails/" + filename
        } catch {
            print("Failed to save thumbnail to \(fileURL): \(error)")
            return nil
        }
    }

    @MainActor
    private func generateSceneKitSnapshot(for url: URL, size: CGSize, scale: CGFloat) -> UIImage? {
        guard let scene = try? SCNScene(url: url, options: nil) else { return nil }
        
        let view = SCNView(frame: CGRect(origin: .zero, size: size))
        view.contentScaleFactor = scale
        view.scene = scene
        view.autoenablesDefaultLighting = true // Add default lights
        view.backgroundColor = UIColor.clear
        
        // Wait for rendering to settle if needed, but snapshot should handle it synchronously for simple models
        return view.snapshot()
    }
}
