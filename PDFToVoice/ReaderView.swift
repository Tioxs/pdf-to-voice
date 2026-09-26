import AVFoundation
import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var reader: ReaderModel
    @State private var showsVoiceSettings = false
    @State private var pageInput = "1"
    let openPDF: () -> Void

    var body: some View {
        readingPanel
        .safeAreaInset(edge: .bottom, spacing: 0) {
            playbackBar
        }
        .navigationTitle(reader.fileName)
        .onReceive(reader.$currentPageIndex) { newPage in
            pageInput = String(newPage + 1)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openPDF) {
                    Label("PDF Aç", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive, action: reader.closeDocument) {
                    Label("PDF'ten Çık", systemImage: "xmark")
                }
            }
        }
    }

    private var readingPanel: some View {
        ScrollView {
            if reader.pageText.isEmpty {
                Text("Bu sayfada okunabilir metin bulunamadı.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(28)
            } else {
                Text(reader.attributedPageText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
        .background(.background)
    }

    private var playbackBar: some View {
        HStack(spacing: 18) {
            Button(action: reader.previousPage) {
                Image(systemName: "backward.end.fill")
            }
            .disabled(!reader.canGoBackward)

            Button(action: reader.togglePlayback) {
                Image(systemName: reader.isSpeaking ? "pause.fill" : "play.fill")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .keyboardShortcut(.space, modifiers: [])
            .help(reader.isPaused ? "Resume" : (reader.isSpeaking ? "Pause" : "Play"))

            Button(action: reader.nextPage) {
                Image(systemName: "forward.end.fill")
            }
            .disabled(!reader.canGoForward)

            Divider()
                .frame(height: 22)

            Button {
                showsVoiceSettings.toggle()
            } label: {
                Image(systemName: "speaker.wave.2")
            }
            .popover(isPresented: $showsVoiceSettings) {
                voiceSettings
            }
            .help("Ses, hız ve ton")

            Spacer()

            TextField("Sayfa", text: $pageInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 62)
                .multilineTextAlignment(.trailing)
                .onSubmit(goToPage)

            Button("Git", action: goToPage)
                .disabled(targetPage == nil)

            Text("Sayfa \(reader.currentPageIndex + 1) / \(reader.pageCount)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var voiceSettings: some View {
        Form {
            Picker("Ses", selection: voiceBinding) {
                Text("Sistem Varsayılanı").tag("")
                ForEach(reader.availableVoices, id: \.identifier) { voice in
                    Text("\(voice.name) (\(voice.language))")
                        .tag(voice.identifier)
                }
            }

            HStack {
                Text("Hız")
                Slider(value: $reader.speechRate, in: 0.35...0.60)
                Text(reader.speedLabel)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Text("Ton")
                Slider(value: $reader.pitch, in: 0.80...1.20)
                Text(String(format: "%.1f×", reader.pitch))
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 220)
    }

    private var voiceBinding: Binding<String> {
        Binding(
            get: { reader.voiceIdentifier ?? "" },
            set: { reader.voiceIdentifier = $0.isEmpty ? nil : $0 }
        )
    }

    private var targetPage: Int? {
        guard reader.pageCount > 0,
              let page = Int(pageInput),
              page >= 1,
              page <= reader.pageCount else { return nil }
        return page
    }

    private func goToPage() {
        guard let targetPage else { return }
        reader.goToPage(targetPage)
    }
}
