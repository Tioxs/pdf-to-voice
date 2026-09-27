import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var reader: ReaderModel
    @State private var showsVoiceSettings = false
    @State private var showsReadingSettings = false
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
                Button {
                    showsReadingSettings.toggle()
                } label: {
                    Label("Okuma Görünümü", systemImage: "textformat.size")
                }
                .popover(isPresented: $showsReadingSettings) {
                    readingSettings
                }
                .help("Yazı görünümünü ayarla")
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: reader.recognizeCurrentPage) {
                    Label(reader.isRunningOCR ? "Metin Tanınıyor" : "OCR", systemImage: "text.viewfinder")
                }
                .disabled(reader.isRunningOCR)
                .help("Taranmış sayfadaki metni tanı")
            }

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
        Group {
            if reader.pageText.isEmpty {
                VStack(spacing: 12) {
                    Text("Bu sayfada okunabilir metin bulunamadı.")
                        .foregroundStyle(.secondary)
                    Button("OCR ile Metni Tanı", action: reader.recognizeCurrentPage)
                        .disabled(reader.isRunningOCR)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(28)
            } else {
                SpokenTextView(
                    text: reader.pageText,
                    spokenRange: reader.spokenRange,
                    fontSize: reader.readingFontSize
                )
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
            .help(reader.isPaused ? "Devam et" : (reader.isSpeaking ? "Duraklat" : "Oynat"))

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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Okuma Hızı", systemImage: "speedometer")
                    Spacer()
                    Text(reader.speedLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $reader.speechRate, in: 0.35...0.60, step: 0.01) { editing in
                    if !editing { reader.applySpeechSettings() }
                }
                HStack {
                    Text("Yavaş")
                    Spacer()
                    Text("Hızlı")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Ses Tonu", systemImage: "waveform")
                    Spacer()
                    Text(String(format: "%.2f×", reader.pitch))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $reader.pitch, in: 0.75...1.25, step: 0.05) { editing in
                    if !editing { reader.applySpeechSettings() }
                }
                HStack {
                    Text("Kalın")
                    Spacer()
                    Text("İnce")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            HStack {
                Button("Varsayılana Dön") {
                    reader.speechRate = 0.48
                    reader.pitch = 1
                    reader.applySpeechSettings()
                }
                Spacer()
                Button("Önizle", action: reader.previewVoice)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 300)
    }

    private var readingSettings: some View {
        Form {
            HStack {
                Text("Yazı Boyutu")
                Slider(value: $reader.readingFontSize, in: 13...30, step: 1)
                Text("\(Int(reader.readingFontSize)) pt")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }

            Button("Varsayılana Dön") {
                reader.readingFontSize = 18
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 380, height: 140)
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
