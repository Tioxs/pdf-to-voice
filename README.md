# PDF to Voice

A minimal native macOS PDF-to-speech app with synchronized word highlighting.

<!-- Add a screenshot here: docs/screenshot.png -->

## Features

- Open PDFs and read the extracted page text
- Speak the current page with macOS system voices
- Highlight the currently spoken word using the real speech callback
- Pause, resume, change pages, and continue automatically across pages
- Choose a system voice and adjust speech speed and pitch
- Close the current PDF and return to the start screen
- Light and Dark Mode support

## Requirements

- macOS 13 or later
- Xcode 15 or later

## Run

1. Open `PDFToVoice.xcodeproj` in Xcode.
2. Select the `PDFToVoice` scheme and **My Mac**.
3. Press `⌘R`.

Without opening Xcode, an Apple Silicon build can also be created with:

```bash
zsh scripts/build.sh
open "dist/PDF to Voice.app"
```

## Tech Stack

Swift, SwiftUI, PDFKit, AVFoundation, and AVSpeechSynthesizer. No third-party dependencies.

## Known Limitations

- Scanned PDFs require OCR and are not supported yet.
- The app focuses on listening and extracted text; it does not display the PDF page itself.

## License

MIT
