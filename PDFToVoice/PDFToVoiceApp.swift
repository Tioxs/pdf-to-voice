import SwiftUI

@main
struct PDFToVoiceApp: App {
    @StateObject private var reader = ReaderModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(reader)
                .frame(minWidth: 820, minHeight: 620)
        }
        .windowStyle(.titleBar)
    }
}
