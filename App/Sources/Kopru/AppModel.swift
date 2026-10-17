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

    /// Kullanıcının seçtiği grafik ayarları (Ayarlar penceresi).
    var settings = LaunchSettings.load() {
        didSet { settings.save() }
    }
    /// Çalışan Steam'in hangi ayarlarla başlatıldığı. Steam bu uygulama dışında (ör. scripts/kwine)
    /// açıldıysa bilinmiyor; o durumda varsayılan ayarlarla açıldığını varsayıyoruz.
    private var steamSettings: LaunchSettings?

    /// Ayarlar değişti ama çalışan Steam (ve oyun) hâlâ eski ayarlarla mı?
    var needsSteamRestart: Bool {
        status.steamRunning && !restartingSteam && (steamSettings ?? LaunchSettings()) != settings
    }

    private var steam: Wine { Wine(paths: paths, prefixName: Paths.steamPrefixName, settings: settings) }

    var selectedGame: InstalledGame? { games.first { $0.id == selection } }

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
        if !fm.isExecutableFile(atPath: paths.wine.path) {
            setupProblem = "Wine bulunamadı: \(paths.wine.path)\nÖnce scripts/build-crossover-wine.sh all çalıştırılmalı."
        } else if !fm.fileExists(atPath: paths.steamExe.path) {
            setupProblem = "Steam kurulu değil: \(paths.steamExe.path)"
        } else {
            setupProblem = nil
        }
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
        var args = [Paths.steamExeWindows]
        // Steam kapalıysa aynı komutla hem Steam açılır hem oyun istenir.
        if !status.steamRunning {
            args.append("-cef-disable-gpu")
            steamSettings = settings
        }
        args += ["-applaunch", game.appID] + (GameProfiles.extraArguments[game.appID] ?? [])
        launching[game.appID] = .now
        run(args, log: "steam", done: "\(game.name) başlatılıyor. Steam'de bir onay penceresi açılırsa onayla.")
    }

    func openSteam() {
        steamSettings = settings
        run([Paths.steamExeWindows, "-cef-disable-gpu"], log: "steam", done: "Steam açılıyor…")
    }

    func closeSteam() {
        run([Paths.steamExeWindows, "-shutdown"], log: "steam", done: "Steam'e kapanma komutu gönderildi.")
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
        let wine = steam
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

    private func run(_ arguments: [String], log: String, done: String) {
        let wine = steam
        Task {
            do {
                try await Task.detached { _ = try wine.launch(arguments, log: log) }.value
                message = done
            } catch {
                message = "Başlatılamadı: \(error.localizedDescription)"
            }
        }
    }
}
