import Foundation
import RealityKit
import SwiftUI
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class ScanningManager: ObservableObject {
    @Published var session: ObjectCaptureSession?
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var extractedColors: [String] = []
    
    private var captureFolder: URL?
    private var photogrammetrySession: PhotogrammetrySession?
    
    init() {
        setupSession()
    }
    
    func setupSession() {
        let newSession = ObjectCaptureSession()
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderName = UUID().uuidString
        let folderURL = documentsDir.appendingPathComponent("Scans/\(folderName)", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = folderURL.appendingPathComponent("Snapshots/")
        
        self.captureFolder = folderURL
        self.session = newSession
    }
    
    func startDetecting() {
        guard let folderURL = captureFolder else { return }
        let imagesURL = folderURL.appendingPathComponent("Images/")
        try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        
        var config = ObjectCaptureSession.Configuration()
        config.checkpointDirectory = folderURL.appendingPathComponent("Snapshots/")
        
        session?.start(imagesDirectory: imagesURL, configuration: config)
    }
    
    func startCapturing() {
        session?.startCapturing()
    }
    
    func finishCapture() {
        session?.finish()
    }
    
    // Processes the captured images into a USDZ file using PhotogrammetrySession
    func processScan(completion: @escaping (URL?, [String]) -> Void) {
        guard let captureFolder = captureFolder else { return }
        let imagesFolder = captureFolder.appendingPathComponent("Images/")
        let modelURL = captureFolder.appendingPathComponent("model.usdz")
        
        isProcessing = true
        
        // Core Feature 1 Bonus Hook: Extract dominant colors
        extractColors(from: imagesFolder)
        
        do {
            photogrammetrySession = try PhotogrammetrySession(input: imagesFolder)
            
            Task {
                guard let photogrammetrySession = photogrammetrySession else { return }
                
                for try await output in photogrammetrySession.outputs {
                    switch output {
                    case .processingComplete:
                        self.isProcessing = false
                        completion(modelURL, self.extractedColors)
                    case .requestProgress(_, let fractionComplete):
                        self.progress = fractionComplete
                    case .processingCancelled:
                        self.isProcessing = false
                    case .requestError(_, let error):
                        print("Photogrammetry error: \(error)")
                        self.isProcessing = false
                    default:
                        break
                    }
                }
            }
            
            try photogrammetrySession?.process(requests: [.modelFile(url: modelURL)])
        } catch {
            print("Photogrammetry setup failed: \(error)")
            isProcessing = false
        }
    }
    
    private func extractColors(from directory: URL) {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return }
        
        var colors = Set<String>()
        var count = 0
        
        for case let fileURL as URL in enumerator {
            if count >= 3 { break } // Just sample a few images
            if fileURL.pathExtension.lowercased() == "heic" || fileURL.pathExtension.lowercased() == "jpg" {
                if let colorHex = averageColor(from: fileURL) {
                    colors.insert(colorHex)
                    count += 1
                }
            }
        }
        
        self.extractedColors = Array(colors)
    }
    
    private func averageColor(from url: URL) -> String? {
        guard let ciImage = CIImage(contentsOf: url) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return String(format: "#%02X%02X%02X", bitmap[0], bitmap[1], bitmap[2])
    }
}
