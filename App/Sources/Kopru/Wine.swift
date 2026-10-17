import Foundation

/// Wine'ı Köprü ayarlarıyla başlatır. Ortam değişkenleri config/wine.env'den gelir
/// (scripts/kwine ile ortak); açıklamaları o dosyada.
struct Wine: Sendable {
    let paths: Paths
    let prefixName: String
    var d3dmetal = true
    var settings = LaunchSettings()
    let envFile: WineEnvFile

    var prefix: URL { paths.prefix(prefixName) }

    /// Bu çalıştırmaya özel ek ortam (ör. doğrudan başlatmada SteamAppId, profil değişkenleri).
    var extraEnvironment: [String: String] = [:]

    var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        // Dışarıdan gelen Wine/D3DMetal/Metal ayarları karışmasın.
        for key in env.keys where ["WINE", "DYLD_", "CX_", "D3DM_", "MTL_", "KOPRU_", "ROSETTA_"].contains(where: key.hasPrefix) {
            env[key] = nil
        }
        env.merge(envFile.environment(runtime: paths.runtime, gptk: paths.gptkLib,
                                      prefix: prefix, d3dmetal: d3dmetal)) { $1 }
        env.merge(settings.environment) { $1 }
        env.merge(extraEnvironment) { $1 }
        return env
    }

    /// Bir Windows programını başlatır ve beklemez. Çıktı log dosyasına eklenir.
    /// workingDirectory bir sürücünün altında olmalı (z: yok); verilmezse C:\ kullanılır.
    @discardableResult
    func launch(_ arguments: [String], log name: String, workingDirectory: URL? = nil) throws -> Process {
        try start(paths.wine, arguments, log: name, workingDirectory: workingDirectory)
    }

    /// Prefix'teki bütün Windows süreçlerini zorla kapatır (wineserver -k).
    func killAll() throws {
        let p = try start(paths.wineserver, ["-k"], log: "wineserver", workingDirectory: nil)
        p.waitUntilExit()
    }

    private func start(_ executable: URL, _ arguments: [String], log name: String,
                       workingDirectory: URL?) throws -> Process {
        let p = Process()
        p.executableURL = executable
        p.arguments = arguments
        p.environment = environment
        // Wine, Mac'teki çalışma klasörünü Windows klasörüne çevirir; prefix klasörünün kendisi
        // hiçbir sürücünün altında değil, bu yüzden varsayılan C:\ (drive_c).
        let cwd = workingDirectory ?? prefix.appending(path: "drive_c")
        p.currentDirectoryURL = cwd
        // Wine önce PWD'ye bakar (get_initial_directory); çalışma klasörüyle aynı olsun.
        p.environment?["PWD"] = cwd.path
        let log = try logHandle(name)
        p.standardOutput = log
        p.standardError = log
        p.standardInput = FileHandle.nullDevice
        try p.run()
        return p
    }

    /// logs/<ad>-<tarih>.log dosyasını sonuna eklemek üzere açar.
    private func logHandle(_ name: String) throws -> FileHandle {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        let date = Date.now.formatted(.iso8601.year().month().day())
        let url = paths.logs.appending(path: "\(name)-\(date).log")
        if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        handle.write(Data("\n=== \(Date.now.formatted(date: .omitted, time: .standard)) Köprü: \(name)\n".utf8))
        return handle
    }
}
