import Foundation

/// Köprü'nün diskteki klasörleri. Hepsi ~/Library/Application Support/Kopru altında.
struct Paths: Sendable {
    let root: URL

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Kopru")) {
        self.root = root
    }

    /// Kendi derlediğimiz CrossOver 26.3 Wine'ı (scripts/build-crossover-wine.sh).
    var runtime: URL { root.appending(path: "runtime/crossover-26.3") }
    var wine: URL { runtime.appending(path: "bin/wine") }
    var wineserver: URL { runtime.appending(path: "bin/wineserver") }

    /// Kullanıcının Apple'dan indirdiği D3DMetal (Game Porting Toolkit 4.0 beta 3).
    var gptkLib: URL { root.appending(path: "gptk/4.0-beta3/redist/lib") }

    var logs: URL { root.appending(path: "logs") }

    func prefix(_ name: String) -> URL { root.appending(path: "prefixes/\(name)") }

    // Steam, "steam" prefix'inin C: sürücüsünde.
    static let steamPrefixName = "steam"
    var steamPrefix: URL { prefix(Self.steamPrefixName) }
    var steamDir: URL { steamPrefix.appending(path: "drive_c/Program Files (x86)/Steam") }
    var steamExe: URL { steamDir.appending(path: "steam.exe") }
    var steamApps: URL { steamDir.appending(path: "steamapps") }
    var steamCommon: URL { steamApps.appending(path: "common") }
    var steamLibraryCache: URL { steamDir.appending(path: "appcache/librarycache") }

    /// Steam'in Windows içindeki yolu (Wine'a verilen komut satırında kullanılır).
    static let steamExeWindows = #"C:\Program Files (x86)\Steam\steam.exe"#

    /// Windows yolunu Mac yoluna çevirir: "D:\Games" → <prefix>/dosdevices/d: bağlantısının hedefi + "/Games".
    /// Wine'da her sürücü harfi, prefix'teki dosdevices klasöründe bir symlink'tir (c: → ../drive_c, z: → /).
    static func unixPath(forWindowsPath path: String, inPrefix prefix: URL) -> URL? {
        let parts = path.split(separator: "\\", omittingEmptySubsequences: true)
        guard let drive = parts.first, drive.count == 2, drive.last == ":" else { return nil }
        var url = prefix.appending(path: "dosdevices/\(drive.lowercased())").resolvingSymlinksInPath()
        for part in parts.dropFirst() { url.append(path: String(part)) }
        return url
    }
}
