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
    var backups: URL { root.appending(path: "backups") }
    /// Kullanıcının oyun profili ekleri (paketteki profiles.json'u alan alan ezer).
    var userProfiles: URL { root.appending(path: "profiles.json") }

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

    /// Prefix'teki Windows kullanıcı klasörü: drive_c/users altında Public dışındaki ilk klasör
    /// (CrossOver tabanlı Wine'da "crossover"). Windows yolu olarak döner: C:\users\<ad>
    static func windowsUserProfile(inPrefix prefix: URL) -> String? {
        let users = prefix.appending(path: "drive_c/users")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: users.path) else { return nil }
        return names.sorted().first { $0 != "Public" && !$0.hasPrefix(".") }.map { #"C:\users\"# + $0 }
    }

    /// Steam'in hesap klasörü: Steam\userdata\<hesap numarası>. Steam Cloud kullanan oyunların bir kısmı
    /// (ör. Batman AA) kaydını doğrudan burada <appid>\remote altına yazar. Birden fazla hesap varsa
    /// en son değişen seçilir; "0" (girişten önceki geçici klasör) atlanır. Windows yolu olarak döner.
    static func steamUserData(inPrefix prefix: URL) -> String? {
        let userdata = prefix.appending(path: "drive_c/Program Files (x86)/Steam/userdata")
        let items = (try? FileManager.default.contentsOfDirectory(
            at: userdata, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let accounts = items.filter { $0.lastPathComponent != "0" && UInt64($0.lastPathComponent) != nil }
        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        return accounts.max { modified($0) < modified($1) }
            .map { #"C:\Program Files (x86)\Steam\userdata\"# + $0.lastPathComponent }
    }

    /// %USERPROFILE% ya da %STEAMUSERDATA% içeren Windows yolunu Mac yoluna çevirir (save klasörleri için).
    static func resolve(windowsPath: String, inPrefix prefix: URL) -> URL? {
        var path = windowsPath
        if path.contains("%USERPROFILE%") {
            guard let profile = windowsUserProfile(inPrefix: prefix) else { return nil }
            path = path.replacingOccurrences(of: "%USERPROFILE%", with: profile)
        }
        if path.contains("%STEAMUSERDATA%") {
            guard let userdata = steamUserData(inPrefix: prefix) else { return nil }
            path = path.replacingOccurrences(of: "%STEAMUSERDATA%", with: userdata)
        }
        return unixPath(forWindowsPath: path, inPrefix: prefix)
    }

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
