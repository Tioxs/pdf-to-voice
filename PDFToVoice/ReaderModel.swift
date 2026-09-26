import AVFoundation
import PDFKit
import SwiftUI

final class ReaderModel: NSObject, ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var fileName = ""
    @Published private(set) var currentPageIndex = 0
    @Published private(set) var pageText = ""
    @Published private(set) var spokenRange: NSRange?
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    @Published var voiceIdentifier: String?
    @Published var speechRate: Float = 0.48
    @Published var pitch: Float = 1.0
    @Published var errorMessage: String?

    private let synthesizer = AVSpeechSynthesizer()
    private var securityScopedURL: URL?
    private var shouldAdvance = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    var pageCount: Int { document?.pageCount ?? 0 }
    var canGoBackward: Bool { currentPageIndex > 0 }
    var canGoForward: Bool { currentPageIndex + 1 < pageCount }

    var speedLabel: String {
        String(format: "%.1f×", 0.7 + Double((speechRate - 0.35) / 0.25) * 0.9)
    }

    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().sorted {
            $0.language == $1.language
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.language < $1.language
        }
    }

    var attributedPageText: AttributedString {
        var attributed = AttributedString(pageText)
        attributed.font = .body.italic()

        if let spokenRange,
           let stringRange = Range(spokenRange, in: pageText),
           let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
           let upper = AttributedString.Index(stringRange.upperBound, within: attributed) {
            attributed[lower..<upper].font = .body.bold().italic()
        }
        return attributed
    }

    func open(_ URL: URL) {
        let hasAccess = URL.startAccessingSecurityScopedResource()

        guard let PDF = PDFDocument(url: URL), PDF.pageCount > 0 else {
            if hasAccess { URL.stopAccessingSecurityScopedResource() }
            errorMessage = "Dosya boş, bozuk veya parola korumalı olabilir."
            return
        }

        stop()
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = hasAccess ? URL : nil
        document = PDF
        fileName = URL.deletingPathExtension().lastPathComponent
        currentPageIndex = 0
        loadCurrentPageText()
    }

    func selectPage(_ index: Int) {
        guard index != currentPageIndex, (0..<pageCount).contains(index) else { return }
        stop()
        currentPageIndex = index
        loadCurrentPageText()
    }

    func closeDocument() {
        stop()
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        document = nil
        fileName = ""
        currentPageIndex = 0
        pageText = ""
    }

    func previousPage() {
        guard canGoBackward else { return }
        selectPage(currentPageIndex - 1)
    }

    func nextPage() {
        guard canGoForward else { return }
        selectPage(currentPageIndex + 1)
    }

    func goToPage(_ pageNumber: Int) {
        selectPage(pageNumber - 1)
    }

    func togglePlayback() {
        if isPaused {
            synthesizer.continueSpeaking()
        } else if isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        } else {
            speakCurrentPage()
        }
    }

    func stop() {
        shouldAdvance = false
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        spokenRange = nil
    }

    private func loadCurrentPageText() {
        pageText = document?.page(at: currentPageIndex)?.string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        spokenRange = nil
    }

    private func speakCurrentPage() {
        guard !pageText.isEmpty else {
            advanceToNextReadablePage()
            return
        }

        let utterance = AVSpeechUtterance(string: pageText)
        utterance.rate = speechRate
        utterance.pitchMultiplier = pitch
        if let voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        }
        shouldAdvance = true
        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
    }

    private func advanceToNextReadablePage() {
        guard shouldAdvance || !isSpeaking else { return }
        var nextIndex = currentPageIndex + 1
        while nextIndex < pageCount {
            currentPageIndex = nextIndex
            loadCurrentPageText()
            if !pageText.isEmpty {
                speakCurrentPage()
                return
            }
            nextIndex += 1
        }
        stop()
    }
}

extension ReaderModel: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        spokenRange = characterRange
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard shouldAdvance else { return }
        isSpeaking = false
        spokenRange = nil
        advanceToNextReadablePage()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isSpeaking = true
        isPaused = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = false
        spokenRange = nil
    }
}
