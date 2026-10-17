import Foundation

/// Steam prefix'inde kurulu bir oyun (appmanifest_<appid>.acf dosyasından).
struct InstalledGame: Identifiable, Hashable, Sendable {
    let appID: String
    let name: String
    let installDir: String
    /// Oyunun bulunduğu kütüphanenin steamapps/common klasörü (Mac yolu).
    let commonDir: URL
    let sizeOnDisk: Int64
    let stateFlags: Int
    let heroImage: URL?
    let capsuleImage: URL?
    let logoImage: URL?

    var id: String { appID }
    var installURL: URL { commonDir.appending(path: installDir) }
    /// Steam'in StateFlags bit alanı: 4 = tam kurulu, 2 = güncelleme gerekiyor.
    var isFullyInstalled: Bool { stateFlags & 4 != 0 }
    var needsUpdate: Bool { stateFlags & 2 != 0 }
}

enum SteamLibrary {
    /// Oyun olmayan Steam araçları (listede gösterilmez).
    static let hiddenAppIDs: Set<String> = [
        "228980",  // Steamworks Common Redistributables (VC++ / DirectX yükleyicileri)
    ]

    /// Steam'in kütüphane klasörleri (her biri bir steamapps klasörü). libraryfolders.vdf'te Windows
    /// yolu olarak yazılı; okunamazsa yalnızca Steam'in kendi klasörü.
    static func libraryFolders(paths: Paths) -> [URL] {
        var result = [paths.steamApps]
        let file = paths.steamApps.appending(path: "libraryfolders.vdf")
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              case .object(let folders)? = VDF.parse(text)["libraryfolders"]
        else { return result }
        for key in folders.keys.sorted(by: { (Int($0) ?? 0) < (Int($1) ?? 0) }) {
            guard let windowsPath = folders[key]?["path"]?.string,
                  let url = Paths.unixPath(forWindowsPath: windowsPath, inPrefix: paths.steamPrefix)?
                      .appending(path: "steamapps").standardizedFileURL,
                  !result.contains(where: { $0.standardizedFileURL.path == url.path })
            else { continue }
            result.append(url)
        }
        return result
    }

    static func load(paths: Paths) -> [InstalledGame] {
        libraryFolders(paths: paths)
            .flatMap { load(steamApps: $0, imageCache: paths.steamLibraryCache) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Bir steamapps klasöründeki appmanifest_*.acf dosyaları.
    static func load(steamApps: URL, imageCache: URL) -> [InstalledGame] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: steamApps, includingPropertiesForKeys: nil)
        else { return [] }

        return files
            .filter { $0.lastPathComponent.hasPrefix("appmanifest_") && $0.pathExtension == "acf" }
            .compactMap { url -> InstalledGame? in
                guard let text = try? String(contentsOf: url, encoding: .utf8),
                      let state = VDF.parse(text)["AppState"],
                      let appID = state["appid"]?.string,
                      !hiddenAppIDs.contains(appID)
                else { return nil }
                let images = findImages(appID: appID, in: imageCache)
                return InstalledGame(
                    appID: appID,
                    name: state["name"]?.string ?? "App \(appID)",
                    installDir: state["installdir"]?.string ?? "",
                    commonDir: steamApps.appending(path: "common"),
                    sizeOnDisk: Int64(state["SizeOnDisk"]?.string ?? "") ?? 0,
                    stateFlags: Int(state["StateFlags"]?.string ?? "") ?? 0,
                    heroImage: images["library_hero.jpg"],
                    capsuleImage: images["library_capsule.jpg"] ?? images["library_600x900.jpg"],
                    logoImage: images["logo.png"]
                )
            }
    }

    /// Steam görselleri librarycache/<appid>/<özet>/library_hero.jpg gibi yollarda duruyor.
    private static func findImages(appID: String, in cache: URL) -> [String: URL] {
        var found: [String: URL] = [:]
        let dir = cache.appending(path: appID)
        guard let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return found }
        for case let url as URL in walker where found[url.lastPathComponent] == nil {
            found[url.lastPathComponent] = url
        }
        return found
    }
}
