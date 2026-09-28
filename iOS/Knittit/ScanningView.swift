import SwiftUI
import RealityKit
import Supabase

#if os(iOS)
@available(iOS 17.0, *)
struct ScanningView: View {
    @State private var session = ObjectCaptureSession()
    @State private var showWarning = true
    @State private var captureDir: URL?
    @State private var isProcessing = false
    @State private var compilationProgress: Double = 0.0
    @State private var showingSaveProject = false
    @State private var latestUSDZURL: URL?
    
    var project: KnitProject? = nil
    init(project: KnitProject? = nil) {
        self.project = project
    }
    @State private var selectedProjectId: UUID?
    
    var body: some View {
        ZStack {
            if isProcessing {
                VStack(spacing: 20) {
                    ProgressView(value: compilationProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .padding()
                    
                    Text("Compiling 3D Model...")
                        .font(.headline)
                    Text("\(Int(compilationProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.systemBackground).opacity(0.8))
                .cornerRadius(16)
            } else {
                ObjectCaptureView(session: session)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    if session.state == .ready {
                        Button("Start Detecting") {
                            session.startDetecting()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    } else if session.state == .detecting {
                        Button("Start Capturing") {
                            session.startCapturing()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    } else if session.state == .capturing {
                        Button("Finish Capture") {
                            session.finish()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            setupCaptureDir()
        }
        .alert("Scanning Best Practices", isPresented: $showWarning) {
            Button("I Understand", role: .cancel) {
                if let dir = captureDir {
                    var configuration = ObjectCaptureSession.Configuration()
                    configuration.checkpointDirectory = dir.appendingPathComponent("Snapshots/")
                    session.start(imagesDirectory: dir.appendingPathComponent("Images/"),
                                  configuration: configuration)
                }
            }
        } message: {
            Text("Place fuzzy yarn projects on a highly patterned, non-white background for proper LiDAR tracking.")
        }
        .onChange(of: session.state) { _, newState in
            if newState == .completed {
                Task {
                    await compileModel()
                }
            }
        }
        .sheet(isPresented: $showingSaveProject) {
            if let usdz = latestUSDZURL {
                SaveProjectView(usdzURL: usdz)
            }
        }
    }
    
    private func setupCaptureDir() {
        let tempDir = FileManager.default.temporaryDirectory
        let newDir = tempDir.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
            self.captureDir = newDir
        } catch {
            print("Failed to create capture dir: \(error)")
        }
    }
    
    private func compileModel() async {
        guard let captureDir = captureDir else { return }
        await MainActor.run { isProcessing = true }
        
        let imagesDir = captureDir.appendingPathComponent("Images/")
        let modelURL = captureDir.appendingPathComponent("model.usdz")
        
        do {
            let session = try PhotogrammetrySession(
                input: imagesDir,
                configuration: PhotogrammetrySession.Configuration()
            )
            
            try session.process(requests: [.modelFile(url: modelURL)])
            
            for try await output in session.outputs {
                switch output {
                case .processingComplete:
                    await MainActor.run {
                        self.latestUSDZURL = modelURL
                        self.isProcessing = false
                        self.showingSaveProject = true
                    }
                case .requestProgress(_, let fractionComplete):
                    await MainActor.run {
                        self.compilationProgress = fractionComplete
                    }
                case .processingCancelled:
                    await MainActor.run { isProcessing = false }
                case .requestError(_, let error):
                    print("Photogrammetry Error: \(error)")
                    await MainActor.run { isProcessing = false }
                default:
                    break
                }
            }
            
        } catch {
            print("Failed to compile model: \(error)")
            await MainActor.run { isProcessing = false }
        }
    }
}

@available(iOS 17.0, *)
struct SaveProjectView: View {
    let usdzURL: URL
    @State private var notes = ""
    @State private var isUploading = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Upload Model") {
                    if isUploading {
                        ProgressView("Uploading to Supabase...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        TextField("Version Notes", text: $notes)
                        
                        Button("Save and Upload") {
                            Task {
                                await uploadModel()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save SupabaseProject")
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
            let project = SupabaseProject(id: projectId, ownerId: user.id, createdAt: Date(), title: "Scanned SupabaseProject", description: nil)
            try await SupabaseManager.shared.client.from("projects").insert(project).execute()
            
            let version = SupabaseProjectVersion(id: UUID(), projectId: projectId, createdAt: Date(), usdzUrl: publicURL, versionNotes: notes)
            try await SupabaseManager.shared.client.from("project_versions").insert(version).execute()
            
            isUploading = false
            dismiss()
            
        } catch {
            print("Upload failed: \(error)")
            isUploading = false
        }
    }
}
#endif
