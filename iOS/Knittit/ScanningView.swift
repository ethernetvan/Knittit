import SwiftUI
#if !targetEnvironment(simulator)
import RealityKit
#endif
import Supabase

@available(iOS 17.0, *)
struct ScanningView: View {
    @StateObject private var manager = ScanningManager()
    @State private var showWarningModal = true
    @State private var showingSaveProject = false
    @State private var latestUSDZURL: URL?
    
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
                    
                    if case .ready = manager.captureState {
                        Button {
                            manager.startDetecting()
                        } label: {
                            Text("Start Detecting")
                                .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity).background(Color.blue).cornerRadius(12)
                        }
                        .padding()
                    } else if case .detecting = manager.captureState {
                        Button {
                            manager.startCapturing()
                        } label: {
                            Text("Start Capturing")
                                .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity).background(Color.green).cornerRadius(12)
                        }
                        .padding()
                    } else if case .capturing = manager.captureState {
                        Button {
                            manager.finishCapture()
                        } label: {
                            Text("Finish Capture")
                                .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity).background(Color.red).cornerRadius(12)
                        }
                        .padding()
                    } else if case .finishing = manager.captureState {
                        Text("Finishing capture...")
                            .padding().background(.ultraThinMaterial).cornerRadius(8).padding()
                    } else if case .completed = manager.captureState {
                        Button {
                            compileModel()
                        } label: {
                            Text("Compile 3D Model")
                                .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity).background(Color.purple).cornerRadius(12)
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
                    .resizable().scaledToFit().frame(width: 60, height: 60).foregroundColor(.orange)
                Text("Scanning Tips").font(.title2).bold()
                Text("Place fuzzy yarn on a highly patterned, non-white background.")
                    .font(.headline).multilineTextAlignment(.center)
                Button {
                    showWarningModal = false
                } label: {
                    Text("I Understand")
                        .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity).background(Color.blue).cornerRadius(12)
                }
                .padding(.top)
            }
            .padding().presentationDetents([.fraction(0.5)]).interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingSaveProject) {
            if let usdz = latestUSDZURL {
                SaveProjectView(usdzURL: usdz)
            }
        }
    }
    
    private func compileModel() {
        manager.processScan { usdzURL, colors in
            guard let usdzURL = usdzURL else { return }
            self.latestUSDZURL = usdzURL
            self.showingSaveProject = true
        }
    }
}

@available(iOS 17.0, *)
struct SaveProjectView: View {
    let usdzURL: URL
    @State private var title = "Scanned Project"
    @State private var yarnBrand = ""
    @State private var toolSize = ""
    @State private var progressPercentage: Double = 100.0
    @State private var isUploading = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Project Details") {
                    if isUploading {
                        ProgressView("Uploading to Supabase...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        TextField("Title", text: $title)
                        TextField("Yarn Brand", text: $yarnBrand)
                        TextField("Tool Size", text: $toolSize)
                        VStack {
                            Text("Progress: \(Int(progressPercentage))%")
                            Slider(value: $progressPercentage, in: 0...100, step: 1)
                        }
                        
                        Button("Save and Upload") {
                            Task {
                                await uploadModel()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save Project")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
    
    private func uploadModel() async {
        guard let user = try? await SupabaseManager.shared.client.auth.session.user else { return }
        
        isUploading = true
        do {
            let fileData = try Data(contentsOf: usdzURL)
            let fileName = "\(UUID().uuidString).usdz"
            
            try await SupabaseManager.shared.client.storage
                .from("scans")
                .upload(fileName, data: fileData, options: FileOptions(contentType: "model/vnd.usdz+zip"))
            
            let publicURL = try SupabaseManager.shared.client.storage
                .from("scans")
                .getPublicURL(path: fileName)
            
            let projectId = UUID()
            let project = SupabaseProject(id: projectId, userId: user.id, createdAt: Date(), title: title, yarnBrand: yarnBrand, toolSize: toolSize, patternSource: nil, colorPalette: nil)
            try await SupabaseManager.shared.client.from("projects").insert(project).execute()
            
            let version = SupabaseProjectVersion(id: UUID(), projectId: projectId, createdAt: Date(), usdzFilePath: publicURL.absoluteString, progressPercentage: Int(progressPercentage))
            try await SupabaseManager.shared.client.from("project_versions").insert(version).execute()
            
            isUploading = false
            dismiss()
            
        } catch {
            print("Upload failed: \(error)")
            isUploading = false
        }
    }
}