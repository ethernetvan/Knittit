import Foundation
import Combine
import RealityKit
import _RealityKit_SwiftUI

@MainActor
public class MockCaptureSession: CaptureSessionProvider {
    private var stateSubject = CurrentValueSubject<CaptureSessionState, Never>(.initializing)
    
    public var state: CaptureSessionState { stateSubject.value }
    public var statePublisher: AnyPublisher<CaptureSessionState, Never> { stateSubject.eraseToAnyPublisher() }
    
    @available(iOS 17.0, *)
    public var objectCaptureSession: ObjectCaptureSession? { nil }
    
    private var captureFolder: URL?
    
    public init() {
        // Start out initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.stateSubject.send(.ready)
        }
    }
    
    public func setupSession(captureFolder: URL) {
        self.captureFolder = captureFolder
    }
    
    public func startDetecting(captureFolder: URL) {
        // In the simulator, we bypass actual detection.
        self.captureFolder = captureFolder
        stateSubject.send(.detecting)
    }
    
    public func startCapturing() {
        stateSubject.send(.capturing)
        
        // Copy images from Data/Rock36Images over to the captureFolder immediately
        copyMockImages()
    }
    
    public func finishCapture() {
        stateSubject.send(.finishing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.stateSubject.send(.completed)
        }
    }
    
    private func copyMockImages() {
        guard let folder = captureFolder else { return }
        let imagesURL = folder.appendingPathComponent("Images/")
        try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        
        // Try looking in the bundle first
        var bundlePaths = Bundle.main.urls(forResourcesWithExtension: "heic", subdirectory: "Data/Rock36Images") ?? []
        if bundlePaths.isEmpty {
            bundlePaths = Bundle.main.urls(forResourcesWithExtension: "HEIC", subdirectory: "Data/Rock36Images") ?? []
        }
        if bundlePaths.isEmpty {
            bundlePaths = Bundle.main.urls(forResourcesWithExtension: "heic", subdirectory: nil) ?? []
        }
        if bundlePaths.isEmpty {
            bundlePaths = Bundle.main.urls(forResourcesWithExtension: "HEIC", subdirectory: nil) ?? []
        }
        
        if !bundlePaths.isEmpty {
            for src in bundlePaths {
                let dst = imagesURL.appendingPathComponent(src.lastPathComponent)
                if !FileManager.default.fileExists(atPath: dst.path) {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
            print("Mock images copied successfully from bundle!")
            return
        }
        
        // Dynamic lookup based on the path of this source file (for Simulator preview fallback)
        let sourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        let dataDir = sourceDir.appendingPathComponent("Data/Rock36Images")
        
        if FileManager.default.fileExists(atPath: dataDir.path) {
            do {
                let items = try FileManager.default.contentsOfDirectory(atPath: dataDir.path)
                for item in items where item.lowercased().hasSuffix(".heic") {
                    let src = dataDir.appendingPathComponent(item)
                    let dst = imagesURL.appendingPathComponent(item)
                    if !FileManager.default.fileExists(atPath: dst.path) {
                        try FileManager.default.copyItem(at: src, to: dst)
                    }
                }
                print("Mock images copied successfully from source dir!")
            } catch {
                print("Error copying mock images: \(error)")
            }
        } else {
            print("Could not find the mock images dir at \(dataDir.path)")
        }
    }
}
