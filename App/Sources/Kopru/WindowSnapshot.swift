import AppKit

/// Hata ayıklama: uygulama kendi penceresini PNG olarak kaydeder.
/// Ekran kaydı izni gerekmez, çünkü yalnızca kendi çizdiğimiz görüntüyü okuyoruz.
/// Kullanım: open -n build/Köprü.app --args --snapshot /yol/pencere.png
@MainActor
enum WindowSnapshot {
    /// Komut satırında "--snapshot <yol>" varsa o yolu döndürür.
    static var requestedPath: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1])
    }

    /// Komut satırında "--select <appid>" varsa o oyun seçili açılır (görüntü almak için).
    static var requestedSelection: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--select"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func save(to url: URL) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              // contentView'un üstü pencerenin çerçevesi: başlık ve araç çubuğu da görüntüye girsin.
              let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
