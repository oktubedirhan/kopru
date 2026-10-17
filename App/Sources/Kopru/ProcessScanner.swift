import Foundation

/// Hangi Windows programlarının bizim prefix'te çalıştığını bulur.
///
/// Wine süreçlerinin `ps` çıktısında yalnızca Windows yolu görünür (C:\...\steam.exe);
/// GameToMac'in Steam'i de aynı yolu gösterir. Ayırt etmek için `lsof -d txt` ile
/// sürecin belleğe yüklediği .exe dosyasının gerçek Mac yoluna bakıyoruz:
/// yol bizim prefix'in içindeyse süreç bizimdir.
enum ProcessScanner {
    struct Snapshot: Equatable, Sendable {
        var steamRunning = false
        var runningGameIDs: Set<String> = []
    }

    static func scan(paths: Paths, games: [InstalledGame]) -> Snapshot {
        // 1) Aday süreçler: komut satırında ".exe" geçenler.
        let pids = candidatePIDs(psOutput: run("/bin/ps", ["-axo", "pid=,command="]))
        guard !pids.isEmpty else { return Snapshot() }
        // 2) Bu süreçlerin yüklediği dosyalar. -F: makinece okunur çıktı (p<pid>, n<yol>).
        let lsof = run("/usr/sbin/lsof", ["-a", "-p", pids.joined(separator: ","), "-d", "txt", "-Fn"])
        return snapshot(exePaths: exePaths(lsofOutput: lsof), paths: paths, games: games)
    }

    // MARK: - Ayrıştırma (komut çalıştırmaz; testlerde kullanılır)

    /// "  1234 C:\...\steam.exe -arg" satırlarından .exe içerenlerin pid'leri.
    static func candidatePIDs(psOutput: String) -> [String] {
        psOutput.split(separator: "\n").compactMap { line in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count == 2, parts[1].localizedCaseInsensitiveContains(".exe") else { return nil }
            return String(parts[0])
        }
    }

    /// lsof -Fn çıktısındaki "n/…/x.exe" satırları, küçük harfe çevrilmiş.
    static func exePaths(lsofOutput: String) -> [String] {
        lsofOutput.split(separator: "\n")
            .filter { $0.hasPrefix("n") && $0.lowercased().hasSuffix(".exe") }
            .map { $0.dropFirst().lowercased() }
    }

    /// macOS dosya sistemi büyük/küçük harf duyarsız olduğu için karşılaştırma küçük harfle yapılır.
    static func snapshot(exePaths: [String], paths: Paths, games: [InstalledGame]) -> Snapshot {
        var snapshot = Snapshot()
        snapshot.steamRunning = exePaths.contains(paths.steamExe.standardizedFileURL.path.lowercased())
        for game in games where !game.installDir.isEmpty {
            let dir = game.installURL.standardizedFileURL.path.lowercased() + "/"
            if exePaths.contains(where: { $0.hasPrefix(dir) }) { snapshot.runningGameIDs.insert(game.appID) }
        }
        return snapshot
    }

    private static func run(_ tool: String, _ arguments: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
