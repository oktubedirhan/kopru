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
