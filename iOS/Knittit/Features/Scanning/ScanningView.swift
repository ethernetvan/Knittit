import SwiftUI
#if !targetEnvironment(simulator)
import RealityKit
#endif
import SwiftData

struct ScanningView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var manager = ScanningManager()
    @State private var showWarningModal = true
    
    // Callback to let the parent know when the scan is done and what data was generated.
    var onScanComplete: (URL, [String]) -> Void
    
    var body: some View {
        ZStack {
            if let provider = manager.sessionProvider {
                
                #if targetEnvironment(simulator)
                Color.black.ignoresSafeArea()
                VStack {
                    Text("Simulator Capture Mock")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("State: \(String(describing: manager.captureState))")
                        .foregroundColor(.gray)
                }
                #else
                if let objectSession = provider.objectCaptureSession {
                    ObjectCaptureView(session: objectSession)
                        .ignoresSafeArea()
                }
                #endif
                
                VStack {
                    Spacer()
                    

                    // State handling
                    if manager.sessionProvider is MockCaptureSession {
                        VStack(spacing: 4) {
                            Text("Mock Model to Spawn")
                                .font(.caption)
                                .foregroundColor(.white)
                            Picker("Mock Model", selection: $manager.selectedMockModel) {
                                ForEach(manager.availableMockModels, id: \.self) { url in
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .tag(url as URL?)
                                        .foregroundColor(.primary)
                                }
                            }
                            .tint(.white)
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    if case .ready = manager.captureState {
                        Button {
                            manager.startDetecting()
                        } label: {
                            Text("Start Detecting")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding()
                    } else if case .detecting = manager.captureState {
                        Button {
                            manager.startCapturing()
                        } label: {
                            Text("Start Capturing")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        .padding()
                    } else if case .capturing = manager.captureState {
                        Button {
                            manager.finishCapture()
                        } label: {
                            Text("Finish Capture")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                        .padding()
                    } else if case .finishing = manager.captureState {
                        Text("Finishing capture...")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding()
                    } else if case .completed = manager.captureState {
                        Button {
                            compileModel()
                        } label: {
                            Text("Compile 3D Model")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                        .padding()
                    }
                }
            }
            
            if manager.isProcessing {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView(value: manager.progress)
                            .progressViewStyle(.circular)
                            .scaleEffect(2)
                            .tint(.white)
                        
                        Text("Compiling USDZ...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("\(Int(manager.progress * 100))%")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showWarningModal) {
            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.orange)
                
                Text("Scanning Tips")
                    .font(.title2).bold()
                
                Text("Place fuzzy yarn on a highly patterned, non-white background.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("This ensures the LiDAR and photogrammetry algorithms can track spatial anchors effectively.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Button {
                    showWarningModal = false
                } label: {
                    Text("I Understand")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top)
            }
            .padding()
            .presentationDetents([.fraction(0.5)])
            .interactiveDismissDisabled()
        }
    }
    
    private func compileModel() {
        manager.processScan { usdzURL, colors in
            guard let usdzURL = usdzURL else { return }
            onScanComplete(usdzURL, colors)
        }
    }
}
