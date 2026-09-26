import SwiftUI
import RealityKit
import SwiftData

struct ProjectDetailView: View {
    let project: KnitProject
    @State private var currentVersionIndex: Int = 0
    @State private var isExporting = false
    @State private var spatialNoteText = ""
    @State private var showNoteInput = false
    @State private var tappedLocation: SIMD3<Float>?
    
    // Sort versions by date
    var sortedVersions: [ProjectVersion] {
        project.versions.sorted { $0.scanDate < $1.scanDate }
    }
    
    var currentVersion: ProjectVersion? {
        guard !sortedVersions.isEmpty else { return nil }
        return sortedVersions[currentVersionIndex]
    }
    
    var body: some View {
        ZStack {
            if let version = currentVersion {
                RealityView { content in
                    // Initial setup
                    if let url = URL(string: version.usdzFilePath) {
                        if let model = try? await ModelEntity(contentsOf: url) {
                            model.name = "ScannedModel"
                            model.components.set(InputTargetComponent(allowedInputTypes: .all))
                            model.generateCollisionShapes(recursive: true)
                            content.add(model)
                            
                            // Load existing notes
                            for note in version.spatialNotes {
                                let textMesh = MeshResource.generateText(note.text, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.05))
                                let material = SimpleMaterial(color: .white, isMetallic: false)
                                let modelEntity = ModelEntity(mesh: textMesh, materials: [material])
                                modelEntity.position = SIMD3<Float>(note.x, note.y, note.z)
                                content.add(modelEntity)
                            }
                        }
                    }
                } update: { content in
                    // When version changes, update the model
                    if let url = URL(string: version.usdzFilePath),
                       let newModel = try? tryAwaitModel(url: url) {
                        content.entities.removeAll()
                        newModel.name = "ScannedModel"
                        newModel.components.set(InputTargetComponent(allowedInputTypes: .all))
                        newModel.generateCollisionShapes(recursive: true)
                        content.add(newModel)
                        
                        for note in version.spatialNotes {
                            let textMesh = MeshResource.generateText(note.text, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.05))
                            let material = SimpleMaterial(color: .white, isMetallic: false)
                            let modelEntity = ModelEntity(mesh: textMesh, materials: [material])
                            modelEntity.position = SIMD3<Float>(note.x, note.y, note.z)
                            content.add(modelEntity)
                        }
                    }
                }
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            // Scaffold Note: On iOS, RealityView tap gestures return 2D screen coordinates.
                            // True 2D-to-3D raycasting requires unprojecting from a camera/ARKit session.
                            // For this scaffold, we'll assign a simulated 3D coordinate near the model.
                            self.tappedLocation = SIMD3<Float>(
                                Float.random(in: -0.1...0.1),
                                Float.random(in: 0...0.2),
                                Float.random(in: -0.1...0.1)
                            )
                            self.showNoteInput = true
                        }
                )
            } else {
                VStack {
                    Image(systemName: "cube.box")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No scans yet.")
                    NavigationLink("Start Scanning", destination: ScanningView(project: project))
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
            }
            
            // Timeline Slider Overlay
            if !sortedVersions.isEmpty {
                VStack {
                    Spacer()
                    VStack {
                        Text("Progress: \(currentVersion?.progressPercentage ?? 0)%")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        Slider(
                            value: Binding(
                                get: { Double(currentVersionIndex) },
                                set: { currentVersionIndex = Int($0) }
                            ),
                            in: 0...Double(max(0, sortedVersions.count - 1)),
                            step: 1
                        )
                        .padding(.horizontal)
                        
                        Text(currentVersion?.scanDate ?? Date(), style: .date)
                            .font(.caption)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding()
                }
            }
            
            if isExporting {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack {
                    ProgressView("Generating 360 Video...")
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }
        }
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ScanningView(project: project)) {
                    Image(systemName: "plus.viewfinder")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: exportVideo) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(currentVersion == nil)
            }
        }
        .alert("Add Spatial Note", isPresented: $showNoteInput) {
            TextField("Note", text: $spatialNoteText)
            Button("Save", action: saveSpatialNote)
            Button("Cancel", role: .cancel) { spatialNoteText = "" }
        }
    }
    
    private func tryAwaitModel(url: URL) throws -> ModelEntity? {
        // Synchronous wrapper for SwiftUI update block simplicity in this scaffold
        // A production app should use an async loader class.
        return try? ModelEntity.loadModel(contentsOf: url)
    }
    
    private func saveSpatialNote() {
        guard let location = tappedLocation, !spatialNoteText.isEmpty, let version = currentVersion else { return }
        
        let newNote = SpatialNote(text: spatialNoteText, x: location.x, y: location.y, z: location.z)
        version.spatialNotes.append(newNote)
        
        spatialNoteText = ""
        tappedLocation = nil
    }
    
    private func exportVideo() {
        guard let version = currentVersion else { return }
        isExporting = true
        
        VideoExportManager.shared.export360Video(usdzPath: version.usdzFilePath) { success in
            isExporting = false
            // Handle success/failure
        }
    }
}
