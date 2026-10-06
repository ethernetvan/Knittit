import SwiftUI
import SwiftData
import QuickLookThumbnailing

struct LibraryGridView: View {
    @Query private var projects: [KnitProject]
    @Environment(\.modelContext) private var modelContext
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if projects.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No projects yet.")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Go to the Scan tab to save your first knit!")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(projects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectThumbnail(project: project)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(project)
                                } label: {
                                    Label("Delete Project", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("My Library")
        }
    }
}

struct ProjectThumbnail: View {
    let project: KnitProject
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                
                if let img = thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                } else {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(project.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(project.yarnBrand)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if !project.colorPalette.isEmpty {
                HStack(spacing: -5) {
                    ForEach(project.colorPalette.prefix(4), id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .task {
            if let mostRecent = project.versions.max(by: { $0.scanDate < $1.scanDate }) {
                thumbnailImage = await ThumbnailManager.shared.getThumbnail(for: mostRecent)
            }
        }
    }
}

// Helper for Hex to Color
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
