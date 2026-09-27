# pdf/voice

Senkronize kelime vurgulama özelliğine sahip, sade ve yerel bir macOS PDF seslendirme uygulaması.

Ekran görüntüsü: docs/ss.png 

## Özellikler

- PDF dosyalarını açma ve sayfalardaki metni çıkarma
- Metni macOS sistem sesiyle seslendirme
- Okumayı duraklatma, sürdürme ve sayfalar arasında otomatik ilerleme
- Konuşma hızını ve ses tonunu ayarlama
- Ses ve görünüm ayarlarını saklama
- Son açılan belgeleri ve son okunan sayfayı hatırlama
- PDF dosyalarını sürükleyip bırakarak açma
- Apple Vision ile taranmış sayfalarda OCR çalıştırma
- Açık ve koyu görünüm desteği


## Çalıştırma

```bash
zsh scripts/build.sh
open "dist/PDF to Voice.app"
```

## Kullanılan Teknolojiler

Swift, SwiftUI, AppKit, PDFKit, AVFoundation ve Vision. Üçüncü taraf bağımlılık kullanılmaz.

## Bilinen Sınırlamalar

- OCR işlemi şu anda her sayfa için kullanıcı tarafından başlatılır.
- OCR ile çıkarılan metin kalıcı olarak saklanmaz.
- Uygulama PDF sayfasının görselini değil, çıkarılan metni gösterir.

## Onun için yapıldı.

## Lisans

MIT
