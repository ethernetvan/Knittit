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
    
    // Core states
    @State private var activeNoteText: String? = nil
    @State private var baseRotation: simd_quatf = .init(angle: 0, axis: [0, 1, 0])
    @State private var dragRotation: simd_quatf = .init(angle: 0, axis: [0, 1, 0])
    @State private var baseScale: Float = 1.0
    @State private var magnifyScale: Float = 1.0
    
    @State private var currentModelEntity: ModelEntity?
    @State private var rootEntity: Entity = {
        let root = Entity()
        root.name = "Root"
        return root
    }()
    
    // Sort versions by date
    var sortedVersions: [ProjectVersion] {
        project.versions.sorted { $0.scanDate < $1.scanDate }
    }
    
    var currentVersion: ProjectVersion? {
        guard !sortedVersions.isEmpty else { return nil }
        let safeIndex = min(max(0, currentVersionIndex), sortedVersions.count - 1)
        return sortedVersions[safeIndex]
    }
    
    var body: some View {
        ZStack {
            if let version = currentVersion {
                RealityView { content in
                    content.add(rootEntity)
                    loadModel(for: version)
                } update: { content in
                    rootEntity.transform.rotation = baseRotation * dragRotation
                    rootEntity.transform.scale = SIMD3<Float>(repeating: baseScale * magnifyScale)
                    updateNotes(for: version)
                }
                .gesture(
                    DragGesture()
                        .targetedToAnyEntity()
                        .onChanged { value in
                            let rotY = simd_quatf(angle: Float(value.translation.width) * 0.01, axis: [0, 1, 0])
                            let rotX = simd_quatf(angle: Float(value.translation.height) * 0.01, axis: [1, 0, 0])
                            dragRotation = rotY * rotX
                        }
                        .onEnded { _ in
                            baseRotation = baseRotation * dragRotation
                            dragRotation = .init(angle: 0, axis: [0, 1, 0])
                        }
                )
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            magnifyScale = Float(value.magnification)
                        }
                        .onEnded { value in
                            baseScale *= Float(value.magnification)
                            magnifyScale = 1.0
                        }
                )
                .gesture(
                    SpatialTapGesture()
                        .targetedToAnyEntity()
                        .onEnded { value in
                            let entity = value.entity
                            if entity.name.hasPrefix("note_") {
                                let idString = entity.name.dropFirst(5)
                                if let note = currentVersion?.spatialNotes.first(where: { $0.id.uuidString == String(idString) }) {
                                    withAnimation {
                                        if activeNoteText == note.text {
                                            activeNoteText = nil
                                        } else {
                                            activeNoteText = note.text
                                        }
                                    }
                                }
                            } else if entity.name == "ScannedModel" {
                                withAnimation { activeNoteText = nil }
                                let bounds = entity.visualBounds(relativeTo: nil)
                                let localPos = SIMD3<Float>(Float.random(in: bounds.min.x...bounds.max.x), Float.random(in: bounds.min.y...bounds.max.y), Float.random(in: bounds.min.z...bounds.max.z))
                                self.tappedLocation = localPos
                                self.showNoteInput = true
                            }
                        }
                )
                .onChange(of: version.id) { _, _ in
                    withAnimation { activeNoteText = nil }
                    loadModel(for: version)
                }
                
                if let noteText = activeNoteText {
                    VStack {
                        Spacer()
                        Text(noteText)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .shadow(radius: 10)
                            .padding(.bottom, 120) // above timeline
                    }
                    .transition(.opacity)
                }
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
                        
                        if sortedVersions.count > 1 {
                            Slider(
                                value: Binding(
                                    get: { Double(min(max(0, currentVersionIndex), sortedVersions.count - 1)) },
                                    set: { currentVersionIndex = Int($0) }
                                ),
                                in: 0...Double(sortedVersions.count - 1),
                                step: 1
                            )
                            .padding(.horizontal)
                        }
                        
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
    
    private func getUSDZURL(for version: ProjectVersion) -> URL {
        let path = version.usdzFilePath
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        } else {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return docDir.appendingPathComponent(path)
        }
    }
    
    private func loadModel(for version: ProjectVersion) {
        Task { @MainActor in
            let url = getUSDZURL(for: version)
            if let model = try? await ModelEntity(contentsOf: url) {
                model.name = "ScannedModel"
                model.components.set(InputTargetComponent(allowedInputTypes: .all))
                model.generateCollisionShapes(recursive: true)
                
                let bounds = model.visualBounds(relativeTo: nil)
                let ex = bounds.extents
                let maxExtent = max(ex.x, max(ex.y, ex.z))
                if maxExtent > 0 {
                    let targetSize: Float = 0.5
                    let scale = targetSize / maxExtent
                    model.scale = SIMD3<Float>(repeating: scale)
                    model.position = -bounds.center * scale
                }
                
                rootEntity.children.filter { $0.name == "ScannedModel" }.forEach { $0.removeFromParent() }
                rootEntity.addChild(model)
                currentModelEntity = model
                
                // Immediately attach notes
                updateNotes(for: version)
            }
        }
    }
    
    private func updateNotes(for version: ProjectVersion) {
        guard let model = currentModelEntity else { return }
        
        let existingNoteIDs = Set(model.children.filter { $0.name.hasPrefix("note_") }.compactMap { UUID(uuidString: String($0.name.dropFirst(5))) })
        let currentNoteIDs = Set(version.spatialNotes.map { $0.id })
        
        // Remove deleted notes
        for noteEntity in model.children where noteEntity.name.hasPrefix("note_") {
            if let noteID = UUID(uuidString: String(noteEntity.name.dropFirst(5))), !currentNoteIDs.contains(noteID) {
                noteEntity.removeFromParent()
            }
        }
        
        // Add new notes
        let invScale = 1.0 / model.scale.x
        let noteRadius: Float = 0.02 * invScale
        
        for note in version.spatialNotes where !existingNoteIDs.contains(note.id) {
            let marker = ModelEntity(
                mesh: .generateSphere(radius: noteRadius),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            marker.name = "note_\(note.id)"
            marker.position = SIMD3<Float>(note.x, note.y, note.z)
            marker.components.set(InputTargetComponent(allowedInputTypes: .all))
            marker.generateCollisionShapes(recursive: false)
            
            let emoji = ModelEntity(
                mesh: .generateText("💬", extrusionDepth: 0.001, font: .systemFont(ofSize: CGFloat(noteRadius * 1.5))),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            let emojiBounds = emoji.visualBounds(relativeTo: nil)
            emoji.position = SIMD3<Float>(-emojiBounds.extents.x / 2, noteRadius * 1.1, 0)
            marker.addChild(emoji)
            
            model.addChild(marker)
        }
    }
    
    private func saveSpatialNote() {
        guard let location = tappedLocation, !spatialNoteText.isEmpty, let version = currentVersion else { return }
        
        let newNote = SpatialNote(text: spatialNoteText, x: location.x, y: location.y, z: location.z)
        version.spatialNotes.append(newNote)
        
        spatialNoteText = ""
        tappedLocation = nil
        
        // Refresh notes in the RealityView explicitly
        updateNotes(for: version)
    }
    
    private func exportVideo() {
        guard let version = currentVersion else { return }
        isExporting = true
        
        VideoExportManager.shared.export360Video(usdzPath: getUSDZURL(for: version).path) { success in
            isExporting = false
        }
    }
}
