import re

with open('Knittit/ProjectDetailView.swift', 'r') as f:
    content = f.read()

replacement = """                    Button(role: .destructive) {
                        if let version = currentVersion {
                            let versionId = version.id
                            project.versions.removeAll(where: { $0.id == versionId })
                            modelContext.delete(version)
                            
                            if currentVersionIndex >= project.versions.count {
                                currentVersionIndex = max(0, project.versions.count - 1)
                            }
                            
                            try? modelContext.save()
                        }
                    } label: {"""

content = re.sub(r'                    Button\(role: \.destructive\) \{.*?\} label: \{', replacement, content, flags=re.DOTALL)

with open('Knittit/ProjectDetailView.swift', 'w') as f:
    f.write(content)
