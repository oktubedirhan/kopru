import Foundation

/// Oyunlara uygulanan grafik ayarları. Ortam değişkeni olarak Steam'e verilir; oyun Steam'den
/// miras alır. Bu yüzden değişiklikler Steam yeniden başlatılınca geçerli olur.
struct LaunchSettings: Codable, Equatable, Sendable {
    /// Apple'ın Metal performans göstergesi (FPS, kare süresi, GPU belleği): MTL_HUD_ENABLED=1
    var metalHUD = false
    /// D3DMetal kare hızı sınırı: D3DM_MAX_FPS (GPTK Read Me). nil = sınırsız.
    var maxFPS: Int?

    static let fpsChoices = [30, 40, 60, 120]

    var environment: [String: String] {
        var env: [String: String] = [:]
        if metalHUD { env["MTL_HUD_ENABLED"] = "1" }
        if let maxFPS { env["D3DM_MAX_FPS"] = String(maxFPS) }
        return env
    }

    // UserDefaults'ta JSON olarak saklanır.
    private static let key = "launchSettings"

    static func load(from defaults: UserDefaults = .standard) -> LaunchSettings {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(LaunchSettings.self, from: data)
        else { return LaunchSettings() }
        return value
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
