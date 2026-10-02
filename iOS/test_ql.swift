import SwiftUI
import QuickLook

struct TestView: View {
    @State private var url: URL? = nil
    var body: some View {
        Text("hello").quickLookPreview($url)
    }
}
