import SwiftUI
import RealityKit
import SwiftData

struct ScanningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let project: KnitProject
    
    @StateObject private var manager = ScanningManager()
    @State private var showWarningModal = true
    
    var body: some View {
        ZStack {
            if let session = manager.session {
                ObjectCaptureView(session: session)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // State handling
                    if case .ready = session.state {
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
                    } else if case .detecting = session.state {
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
                    } else if case .capturing = session.state {
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
                    } else if case .finishing = session.state {
                        Text("Finishing capture...")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding()
                    } else if case .completed = session.state {
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
            
            let newVersion = ProjectVersion(
                scanDate: Date(),
                progressPercentage: 50, // This could be user input
                usdzFilePath: usdzURL.path
            )
            
            project.versions.append(newVersion)
            
            // Core Feature 1 Bonus: Add extracted colors to project
            for color in colors {
                if !project.colorPalette.contains(color) {
                    project.colorPalette.append(color)
                }
            }
            
            try? modelContext.save()
            dismiss()
        }
    }
}
