import AVFoundation
import PDFKit
import SwiftUI
@preconcurrency import Vision

@MainActor
final class ReaderModel: NSObject, ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var fileName = ""
    @Published private(set) var currentPageIndex = 0
    @Published private(set) var pageText = ""
    @Published private(set) var spokenRange: NSRange?
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    @Published private(set) var isLoading = false
    @Published private(set) var isRunningOCR = false
    @Published private(set) var recentDocuments: [RecentDocument] = []
    @Published var errorMessage: String?
    @Published var voiceIdentifier: String? { didSet { defaults.set(voiceIdentifier, forKey: Keys.voice) } }
    @Published var speechRate: Float { didSet { defaults.set(speechRate, forKey: Keys.rate) } }
    @Published var pitch: Float { didSet { defaults.set(pitch, forKey: Keys.pitch) } }
    @Published var readingFontSize: Double { didSet { defaults.set(readingFontSize, forKey: Keys.fontSize) } }

    struct RecentDocument: Identifiable, Codable, Hashable {
        let bookmark: Data
        let name: String
        let lastPage: Int
        var id: Data { bookmark }
    }

    private enum Keys {
        static let voice = "reader.voice"
        static let rate = "reader.rate"
        static let pitch = "reader.pitch"
        static let recent = "reader.recent"
        static let fontSize = "reader.fontSize"
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let defaults: UserDefaults
    private var securityScopedURL: URL?
    private var shouldAdvance = false
    private var utteranceOffset = 0
    private var loadTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        voiceIdentifier = defaults.string(forKey: Keys.voice)
        speechRate = defaults.object(forKey: Keys.rate) as? Float ?? 0.48
        pitch = defaults.object(forKey: Keys.pitch) as? Float ?? 1
        readingFontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 18
        super.init()
        synthesizer.delegate = self
        if let data = defaults.data(forKey: Keys.recent),
           let items = try? JSONDecoder().decode([RecentDocument].self, from: data) {
            recentDocuments = items
        }
    }

    deinit {
        loadTask?.cancel()
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    var pageCount: Int { document?.pageCount ?? 0 }
    var canGoBackward: Bool { currentPageIndex > 0 }
    var canGoForward: Bool { currentPageIndex + 1 < pageCount }
    var speedLabel: String {
        let multiplier: Double
        if speechRate <= 0.48 {
            multiplier = 0.5 + Double((speechRate - 0.35) / 0.13) * 0.5
        } else {
            multiplier = 1 + Double((speechRate - 0.48) / 0.12)
        }
        return String(format: "%.1f×", multiplier)
    }
    var spokenLocation: Int? { spokenRange?.location }

    var availableVoices: [AVSpeechSynthesisVoice] {
        let preferred = Locale.current.language.languageCode?.identifier ?? "tr"
        return AVSpeechSynthesisVoice.speechVoices().sorted {
            let a = $0.language.hasPrefix(preferred), b = $1.language.hasPrefix(preferred)
            if a != b { return a }
            return $0.language == $1.language
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.language < $1.language
        }
    }

    var attributedPageText: AttributedString {
        var value = AttributedString(pageText)
        value.font = .system(size: readingFontSize)
        if let spokenRange, let range = Range(spokenRange, in: pageText),
           let lower = AttributedString.Index(range.lowerBound, within: value),
           let upper = AttributedString.Index(range.upperBound, within: value) {
            value[lower..<upper].font = .system(size: readingFontSize, weight: .bold)
            value[lower..<upper].backgroundColor = .accentColor.opacity(0.3)
        }
        return value
    }

    func open(_ url: URL, page: Int? = nil) {
        loadTask?.cancel()
        stop()
        isLoading = true
        let hasAccess = url.startAccessingSecurityScopedResource()
        loadTask = Task { [weak self] in
            let pdf = await Task.detached(priority: .userInitiated) { PDFDocument(url: url) }.value
            guard let self, !Task.isCancelled else {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
                return
            }
            isLoading = false
            guard let pdf, pdf.pageCount > 0 else {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
                errorMessage = "Dosya boş, bozuk veya parola korumalı olabilir."
                return
            }
            securityScopedURL?.stopAccessingSecurityScopedResource()
            securityScopedURL = hasAccess ? url : nil
            document = pdf
            fileName = url.deletingPathExtension().lastPathComponent
            let saved = recentDocuments.first { $0.name == self.fileName }?.lastPage ?? 0
            currentPageIndex = min(max(page ?? saved, 0), pdf.pageCount - 1)
            loadCurrentPageText()
            remember(url)
        }
    }

    func openRecent(_ item: RecentDocument) {
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: item.bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            open(url, page: item.lastPage)
        } catch { errorMessage = "Son kullanılan PDF açılamadı: \(error.localizedDescription)" }
    }

    func clearRecentDocuments() {
        recentDocuments.removeAll()
        defaults.removeObject(forKey: Keys.recent)
    }

    func selectPage(_ index: Int) {
        guard index != currentPageIndex, (0..<pageCount).contains(index) else { return }
        stop(); currentPageIndex = index; loadCurrentPageText(); updateRecentPage()
    }
    func closeDocument() {
        loadTask?.cancel(); stop(); securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil; document = nil; fileName = ""; currentPageIndex = 0; pageText = ""
    }
    func previousPage() { if canGoBackward { selectPage(currentPageIndex - 1) } }
    func nextPage() { if canGoForward { selectPage(currentPageIndex + 1) } }
    func goToPage(_ pageNumber: Int) { selectPage(pageNumber - 1) }
    func togglePlayback() {
        if isPaused { synthesizer.continueSpeaking() }
        else if isSpeaking { synthesizer.pauseSpeaking(at: .word) }
        else { speakCurrentPage() }
    }
    func stop() {
        shouldAdvance = false; synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false; isPaused = false; spokenRange = nil
    }
    func previewVoice() {
        stop()
        synthesizer.speak(makeUtterance("Merhaba, seçtiğiniz ses böyle duyuluyor."))
    }

    func applySpeechSettings() {
        guard isSpeaking else { return }
        let offset = spokenRange?.location ?? utteranceOffset
        shouldAdvance = false
        synthesizer.stopSpeaking(at: .immediate)
        speakCurrentPage(from: offset)
    }

    func recognizeCurrentPage() {
        guard let page = document?.page(at: currentPageIndex), !isRunningOCR else { return }
        stop(); isRunningOCR = true
        let image = page.thumbnail(of: CGSize(width: 2400, height: 3200), for: .mediaBox)
        Task {
            let text = await Self.recognize(image: image)
            isRunningOCR = false
            if text.isEmpty { errorMessage = "Bu sayfada OCR ile metin bulunamadı." }
            else { pageText = text }
        }
    }

    private func loadCurrentPageText() {
        pageText = document?.page(at: currentPageIndex)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        spokenRange = nil
    }
    private func makeUtterance(_ text: String) -> AVSpeechUtterance {
        let value = AVSpeechUtterance(string: text); value.rate = speechRate; value.pitchMultiplier = pitch
        if let voiceIdentifier { value.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) }
        return value
    }
    private func speakCurrentPage(from offset: Int = 0) {
        guard !pageText.isEmpty else { advanceToNextReadablePage(); return }
        let text = pageText as NSString
        let safeOffset = min(max(offset, 0), text.length)
        guard safeOffset < text.length else { advanceToNextReadablePage(); return }
        utteranceOffset = safeOffset
        shouldAdvance = true; isSpeaking = true; isPaused = false
        synthesizer.speak(makeUtterance(text.substring(from: safeOffset)))
    }
    private func advanceToNextReadablePage() {
        var index = currentPageIndex + 1
        while index < pageCount {
            currentPageIndex = index; loadCurrentPageText(); updateRecentPage()
            if !pageText.isEmpty { speakCurrentPage(); return }
            index += 1
        }
        stop()
    }
    private func remember(_ url: URL) {
        guard let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        recentDocuments.removeAll { $0.name == fileName }
        recentDocuments.insert(.init(bookmark: data, name: fileName, lastPage: currentPageIndex), at: 0)
        recentDocuments = Array(recentDocuments.prefix(5)); saveRecent()
    }
    private func updateRecentPage() {
        guard let index = recentDocuments.firstIndex(where: { $0.name == fileName }) else { return }
        let old = recentDocuments[index]
        recentDocuments[index] = .init(bookmark: old.bookmark, name: old.name, lastPage: currentPageIndex)
        saveRecent()
    }
    private func saveRecent() { defaults.set(try? JSONEncoder().encode(recentDocuments), forKey: Keys.recent) }

    nonisolated private static func recognize(image: NSImage) async -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let rows = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: rows.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: cgImage).perform([request]) }
                catch { continuation.resume(returning: "") }
            }
        }
    }
}

extension ReaderModel: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.spokenRange = NSRange(location: range.location + self.utteranceOffset, length: range.length)
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.shouldAdvance else { return }
            self.isSpeaking = false; self.spokenRange = nil; self.advanceToNextReadablePage()
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false; self.isPaused = true }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true; self.isPaused = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false; self.isPaused = false; self.spokenRange = nil }
    }
}
