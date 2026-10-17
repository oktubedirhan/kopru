import AppKit
import Foundation
import Observation

/// Uygulamanın durumu ve eylemleri. Arayüz yalnızca bunu okur ve buradaki fonksiyonları çağırır.
@Observable @MainActor
final class AppModel {
    let paths = Paths()
    private(set) var games: [InstalledGame] = []
    /// Profili olan ama kurulu olmayan oyunlar
    private(set) var available: [AvailableGame] = []
    /// Seçili oyunun AppID'si (kurulu ya da kurulu değil)
    var selection: String?
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
    /// Oyun başına en son save yedeği klasörü
    private(set) var lastBackups: [String: URL] = [:]

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
    var selectedAvailable: AvailableGame? { available.first { $0.id == selection } }

    func profile(for game: InstalledGame) -> GameProfile? { profiles[game.appID] }

    func settings(for game: InstalledGame) -> GameSettings { gameSettings[game.appID] ?? GameSettings() }

    func setSettings(_ value: GameSettings, for game: InstalledGame) {
        gameSettings[game.appID] = value == GameSettings() ? nil : value
        GameSettings.saveAll(gameSettings)
    }

    /// Profildeki save klasörünün Mac yolu (yoksa nil)
    func saveFolder(for game: InstalledGame) -> URL? {
        profile(for: game)?.saveDirectory.flatMap { Paths.resolve(windowsPath: $0, inPrefix: paths.steamPrefix) }
    }

    /// Save klasörünü yedekler (değişmediyse yeni yedek almaz). Sonucu kullanıcıya gösterilecek metin olarak döner.
    @discardableResult
    func backupSaves(_ game: InstalledGame) async -> String? {
        guard let source = saveFolder(for: game) else { return nil }
        let backups = paths.backups, appID = game.appID
        do {
            let result = try await Task.detached {
                try SaveBackup.backup(source: source, appID: appID, backups: backups)
            }.value
            if let folder = result.folder { lastBackups[appID] = folder }
            switch result.kind {
            case .created: return "Kayıtlar yedeklendi (\(result.folder?.lastPathComponent ?? ""))."
            case .unchanged: return "Kayıtlar son yedekten beri değişmemiş; yeni yedek gerekmedi."
            case .noSaves: return "Save klasöründe henüz kayıt yok."
            }
        } catch {
            return "Kayıt yedeği alınamadı: \(error.localizedDescription)"
        }
    }

    func backupNow(_ game: InstalledGame) {
        Task { message = await backupSaves(game) ?? "Bu oyunun save klasörü profilde tanımlı değil." }
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
        available = SteamLibrary.available(profiles: profiles, installed: games, imageCache: paths.steamLibraryCache)
        if selectedGame == nil && selectedAvailable == nil { selection = games.first?.id ?? available.first?.id }
        lastBackups = Dictionary(uniqueKeysWithValues: games.compactMap { game in
            SaveBackup.list(appID: game.appID, in: paths.backups).first.map { (game.appID, $0) }
        })
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
        Task {
            // Önce kayıtların yedeği (CLAUDE.md: save'e dokunabilecek her şeyden önce yedek).
            let backupNote = await backupSaves(game).map { " " + $0 } ?? ""
            switch LaunchPlan.mode(profile: profile, settings: choice) {
            case .steam:
                let plan = LaunchPlan.make(game: game, profile: profile, settings: choice, global: settings,
                                           steamRunning: status.steamRunning, paths: paths)
                if !status.steamRunning { steamSettings = settings }
                run(plan, log: "steam",
                    done: "\(game.name) Steam üzerinden başlatılıyor. Steam'de bir onay penceresi açılırsa onayla." + backupNote)
            case .direct:
                await playDirect(game, profile: profile, choice: choice, note: backupNote)
            }
        }
    }

    /// Doğrudan başlatma: oyunun steam_api'si açık bir Steam'e bağlanmak ister; kapalıysa önce Steam açılır.
    private func playDirect(_ game: InstalledGame, profile: GameProfile?, choice: GameSettings?, note: String) async {
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
            done: "\(game.name) doğrudan başlatılıyor (Steam'i atlayarak)." + note)
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

    /// Kurulu olmayan oyun için Steam'e bağlantı gönderir: steam://install (hesapta varsa kurulum penceresi)
    /// ya da steam://store (mağaza sayfası). Steam açıksa komut açık Steam'e geçer, kapalıysa Steam onunla açılır.
    func openInSteam(_ game: AvailableGame, install: Bool) {
        var args = [Paths.steamExeWindows]
        if !status.steamRunning {
            steamSettings = settings
            args.append("-cef-disable-gpu")
        }
        args.append("steam://\(install ? "install" : "store")/\(game.appID)")
        let plan = LaunchPlan(mode: .steam, arguments: args, workingDirectory: paths.steamDir,
                              extraEnvironment: [:], graphics: settings)
        run(plan, log: "steam", done: install
            ? "Steam'de \(game.name) kurulum penceresi açılıyor. Oyun hesabında yoksa Steam bunu söyler; o zaman Mağaza Sayfası'na bak."
            : "Steam'de \(game.name) mağaza sayfası açılıyor.")
        guard install else { return }
        // Kurulum başlayınca Steam appmanifest yazar; o zaman oyun "Kurulu" bölümüne geçsin (en fazla ~10 dk bekle).
        Task {
            let paths = paths
            for _ in 0..<120 {
                try? await Task.sleep(for: .seconds(5))
                let found = SteamLibrary.libraryFolders(paths: paths).contains {
                    FileManager.default.fileExists(atPath: $0.appending(path: "appmanifest_\(game.appID).acf").path)
                }
                if found { reload(); return }
            }
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
