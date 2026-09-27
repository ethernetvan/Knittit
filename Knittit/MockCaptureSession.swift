import Foundation
import Combine

#if targetEnvironment(simulator)
@MainActor
public class MockCaptureSession: CaptureSessionProvider {
    private var stateSubject = CurrentValueSubject<CaptureSessionState, Never>(.initializing)
    
    public var state: CaptureSessionState { stateSubject.value }
    public var statePublisher: AnyPublisher<CaptureSessionState, Never> { stateSubject.eraseToAnyPublisher() }
    
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
        
        // Dynamic lookup based on the path of this source file
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
                print("Mock images copied successfully!")
            } catch {
                print("Error copying mock images: \\(error)")
            }
        } else {
            print("Could not find the mock images dir at \\(dataDir.path)")
        }
    }
}
#endif