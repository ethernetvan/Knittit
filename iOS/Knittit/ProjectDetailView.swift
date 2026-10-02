import SwiftUI
import RealityKit
import SwiftData

struct ProjectDetailView: View {
    let project: KnitProject
    @Environment(\.modelContext) private var modelContext
    @State private var showEditProject = false
    @State private var currentVersionIndex: Int = 0
    @State private var isExporting = false
    @State private var spatialNoteText = ""
    @State private var showNoteInput = false
    @State private var tappedLocation: SIMD3<Float>?
    @State private var queuedTapLocation: CGPoint? = nil
    @State private var activeNoteID: UUID? = nil
    @State private var editingNoteID: UUID? = nil
    
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
    
    var sortedVersions: [ProjectVersion] {
        project.versions.sorted { $0.scanDate < $1.scanDate }
    }
    
    var currentVersion: ProjectVersion? {
        guard !sortedVersions.isEmpty else { return nil }
        let safeIndex = min(max(0, currentVersionIndex), sortedVersions.count - 1)
        return sortedVersions[safeIndex]
    }
    
    var modelDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                withAnimation { activeNoteID = nil }
                let rotY = simd_quatf(angle: Float(value.translation.width) * 0.01, axis: SIMD3<Float>(0, 1, 0))
                let rotX = simd_quatf(angle: Float(value.translation.height) * 0.01, axis: SIMD3<Float>(1, 0, 0))
                dragRotation = rotY * rotX
            }
            .onEnded { _ in
                baseRotation = baseRotation * dragRotation
                dragRotation = .init(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            }
    }
    
    var modelMagnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                withAnimation { activeNoteID = nil }
                magnifyScale = Float(value.magnification)
            }
            .onEnded { value in
                baseScale *= Float(value.magnification)
                magnifyScale = 1.0
            }
    }
    
    var modelSpatialTapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                let entity = value.entity
                if entity.name.hasPrefix("note_") {
                    let idString = entity.name.dropFirst(5)
                    if let noteID = UUID(uuidString: String(idString)) {
                        withAnimation {
                            if activeNoteID == noteID {
                                activeNoteID = nil
                            } else {
                                activeNoteID = noteID
                            }
                        }
                    }
                } else if entity.name == "ScannedModel" {
                    withAnimation { activeNoteID = nil }
                    self.queuedTapLocation = value.location
                }
            }
    }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        withAnimation { activeNoteID = nil }
                    }
                )
                
            if let version = currentVersion {
                RealityView { content in
                    content.add(rootEntity)
                    loadModel(for: version)
                } update: { content in
                    handleUpdate(content: content, version: version)
                }
                .gesture(modelDragGesture)
                .gesture(modelMagnifyGesture)
                .gesture(modelSpatialTapGesture)
                .onChange(of: version.id) { _, _ in
                    withAnimation { activeNoteID = nil }
                    loadModel(for: version)
                }
                
                // Overlay for Editing/Deleting the active Note
                if let activeID = activeNoteID, let note = version.spatialNotes.first(where: { $0.id == activeID }) {
                    VStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Text(note.text)
                                .font(.headline)
                                .foregroundColor(.primary)
                            HStack(spacing: 40) {
                                Button(action: {
                                    spatialNoteText = note.text
                                    editingNoteID = note.id
                                    showNoteInput = true
                                }) {
                                    VStack {
                                        Image(systemName: "pencil")
                                        Text("Edit")
                                            .font(.caption)
                                    }
                                }
                                Button(action: {
                                    deleteNote(note, from: version)
                                }) {
                                    VStack {
                                        Image(systemName: "trash")
                                        Text("Delete")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                        .padding(.bottom, 120)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
            } else {
                VStack {
                    Image(systemName: "cube.box")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No scans yet.")
                    NavigationLink("Start Scanning", destination: ScanningView())
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
            }
            
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
                Menu {
                    NavigationLink(destination: ScanningView()) {
                        Label("Add Scan", systemImage: "plus.viewfinder")
                    }
                    Button(action: exportVideo) {
                        Label("Export Video", systemImage: "square.and.arrow.up")
                    }
                    .disabled(currentVersion == nil)
                    
                    Button {
                        showEditProject = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        if let version = currentVersion {
                            let versionId = version.id
                            project.versions.removeAll(where: { $0.id == versionId })
                            modelContext.delete(version)
                            
                            if currentVersionIndex >= project.versions.count {
                                currentVersionIndex = max(0, project.versions.count - 1)
                            }
                            
                            try? modelContext.save()
                        }
                    } label: {
                        Label("Delete Current Scan", systemImage: "trash")
                    }
                    .disabled(currentVersion == nil)
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditProject) {
            EditProjectView(project: project)
        }
        .alert(editingNoteID == nil ? "Add Spatial Note" : "Edit Note", isPresented: $showNoteInput) {
            TextField("Note", text: $spatialNoteText)
            Button("Save", action: saveSpatialNote)
            Button("Cancel", role: .cancel) { 
                spatialNoteText = ""
                editingNoteID = nil
            }
        }
    }
    
    private func handleUpdate(content: RealityViewCameraContent, version: ProjectVersion) {
        rootEntity.transform.rotation = baseRotation * dragRotation
        rootEntity.transform.scale = SIMD3<Float>(repeating: baseScale * magnifyScale)
        updateNotes(for: version)
        
        let globalInverse = (baseRotation * dragRotation).inverse
        let tilt = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        let finalRot = globalInverse * tilt
        
        if let children = currentModelEntity?.children {
            for child in children {
                if child.name.hasPrefix("note_") {
                    child.transform.rotation = finalRot
                    

                }
            }
        }
        
        if let loc = queuedTapLocation {
            DispatchQueue.main.async {
                self.queuedTapLocation = nil
            }
            
            let hits = content.hitTest(point: loc, in: .local)
            if let firstHit = hits.first(where: { $0.entity.name == "ScannedModel" }) {
                // Push out by 15mm along the normal
                let hitPos = firstHit.position + firstHit.normal * 0.03
                let localPos = currentModelEntity?.convert(position: hitPos, from: nil)
                DispatchQueue.main.async {
                    self.tappedLocation = localPos
                    self.spatialNoteText = ""
                    self.editingNoteID = nil
                    self.showNoteInput = true
                }
            }
        }
    }

    private func deleteNote(_ note: SpatialNote, from version: ProjectVersion) {
        version.spatialNotes.removeAll(where: { $0.id == note.id })
        if activeNoteID == note.id { activeNoteID = nil }
        updateNotes(for: version)
    }

    private func addConvexCollisions(to entity: Entity) {
        if let modelEntity = entity as? ModelEntity, let mesh = modelEntity.model?.mesh {
            modelEntity.components.set(CollisionComponent(shapes: [ShapeResource.generateConvex(from: mesh)]))
            modelEntity.components.set(InputTargetComponent(allowedInputTypes: .all))
        }
        for child in entity.children {
            addConvexCollisions(to: child)
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
                addConvexCollisions(to: model)
                
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
                
                updateNotes(for: version)
            }
        }
    }
    
    private func updateNotes(for version: ProjectVersion) {
        guard let model = currentModelEntity else { return }
        
        let existingNoteIDs = Set(model.children.filter { $0.name.hasPrefix("note_") }.compactMap { UUID(uuidString: String($0.name.dropFirst(5))) })
        let currentNoteIDs = Set(version.spatialNotes.map { $0.id })
        
        for noteEntity in model.children where noteEntity.name.hasPrefix("note_") {
            if let noteID = UUID(uuidString: String(noteEntity.name.dropFirst(5))), !currentNoteIDs.contains(noteID) {
                noteEntity.removeFromParent()
            }
        }
        
        let invScale = 1.0 / model.scale.x
        let noteRadius: Float = 0.03 * invScale
        let thickness: Float = 0.001 * invScale
        
        for note in version.spatialNotes where !existingNoteIDs.contains(note.id) {
            let circle = ModelEntity(
                mesh: .generateCylinder(height: thickness, radius: noteRadius),
                materials: [SimpleMaterial(color: .lightGray, isMetallic: false)]
            )
            circle.name = "note_\(note.id)"
            circle.position = SIMD3<Float>(note.x, note.y, note.z)
            circle.components.set(InputTargetComponent(allowedInputTypes: .all))
            circle.generateCollisionShapes(recursive: false)
            
            let border = ModelEntity(
                mesh: .generateCylinder(height: thickness * 0.5, radius: noteRadius + (0.005 * invScale)),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            border.position = SIMD3<Float>(0, -thickness, 0)
            circle.addChild(border)
            
            let emoji = ModelEntity(
                mesh: .generateText("💬", extrusionDepth: 0.001, font: .systemFont(ofSize: CGFloat(noteRadius * 1.5))),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            let emojiBounds = emoji.visualBounds(relativeTo: nil)
            emoji.position = SIMD3<Float>(-emojiBounds.extents.x / 2, thickness, emojiBounds.extents.y / 2)
            let rot = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            emoji.transform.rotation = rot
            circle.addChild(emoji)
            

            model.addChild(circle)
        }
    }
    
    private func saveSpatialNote() {
        guard let version = currentVersion else { return }
        
        if let editingID = editingNoteID, let idx = version.spatialNotes.firstIndex(where: { $0.id == editingID }) {
            version.spatialNotes[idx].text = spatialNoteText
            if activeNoteID != nil { activeNoteID = editingID }
        } else if let location = tappedLocation, !spatialNoteText.isEmpty {
            let newNote = SpatialNote(text: spatialNoteText, x: location.x, y: location.y, z: location.z)
            version.spatialNotes.append(newNote)
        }
        
        spatialNoteText = ""
        tappedLocation = nil
        editingNoteID = nil
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


struct EditProjectView: View {
    @Bindable var project: KnitProject
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project Details")) {
                    TextField("Title", text: $project.title)
                    TextField("Yarn Brand", text: $project.yarnBrand)
                    TextField("Tool Size (e.g. US 8)", text: $project.toolSize)
                }
            }
            .navigationTitle("Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
