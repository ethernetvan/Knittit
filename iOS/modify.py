import re

with open('Knittit/ProjectDetailView.swift', 'r') as f:
    content = f.read()

# Add `@Environment(\.modelContext)` and `@State private var showEditProject = false`
new_props = """    let project: KnitProject
    @Environment(\.modelContext) private var modelContext
    @State private var showEditProject = false
"""
content = re.sub(r'    let project: KnitProject\n', new_props, content)

# Replace toolbar
old_toolbar = """        .toolbar {
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
        }"""
new_toolbar = """        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    NavigationLink(destination: ScanningView(project: project)) {
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
                            // modelContext.delete(version)
                            
                            if currentVersionIndex >= project.versions.count {
                                currentVersionIndex = max(0, project.versions.count - 1)
                            }
                            
                            // Let SwiftData know about changes?
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
        }"""

content = content.replace(old_toolbar, new_toolbar)

# Add EditProjectView at the end
edit_view = """

struct EditProjectView: View {
    @Bindable var project: KnitProject
    @Environment(\\.dismiss) private var dismiss
    
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
"""
content += edit_view

with open('Knittit/ProjectDetailView.swift', 'w') as f:
    f.write(content)
