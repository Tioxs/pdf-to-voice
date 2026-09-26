import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var reader: ReaderModel
    @State private var isImporterPresented = false

    var body: some View {
        Group {
            if reader.document == nil {
                emptyState
            } else {
                ReaderView(openPDF: { isImporterPresented = true })
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .alert("PDF Açılamadı", isPresented: errorBinding) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(reader.errorMessage ?? "Bilinmeyen hata")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)

            Text("PDF Ses")
                .font(.largeTitle.weight(.semibold))

            Text("Bir PDF seç ve metni dinlemeye başla.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("PDF Seç") {
                isImporterPresented = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)
        }
        .padding(40)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { reader.errorMessage != nil },
            set: { if !$0 { reader.errorMessage = nil } }
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let URLs):
            guard let URL = URLs.first else { return }
            reader.open(URL)
        case .failure(let error):
            reader.errorMessage = error.localizedDescription
        }
    }
}
