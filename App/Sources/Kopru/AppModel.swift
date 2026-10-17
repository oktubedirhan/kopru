import AppKit
import Foundation
import Observation

/// Uygulamanın durumu ve eylemleri. Arayüz yalnızca bunu okur ve buradaki fonksiyonları çağırır.
@Observable @MainActor
final class AppModel {
    let paths = Paths()
    private(set) var games: [InstalledGame] = []
    var selection: InstalledGame.ID?
    private(set) var status = ProcessScanner.Snapshot()
    /// Başlatma komutu gönderilmiş ama süreci henüz görünmeyen oyunlar.
    private(set) var launching: [String: Date] = [:]
    private(set) var message: String?
    private(set) var setupProblem: String?
    private(set) var restartingSteam = false
    private var monitor: Task<Void, Never>?

    /// Genel grafik ayarları (Ayarlar penceresi). Steam üzerinden başlatılan oyunlara Steam'den geçer.
    var settings = LaunchSettings.load() {
        didSet { settings.save() }
    }
    /// Çalışan Steam'in hangi ayarlarla başlatıldığı. Steam bu uygulama dışında (ör. scripts/kwine)
    /// açıldıysa bilinmiyor; o durumda varsayılan ayarlarla açıldığını varsayıyoruz.
    private var steamSettings: LaunchSettings?

    /// Oyun profilleri: paketteki profiles.json + ~/…/Kopru/profiles.json
    private(set) var profiles: [String: GameProfile] = [:]
    /// Kullanıcının oyun başına seçimleri (başlatma yolu, oyuna özel grafik ayarı)
    private(set) var gameSettings = GameSettings.loadAll()

    /// Ayarlar değişti ama çalışan Steam (ve ondan başlatılan oyunlar) hâlâ eski ayarlarla mı?
    var needsSteamRestart: Bool {
        status.steamRunning && !restartingSteam && (steamSettings ?? LaunchSettings()) != settings
    }

    /// Wine ortam değişkenleri: paketteki config/wine.env kopyası.
    private let envFile = WineEnvFile.bundled()

    private func wine(graphics: LaunchSettings, extra: [String: String] = [:]) -> Wine {
        Wine(paths: paths, prefixName: Paths.steamPrefixName, settings: graphics,
             envFile: envFile ?? WineEnvFile(text: ""), extraEnvironment: extra)
    }

    var selectedGame: InstalledGame? { games.first { $0.id == selection } }

    func profile(for game: InstalledGame) -> GameProfile? { profiles[game.appID] }

    func settings(for game: InstalledGame) -> GameSettings { gameSettings[game.appID] ?? GameSettings() }

    func setSettings(_ value: GameSettings, for game: InstalledGame) {
        gameSettings[game.appID] = value == GameSettings() ? nil : value
        GameSettings.saveAll(gameSettings)
    }

    func launchMode(for game: InstalledGame) -> GameProfile.LaunchMode {
        LaunchPlan.mode(profile: profile(for: game), settings: gameSettings[game.appID])
    }

    func start() {
        reload()
        guard monitor == nil else { return }
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshStatus()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func reload() {
        let fm = FileManager.default
        let loaded = GameProfiles.load(bundled: Bundle.main.url(forResource: "profiles", withExtension: "json"),
                                       user: paths.userProfiles)
        profiles = loaded.profiles
        if envFile == nil {
            setupProblem = "Uygulama paketinde wine.env yok. Uygulamayı scripts/build-app.sh ile derle."
        } else if !fm.isExecutableFile(atPath: paths.wine.path) {
            setupProblem = "Wine bulunamadı: \(paths.wine.path)\nÖnce scripts/build-crossover-wine.sh all çalıştırılmalı."
        } else if !fm.fileExists(atPath: paths.steamExe.path) {
            setupProblem = "Steam kurulu değil: \(paths.steamExe.path)"
        } else {
            setupProblem = nil
        }
        if let problem = loaded.problem { message = problem }
        games = SteamLibrary.load(paths: paths)
        if selectedGame == nil { selection = games.first?.id }
    }

    func refreshStatus() async {
        let paths = paths, games = games
        let snapshot = await Task.detached { ProcessScanner.scan(paths: paths, games: games) }.value
        // Oyun görününce ya da 2 dakika geçince "başlatılıyor" durumunu bırak.
        for (id, date) in launching where snapshot.runningGameIDs.contains(id) || date.timeIntervalSinceNow < -120 {
            launching[id] = nil
        }
        if snapshot != status {
            // Oyun kapanınca Steam manifesti güncellemiş olabilir (boyut, güncelleme durumu).
            if !status.runningGameIDs.subtracting(snapshot.runningGameIDs).isEmpty { reload() }
            if !snapshot.steamRunning { steamSettings = nil }
            status = snapshot
        }
    }

    // MARK: - Eylemler

    func play(_ game: InstalledGame) {
        let profile = profile(for: game), choice = gameSettings[game.appID]
        launching[game.appID] = .now
        switch LaunchPlan.mode(profile: profile, settings: choice) {
        case .steam:
            let plan = LaunchPlan.make(game: game, profile: profile, settings: choice, global: settings,
                                       steamRunning: status.steamRunning, paths: paths)
            if !status.steamRunning { steamSettings = settings }
            run(plan, log: "steam", done: "\(game.name) Steam üzerinden başlatılıyor. Steam'de bir onay penceresi açılırsa onayla.")
        case .direct:
            Task { await playDirect(game, profile: profile, choice: choice) }
        }
    }

    /// Doğrudan başlatma: oyunun steam_api'si açık bir Steam'e bağlanmak ister; kapalıysa önce Steam açılır.
    private func playDirect(_ game: InstalledGame, profile: GameProfile?, choice: GameSettings?) async {
        if !status.steamRunning {
            openSteam()
            message = "\(game.name) için önce Steam açılıyor…"
            for _ in 0..<30 {  // en fazla ~90 sn
                try? await Task.sleep(for: .seconds(3))
                await refreshStatus()
                if status.steamRunning { break }
            }
            guard status.steamRunning else {
                launching[game.appID] = nil
                message = "Steam açılamadı; \(game.name) başlatılmadı."
                return
            }
            // Steam'in hesaba giriş yapmasına zaman tanı.
            try? await Task.sleep(for: .seconds(15))
        }
        let plan = LaunchPlan.make(game: game, profile: profile, settings: choice, global: settings,
                                   steamRunning: true, paths: paths)
        run(plan, log: "game-\(game.appID)",
            done: "\(game.name) doğrudan başlatılıyor (Steam'i atlayarak).")
    }

    func openSteam() {
        steamSettings = settings
        let plan = LaunchPlan(mode: .steam, arguments: [Paths.steamExeWindows, "-cef-disable-gpu"],
                              workingDirectory: paths.steamDir, extraEnvironment: [:], graphics: settings)
        run(plan, log: "steam", done: "Steam açılıyor…")
    }

    func closeSteam() {
        let plan = LaunchPlan(mode: .steam, arguments: [Paths.steamExeWindows, "-shutdown"],
                              workingDirectory: paths.steamDir, extraEnvironment: [:], graphics: settings)
        run(plan, log: "steam", done: "Steam'e kapanma komutu gönderildi.")
    }

    /// Ayarların oyuna geçmesi için: Steam'i kapat, tamamen kapanmasını bekle, yeni ayarlarla aç.
    func restartSteam() {
        guard !restartingSteam else { return }
        restartingSteam = true
        closeSteam()
        message = "Steam yeni ayarlarla yeniden başlatılıyor…"
        Task {
            defer { restartingSteam = false }
            for _ in 0..<40 {  // en fazla ~2 dakika
                try? await Task.sleep(for: .seconds(3))
                await refreshStatus()
                if !status.steamRunning { break }
            }
            guard !status.steamRunning else {
                message = "Steam kapanmadı. Bir oyun açıksa önce oyundan çık."
                return
            }
            openSteam()
        }
    }

    /// wineserver -k: Steam ve oyunlar dahil bu prefix'teki bütün Windows süreçleri kapanır.
    func forceQuit() {
        let wine = wine(graphics: settings)
        message = "Zorla kapatılıyor…"
        Task {
            do {
                try await Task.detached { try wine.killAll() }.value
                message = "Prefix'teki bütün Windows süreçleri kapatıldı."
                launching = [:]
            } catch {
                message = "Zorla kapatma başarısız: \(error.localizedDescription)"
            }
            await refreshStatus()
        }
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func showLogs() {
        try? FileManager.default.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        NSWorkspace.shared.open(paths.logs)
    }

    private func run(_ plan: LaunchPlan, log: String, done: String) {
        let wine = wine(graphics: plan.graphics, extra: plan.extraEnvironment)
        Task {
            do {
                try await Task.detached {
                    _ = try wine.launch(plan.arguments, log: log, workingDirectory: plan.workingDirectory)
                }.value
                message = done
            } catch {
                message = "Başlatılamadı: \(error.localizedDescription)"
            }
        }
    }
}
