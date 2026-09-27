import Foundation
import Combine
#if !targetEnvironment(simulator)
import RealityKit

@MainActor
public class RealCaptureSession: CaptureSessionProvider {
    private let session = ObjectCaptureSession()
    private var cancellables = Set<AnyCancellable>()
    private var stateSubject = CurrentValueSubject<CaptureSessionState, Never>(.initializing)
    
    public var state: CaptureSessionState { stateSubject.value }
    public var statePublisher: AnyPublisher<CaptureSessionState, Never> { stateSubject.eraseToAnyPublisher() }
    
    public var objectCaptureSession: ObjectCaptureSession? { session }
    
    public init() {
        session.$state
            .sink { [weak self] state in
                let mapped: CaptureSessionState
                switch state {
                case .initializing: mapped = .initializing
                case .ready: mapped = .ready
                case .detecting: mapped = .detecting
                case .capturing: mapped = .capturing
                case .finishing: mapped = .finishing
                case .completed: mapped = .completed
                case .failed(let err):
                    print("Session failed: \(err)")
                    mapped = .initializing
                @unknown default: mapped = .initializing
                }
                self?.stateSubject.send(mapped)
            }
            .store(in: &cancellables)
    }
    
    public func setupSession(captureFolder: URL) {
        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = captureFolder.appendingPathComponent("Snapshots/")
        // Configuration can be further set here if required
    }
    
    public func startDetecting(captureFolder: URL) {
        let imagesURL = captureFolder.appendingPathComponent("Images/")
        try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        
        var config = ObjectCaptureSession.Configuration()
        config.checkpointDirectory = captureFolder.appendingPathComponent("Snapshots/")
        
        session.start(imagesDirectory: imagesURL, configuration: config)
    }
    
    public func startCapturing() {
        session.startCapturing()
    }
    
    public func finishCapture() {
        session.finish()
    }
}
#endif