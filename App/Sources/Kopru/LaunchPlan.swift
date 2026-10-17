import Foundation

/// Bir oyunun nasıl başlatılacağı. Saf hesap: dosya sistemine ya da süreçlere dokunmaz (testlerde kullanılır).
struct LaunchPlan: Equatable, Sendable {
    let mode: GameProfile.LaunchMode
    /// wine'a verilecek argümanlar (ilki çalıştırılacak program)
    let arguments: [String]
    let workingDirectory: URL
    /// Wine'ın genel ortamına eklenecekler
    let extraEnvironment: [String: String]
    /// Bu çalıştırmada kullanılacak grafik ayarları
    let graphics: LaunchSettings

    /// Kullanıcı seçimi > profil varsayılanı > Steam. Exe yolu bilinmiyorsa doğrudan başlatma yapılamaz.
    static func mode(profile: GameProfile?, settings: GameSettings?) -> GameProfile.LaunchMode {
        let wanted = settings?.launchMode ?? profile?.launchMode ?? .steam
        return wanted == .direct && profile?.executable == nil ? .steam : wanted
    }

    static func make(game: InstalledGame, profile: GameProfile?, settings: GameSettings?,
                     global: LaunchSettings, steamRunning: Bool, paths: Paths) -> LaunchPlan {
        switch mode(profile: profile, settings: settings) {
        case .steam:
            var args = [Paths.steamExeWindows]
            // Steam kapalıysa aynı komutla hem Steam açılır hem oyun istenir.
            if !steamRunning { args.append("-cef-disable-gpu") }
            args += ["-applaunch", game.appID] + (profile?.steamArguments ?? [])
            // Oyun ortamı Steam'den miras alır: grafik ayarı yalnızca genel ayar olabilir.
            return LaunchPlan(mode: .steam, arguments: args, workingDirectory: paths.steamDir,
                              extraEnvironment: [:], graphics: global)

        case .direct:
            let exe = game.installURL.appending(path: profile?.executable ?? "")
            var env = profile?.environment ?? [:]
            // steam_api bu değişkenlerle hangi oyun olduğunu anlar ve açık Steam'e bağlanır.
            env["SteamAppId"] = game.appID
            env["SteamGameId"] = game.appID
            // Wine, Mac yolunu kendisi C:\…'ye çevirir (yama 0006'dan sonra sürücü dışı yollar da güvenli).
            return LaunchPlan(mode: .direct, arguments: [exe.path] + (profile?.arguments ?? []),
                              workingDirectory: exe.deletingLastPathComponent(),
                              extraEnvironment: env, graphics: settings?.graphics ?? global)
        }
    }
}
