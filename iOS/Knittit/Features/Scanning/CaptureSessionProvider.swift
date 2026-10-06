import Foundation
import _RealityKit_SwiftUI
import Combine
import RealityKit

public enum CaptureSessionState {
    case initializing
    case ready
    case detecting
    case capturing
    case finishing
    case completed
}

@MainActor
public protocol CaptureSessionProvider: AnyObject {
    var state: CaptureSessionState { get }
    var statePublisher: AnyPublisher<CaptureSessionState, Never> { get }
    
    func setupSession(captureFolder: URL)
    func startDetecting(captureFolder: URL)
    func startCapturing()
    func finishCapture()
    
    #if !targetEnvironment(simulator)
    var objectCaptureSession: ObjectCaptureSession? { get }
    #endif
}
