import Foundation
import SwiftUI
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import RealityKit

@MainActor
class ScanningManager: ObservableObject {
    @Published var sessionProvider: CaptureSessionProvider?
    @Published var captureState: CaptureSessionState = .initializing
    
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var extractedColors: [String] = []
    
    private var captureFolder: URL?
    private var cancellables = Set<AnyCancellable>()
    private var photogrammetrySession: PhotogrammetrySession?
    
    init() {
        setupSession()
    }
    
    func setupSession() {
        let provider: CaptureSessionProvider
        if ObjectCaptureSession.isSupported {
            provider = RealCaptureSession()
        } else {
            provider = MockCaptureSession()
        }
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderName = UUID().uuidString
        let folderURL = documentsDir.appendingPathComponent("Scans/\(folderName)", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        self.captureFolder = folderURL
        provider.setupSession(captureFolder: folderURL)
        
        provider.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.captureState = state
            }
            .store(in: &cancellables)
            
        self.sessionProvider = provider
    }
    
    func startDetecting() {
        guard let folderURL = captureFolder else { return }
        sessionProvider?.startDetecting(captureFolder: folderURL)
    }
    
    func startCapturing() {
        sessionProvider?.startCapturing()
    }
    
    func finishCapture() {
        sessionProvider?.finishCapture()
    }
    
    // Processes the captured images into a USDZ file using PhotogrammetrySession
    func processScan(completion: @escaping (URL?, [String]) -> Void) {
        guard let captureFolder = captureFolder else { return }
        let imagesFolder = captureFolder.appendingPathComponent("Images/")
        let modelURL = captureFolder.appendingPathComponent("model.usdz")
        
        isProcessing = true
        progress = 0.0
        
        // Core Feature 1 Bonus Hook: Extract dominant colors
        extractColors(from: imagesFolder)
        
        guard PhotogrammetrySession.isSupported else {
            print("Photogrammetry is not supported on this device. Falling back to mock model.")
            simulateModelProcessing(modelURL: modelURL, completion: completion)
            return
        }
        
        // Check if we are actually using the Mock provider. If so, we probably want to mock processing too,
        // because the mock session doesn't create real images that PhotogrammetrySession can process properly (or it might, but it could be slow).
        // For now, if we used MockCaptureSession, also do simulateModelProcessing to be safe.
        if sessionProvider is MockCaptureSession {
            print("Using mock capture session. Simulating model processing.")
            simulateModelProcessing(modelURL: modelURL, completion: completion)
            return
        }
        
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
    
    private func simulateModelProcessing(modelURL: URL, completion: @escaping (URL?, [String]) -> Void) {
        Task {
            // Animate progress to simulate photogrammetry reconstruction
            for step in 1...10 {
                try? await Task.sleep(nanoseconds: 150_000_000)
                self.progress = Double(step) / 10.0
            }
            
            let finalURL: URL?
            if let mockUSDZ = pickMockUSDZ() {
                do {
                    if FileManager.default.fileExists(atPath: modelURL.path) {
                        try FileManager.default.removeItem(at: modelURL)
                    }
                    try FileManager.default.copyItem(at: mockUSDZ, to: modelURL)
                    print("Mock USDZ copied from \(mockUSDZ.lastPathComponent) to \(modelURL.path)")
                    finalURL = modelURL
                } catch {
                    print("Failed to copy mock USDZ: \(error)")
                    finalURL = mockUSDZ
                }
            } else {
                print("No mock USDZ files found in Data folder or bundle.")
                finalURL = nil
            }
            
            self.isProcessing = false
            completion(finalURL, self.extractedColors)
        }
    }
    
    private func pickMockUSDZ() -> URL? {
        var usdzURLs: [URL] = []
        
        // Try looking in the bundled Data folder or main bundle
        if let bundleUSDZs = Bundle.main.urls(forResourcesWithExtension: "usdz", subdirectory: "Data") {
            usdzURLs.append(contentsOf: bundleUSDZs)
        }
        if let bundleUSDZs = Bundle.main.urls(forResourcesWithExtension: "usdz", subdirectory: nil) {
            usdzURLs.append(contentsOf: bundleUSDZs)
        }
        
        // Also try the fallback relative to #file for simulator / previews if not in bundle
        let sourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        let dataDir = sourceDir.appendingPathComponent("Data")
        
        if FileManager.default.fileExists(atPath: dataDir.path) {
            if let files = try? FileManager.default.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil) {
                usdzURLs.append(contentsOf: files.filter { $0.pathExtension.lowercased() == "usdz" })
            }
        }
        
        return usdzURLs.randomElement()
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
