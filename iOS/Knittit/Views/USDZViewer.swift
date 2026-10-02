import SwiftUI
import RealityKit
#if targetEnvironment(simulator)
import SceneKit
#endif

@available(iOS 17.0, *)
struct USDZViewer: View {
    let url: URL
    let title: String
    
    @State private var modelEntity: ModelEntity?
#if targetEnvironment(simulator)
    @State private var scene: SCNScene?
#endif
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Downloading 3D Model...")
            } else if let error = loadError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.largeTitle)
                    Text("Error Loading Model")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                #if os(iOS) && !targetEnvironment(simulator)
                if let entity = modelEntity {
                    RealityView { content in
                        let root = Entity()
                        root.addChild(entity)
                        content.add(root)
                        
                        let bounds = entity.visualBounds(relativeTo: nil)
                        let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                        if maxExtent > 0 {
                            let scale = 0.2 / maxExtent
                            entity.scale = SIMD3<Float>(repeating: scale)
                        }
                        entity.position = [0, 0, 0]
                    }
                    .gesture(
                        DragGesture().onChanged { value in
                            let delta = Float(value.translation.width)
                            entity.transform.rotation *= simd_quatf(angle: delta * 0.005, axis: [0, 1, 0])
                        }
                    )
                }
                #else
                if let scene = scene {
                    SceneView(scene: scene, options: [.allowsCameraControl, .autoenablesDefaultLighting])
                } else {
                    VStack {
                        Text("3D Preview could not be loaded on Simulator.")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                #endif
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await downloadAndLoadModel()
        }
    }
    
    private func downloadAndLoadModel() async {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let localURL = tempDir.appendingPathComponent(url.lastPathComponent)
            
            if !FileManager.default.fileExists(atPath: localURL.path) {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: localURL)
            }
            
            #if targetEnvironment(simulator)
            let loadedScene = try? SCNScene(url: localURL, options: nil)
            await MainActor.run {
                self.scene = loadedScene
                self.isLoading = false
            }
            #else
            let entity = try await ModelEntity(contentsOf: localURL)
            await MainActor.run {
                self.modelEntity = entity
                self.isLoading = false
            }
            #endif
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
        }
    }
}
