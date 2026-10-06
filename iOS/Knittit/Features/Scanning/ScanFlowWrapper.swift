import SwiftUI
import SwiftData

struct ScanFlowWrapper: View {
    @Binding var selectedTab: Int
    @State private var usdzURL: URL?
    @State private var colors: [String] = []
    @State private var isShowingSaveSheet = false
    
    var body: some View {
        NavigationStack {
            ScanningView { completedURL, extractedColors in
                self.usdzURL = completedURL
                self.colors = extractedColors
                self.isShowingSaveSheet = true
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isShowingSaveSheet, onDismiss: {
            // Reset state when sheet is dismissed/pulled down without saving
            self.usdzURL = nil
            self.colors = []
        }) {
            if let usdzURL = usdzURL {
                NavigationStack {
                    NewProjectFromScanView(usdzURL: usdzURL, colors: colors) { newProject in
                        // Reset state
                        self.isShowingSaveSheet = false
                        self.usdzURL = nil
                        self.colors = []
                        // Switch to library tab
                        selectedTab = 2
                    }
                }
            }
        }
    }
}

struct NewProjectFromScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let usdzURL: URL
    let colors: [String]
    let onSave: (KnitProject) -> Void
    
    @State private var title = ""
    @State private var yarnBrand = ""
    @State private var toolSize = ""
    
    var body: some View {
        Form {
            Section(header: Text("Project Details")) {
                TextField("Title", text: $title)
                TextField("Yarn Brand", text: $yarnBrand)
                TextField("Tool Size (e.g. US 8)", text: $toolSize)
            }
            
            if !colors.isEmpty {
                Section(header: Text("Detected Colors")) {
                    HStack {
                        ForEach(colors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .gray)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
            }
            
            Button("Save Project to Library") {
                saveProject()
            }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("New Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func saveProject() {
        let newProject = KnitProject(title: title, yarnBrand: yarnBrand, toolSize: toolSize)
        newProject.colorPalette = colors
        
        // Setup initial version
        let newVersion = ProjectVersion(
            scanDate: Date(),
            progressPercentage: 100,
            usdzFilePath: {
                let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fullPath = usdzURL.path
                if fullPath.hasPrefix(docDir.path) {
                    return String(fullPath.dropFirst(docDir.path.count + 1))
                }
                return usdzURL.lastPathComponent
            }()
        )
        
        newProject.versions.append(newVersion)
        modelContext.insert(newProject)
        
        try? modelContext.save()
        onSave(newProject)
    }
}
