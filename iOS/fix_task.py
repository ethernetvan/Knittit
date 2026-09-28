import re

with open('Knittit/LibraryGridView.swift', 'r') as f:
    content = f.read()

replacement = """        .task(id: project.versions.count) {
            if let mostRecent = project.versions.max(by: { $0.scanDate < $1.scanDate }) {
                thumbnailImage = await ThumbnailManager.shared.getThumbnail(for: mostRecent)
            } else {
                thumbnailImage = nil
            }
        }"""

content = re.sub(r'        \.task \{\n            if let mostRecent = project\.versions\.max[^}]+\}\n        \}', replacement, content)

with open('Knittit/LibraryGridView.swift', 'w') as f:
    f.write(content)

