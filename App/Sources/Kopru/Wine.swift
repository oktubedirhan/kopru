import Foundation

/// Wine'ı Köprü ayarlarıyla başlatır. scripts/kwine'ın (cx runtime) Swift karşılığı;
/// ortam değişkenlerinin açıklamaları o betikte de var.
struct Wine: Sendable {
    let paths: Paths
    let prefixName: String
    var d3dmetal = true
    var settings = LaunchSettings()

    var prefix: URL { paths.prefix(prefixName) }

    var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        // Dışarıdan gelen Wine/D3DMetal/Metal ayarları karışmasın.
        for key in env.keys where ["WINE", "DYLD_", "CX_", "D3DM_", "MTL_", "KOPRU_"].contains(where: key.hasPrefix) {
            env[key] = nil
        }
        env["WINEPREFIX"] = prefix.path
        env["WINEDEBUG"] = "-all"
        // FreeType/GnuTLS (x86_64) runtime'ın yanındaki lib/deps'ten yüklenir.
        env["DYLD_FALLBACK_LIBRARY_PATH"] = paths.runtime.appending(path: "lib/deps").path + ":/usr/local/lib:/usr/lib"
        if d3dmetal {
            // tools/d3dmetal-hook bu klasörü DLL arama listesinin başına koyar (dxgi/d3d11/d3d12 → D3DMetal).
            env["KOPRU_D3DMETAL_DLLPATH"] = paths.gptkLib.appending(path: "wine").path
            // CrossOver ntdll'i D3DMetal'in macOS kütüphanesini erkenden yükler.
            env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = paths.gptkLib.appending(path: "external/libd3dshared.dylib").path
        }
        env["WINEDLLOVERRIDES"] = "mscoree,mshtml=;winemenubuilder.exe=;gameoverlayrenderer,gameoverlayrenderer64="
        // wineserver ile bütün süreçlerde aynı olmalı.
        env["WINEMSYNC"] = "1"
        env["ROSETTA_ADVERTISE_AVX"] = "1"
        // patches/crossover-26.3/0003: Steam arayüzü tek süreçte (yoksa pencere siyah).
        env["KOPRU_STEAMWEBHELPER_ARGS"] = "--single-process"
        env.merge(settings.environment) { $1 }
        return env
    }

    /// Bir Windows programını başlatır ve beklemez. Çıktı log dosyasına eklenir.
    @discardableResult
    func launch(_ arguments: [String], log name: String) throws -> Process {
        try start(paths.wine, arguments, log: name)
    }

    /// Prefix'teki bütün Windows süreçlerini zorla kapatır (wineserver -k).
    func killAll() throws {
        let p = try start(paths.wineserver, ["-k"], log: "wineserver")
        p.waitUntilExit()
    }

    private func start(_ executable: URL, _ arguments: [String], log name: String) throws -> Process {
        let p = Process()
        p.executableURL = executable
        p.arguments = arguments
        p.environment = environment
        p.currentDirectoryURL = prefix
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
