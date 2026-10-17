import Foundation
import Testing
@testable import Kopru

@Suite("Başlatma ayarları")
struct LaunchSettingsTests {
    @Test("Varsayılan ayarlar ortam değişkeni eklemez")
    func defaults() {
        #expect(LaunchSettings().environment.isEmpty)
    }

    @Test("FPS göstergesi ve sınırı doğru değişkenlere çevrilir")
    func environment() {
        let s = LaunchSettings(metalHUD: true, maxFPS: 60)
        #expect(s.environment == ["MTL_HUD_ENABLED": "1", "D3DM_MAX_FPS": "60"])
    }

    @Test("Kaydedilip geri okunur")
    func roundTrip() throws {
        let suite = "kopru-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(LaunchSettings.load(from: defaults) == LaunchSettings())
        LaunchSettings(metalHUD: true, maxFPS: 40).save(to: defaults)
        #expect(LaunchSettings.load(from: defaults) == LaunchSettings(metalHUD: true, maxFPS: 40))
    }

    @Test("Wine ortamına eklenir; dışarıdan gelen MTL_/D3DM_ değişkenleri silinir")
    func wineEnvironment() {
        let wine = Wine(paths: Paths(root: URL(fileURLWithPath: "/tmp/kopru")), prefixName: "steam",
                        settings: LaunchSettings(metalHUD: false, maxFPS: 30), envFile: try! Repo.wineEnv())
        let env = wine.environment
        #expect(env["D3DM_MAX_FPS"] == "30")
        #expect(env["MTL_HUD_ENABLED"] == nil)
        #expect(env["WINEPREFIX"] == "/tmp/kopru/prefixes/steam")
        #expect(env["WINEMSYNC"] == "1")
    }
}
