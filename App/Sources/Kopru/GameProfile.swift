import Foundation

/// Oyuna özel bilgiler (profiles.json). Hepsi isteğe bağlı; bilinmeyen oyunlar profilsiz de çalışır.
struct GameProfile: Codable, Equatable, Sendable {
    enum LaunchMode: String, Codable, Sendable, CaseIterable {
        /// steam.exe -applaunch: Steam Cloud eşitlemesi ve ilk kurulumlar Steam'de. Ortamı Steam'den miras alır.
        case steam
        /// Oyun exe'si doğrudan (Steam açık kalır, SteamAppId ile bağlanır). Oyuna özel ortam mümkün.
        case direct
    }

    var name: String?
    /// Oyunun DirectX sürümü ("9", "11", "12"). D3DMetal yalnızca 10–12'yi çevirir; 9 Wine'ın wined3d'sine (OpenGL) düşer.
    var directX: String?
    /// -applaunch <appid> sonrasına eklenen argümanlar
    var steamArguments: [String]?
    /// Kurulum klasörüne göre exe yolu ("/" ile), doğrudan başlatma için
    var executable: String?
    /// Doğrudan başlatmada exe'ye verilen argümanlar
    var arguments: [String]?
    var launchMode: LaunchMode?
    /// Doğrudan başlatmada eklenen ortam değişkenleri
    var environment: [String: String]?
    /// Windows yolu; %USERPROFILE% kullanılabilir (C:\users\<ad>)
    var saveDirectory: String?
    var notes: String?

    /// Arayüzde gösterilen grafik yolu
    var rendererDescription: String {
        switch directX {
        case "9": "DirectX 9 → wined3d (OpenGL)"
        case let v?: "DirectX \(v) → D3DMetal 4 (Metal)"
        case nil: "D3DMetal 4 (DirectX 10–12) / wined3d (DirectX 9 ve öncesi)"
        }
    }

    /// Diğer profildeki dolu alanlar bu profildekilerin yerine geçer (kullanıcı dosyası paketteki varsayılanı ezer).
    func merged(with other: GameProfile) -> GameProfile {
        GameProfile(name: other.name ?? name,
                    directX: other.directX ?? directX,
                    steamArguments: other.steamArguments ?? steamArguments,
                    executable: other.executable ?? executable,
                    arguments: other.arguments ?? arguments,
                    launchMode: other.launchMode ?? launchMode,
                    environment: (environment ?? [:]).merging(other.environment ?? [:]) { $1 }.nilIfEmpty,
                    saveDirectory: other.saveDirectory ?? saveDirectory,
                    notes: other.notes ?? notes)
    }
}

/// Kullanıcının uygulamada bir oyun için seçtikleri (UserDefaults'ta saklanır).
struct GameSettings: Codable, Equatable, Sendable {
    var launchMode: GameProfile.LaunchMode?
    /// nil: genel ayarlar (⌘,) kullanılır. Yalnızca doğrudan başlatmada etkili.
    var graphics: LaunchSettings?

    private static let key = "gameSettings"

    static func loadAll(from defaults: UserDefaults = .standard) -> [String: GameSettings] {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode([String: GameSettings].self, from: data)
        else { return [:] }
        return value
    }

    static func saveAll(_ all: [String: GameSettings], to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(all), forKey: key)
    }
}

enum GameProfiles {
    private struct File: Codable { var games: [String: GameProfile] }

    static func parse(_ data: Data) throws -> [String: GameProfile] {
        try JSONDecoder().decode(File.self, from: data).games
    }

    /// Paketteki varsayılan profiller + kullanıcı dosyası (varsa, alan alan üstüne yazar).
    /// Bozuk kullanıcı dosyası yok sayılır ve hata metni döner.
    static func load(bundled: URL?, user: URL?) -> (profiles: [String: GameProfile], problem: String?) {
        var result: [String: GameProfile] = [:]
        if let bundled, let data = try? Data(contentsOf: bundled), let games = try? parse(data) {
            result = games
        }
        guard let user, FileManager.default.fileExists(atPath: user.path) else { return (result, nil) }
        do {
            for (id, profile) in try parse(Data(contentsOf: user)) {
                result[id] = (result[id] ?? GameProfile()).merged(with: profile)
            }
            return (result, nil)
        } catch {
            return (result, "\(user.lastPathComponent) okunamadı: \(error.localizedDescription)")
        }
    }
}

private extension Dictionary {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}
