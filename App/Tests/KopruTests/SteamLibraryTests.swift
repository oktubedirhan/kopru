import Foundation
import Testing
@testable import Kopru

@Suite("Steam kütüphanesi")
struct SteamLibraryTests {
    @Test("Windows yolu → Mac yolu (dosdevices bağlantısı üzerinden)")
    func windowsPaths() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let url = Paths.unixPath(forWindowsPath: #"C:\Program Files (x86)\Steam"#, inPrefix: fx.paths.steamPrefix)
        #expect(url?.standardizedFileURL.path == fx.paths.steamDir.resolvingSymlinksInPath().standardizedFileURL.path)
        #expect(Paths.unixPath(forWindowsPath: "göreli\\yol", inPrefix: fx.paths.steamPrefix) == nil)
    }

    @Test("Manifestler okunur, araçlar gizlenir, ada göre sıralanır, görseller bulunur")
    func loadsManifests() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let apps = fx.paths.steamApps
        try fx.write(fx.manifest(appID: "292030", name: "The Witcher 3", installDir: "The Witcher 3", flags: 6),
                     to: apps.appending(path: "appmanifest_292030.acf"))
        try fx.write(fx.manifest(appID: "228980", name: "Steamworks Common Redistributables", installDir: "Steamworks Shared"),
                     to: apps.appending(path: "appmanifest_228980.acf"))
        try fx.write(fx.manifest(appID: "10", name: "Counter-Strike", installDir: "Half-Life"),
                     to: apps.appending(path: "appmanifest_10.acf"))
        try fx.write("x", to: fx.paths.steamLibraryCache.appending(path: "292030/abc/library_hero.jpg"))

        let games = SteamLibrary.load(paths: fx.paths)
        #expect(games.map(\.appID) == ["10", "292030"])
        let witcher = try #require(games.last)
        #expect(witcher.needsUpdate)
        #expect(witcher.isFullyInstalled)
        #expect(witcher.heroImage?.lastPathComponent == "library_hero.jpg")
        #expect(witcher.capsuleImage == nil)
        #expect(witcher.installURL.path.hasSuffix("steamapps/common/The Witcher 3"))
    }

    @Test("Kurulu olmayan profiller listelenir: kurulular ve araçlar çıkar, ada göre sıralı, görsel varsa bulunur")
    func availableGames() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let installed = InstalledGame(appID: "292030", name: "The Witcher 3", installDir: "The Witcher 3",
                                      commonDir: fx.paths.steamCommon, sizeOnDisk: 0, stateFlags: 4,
                                      heroImage: nil, capsuleImage: nil, logoImage: nil)
        try fx.write("x", to: fx.paths.steamLibraryCache.appending(path: "730/abc/library_600x900.jpg"))
        let profiles: [String: GameProfile] = [
            "292030": GameProfile(name: "The Witcher 3"),
            "730": GameProfile(name: "Counter-Strike 2"),
            "1245620": GameProfile(name: "Elden Ring"),
            "228980": GameProfile(name: "Steamworks"),
            "1": GameProfile(),
        ]
        let list = SteamLibrary.available(profiles: profiles, installed: [installed],
                                          imageCache: fx.paths.steamLibraryCache)
        #expect(list.map(\.name) == ["App 1", "Counter-Strike 2", "Elden Ring"])
        #expect(list[1].capsuleImage?.lastPathComponent == "library_600x900.jpg")
        #expect(list[2].heroImage == nil)

        // Köprü'nün indirdiği görseller: Steam önbelleğindeki önce gelir; header.jpg yalnızca son çare.
        let downloaded = fx.root.appending(path: "images")
        try fx.write("x", to: downloaded.appending(path: "1245620/header.jpg"))
        try fx.write("x", to: downloaded.appending(path: "1245620/logo.png"))
        try fx.write("x", to: downloaded.appending(path: "730/library_600x900.jpg"))
        let merged = SteamLibrary.available(profiles: profiles, installed: [installed],
                                            imageCache: fx.paths.steamLibraryCache, downloaded: downloaded)
        #expect(merged[1].capsuleImage?.path.contains("librarycache") == true)
        #expect(merged[2].capsuleImage?.lastPathComponent == "header.jpg")
        #expect(merged[2].heroImage?.lastPathComponent == "header.jpg")
        #expect(merged[2].logoImage?.lastPathComponent == "logo.png")
    }

    @Test("appdetails yanıtından header_image okunur")
    func appDetailsHeader() {
        let json = #"{"4921760":{"success":true,"data":{"header_image":"https://example.com/h.jpg?t=1"}}}"#
        #expect(GameImages.headerImage(appDetails: Data(json.utf8), appID: "4921760")?.absoluteString
                == "https://example.com/h.jpg?t=1")
        #expect(GameImages.headerImage(appDetails: Data(#"{"1":{"success":false}}"#.utf8), appID: "1") == nil)
    }

    @Test("libraryfolders.vdf'teki ikinci kütüphane (başka sürücü) de okunur")
    func secondLibrary() throws {
        let fx = try Fixture(); defer { fx.remove() }
        // D: sürücüsü → geçici klasördeki "disk2"
        let disk2 = fx.root.appending(path: "disk2")
        try FileManager.default.createDirectory(at: disk2, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            atPath: fx.paths.steamPrefix.appending(path: "dosdevices/d:").path, withDestinationPath: disk2.path)
        try fx.write("""
        "libraryfolders"
        {
            "0" { "path" "C:\\\\Program Files (x86)\\\\Steam" }
            "1" { "path" "D:\\\\SteamLibrary" }
        }
        """, to: fx.paths.steamApps.appending(path: "libraryfolders.vdf"))
        try fx.write(fx.manifest(appID: "1245620", name: "ELDEN RING", installDir: "ELDEN RING"),
                     to: disk2.appending(path: "SteamLibrary/steamapps/appmanifest_1245620.acf"))

        let folders = SteamLibrary.libraryFolders(paths: fx.paths)
        #expect(folders.count == 2)  // C: kütüphanesi Steam'in kendi klasörüyle aynı; iki kez sayılmaz
        let games = SteamLibrary.load(paths: fx.paths)
        let elden = try #require(games.first { $0.appID == "1245620" })
        #expect(elden.installURL.resolvingSymlinksInPath().path
                == disk2.appending(path: "SteamLibrary/steamapps/common/ELDEN RING").resolvingSymlinksInPath().path)
    }
}
