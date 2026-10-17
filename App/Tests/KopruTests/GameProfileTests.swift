import Foundation
import Testing
@testable import Kopru

@Suite("Oyun profilleri ve başlatma planı")
struct GameProfileTests {
    func game(_ fx: Fixture, id: String = "292030", dir: String = "The Witcher 3") -> InstalledGame {
        InstalledGame(appID: id, name: "Oyun", installDir: dir, commonDir: fx.paths.steamCommon,
                      sizeOnDisk: 0, stateFlags: 4, heroImage: nil, capsuleImage: nil, logoImage: nil)
    }

    @Test("Depodaki profiles.json geçerli; Witcher 3 ve Batman profilleri var")
    func repoFile() throws {
        let profiles = try GameProfiles.parse(Data(contentsOf: Repo.root.appending(path: "App/Resources/profiles.json")))
        #expect(profiles["292030"]?.steamArguments == ["--launcher-skip"])
        #expect(profiles["292030"]?.executable == "bin/x64_dx12/witcher3.exe")
        #expect(profiles["208650"]?.executable == "Binaries/Win64/BatmanAK.exe")
        #expect(profiles["35140"]?.directX == "9")
        // Asylum'un exe'si başlatıcısız açılmıyor: doğrudan başlatmada da BmLauncher çalışmalı.
        #expect(profiles["35140"]?.executable == "Binaries/BmLauncher.exe")
        #expect(profiles["35140"]?.saveDirectory?.hasSuffix("Batman Arkham Asylum GOTY\\SaveData") == true)
    }

    @Test("Grafik yolu açıklaması DirectX sürümüne göre")
    func renderer() {
        #expect(GameProfile(directX: "9").rendererDescription.contains("wined3d"))
        #expect(GameProfile(directX: "11").rendererDescription.contains("D3DMetal"))
        #expect(GameProfile().rendererDescription.contains("D3DMetal"))
    }

    @Test("Kullanıcı dosyası alan alan ezer, ortam değişkenleri birleşir; bozuk dosya raporlanır")
    func userOverrides() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let bundled = fx.root.appending(path: "bundled.json"), user = fx.root.appending(path: "user.json")
        try fx.write(#"{"games":{"1":{"name":"A","executable":"a.exe","environment":{"X":"1"}}}}"#, to: bundled)
        try fx.write(#"{"games":{"1":{"launchMode":"direct","environment":{"Y":"2"}},"2":{"name":"B"}}}"#, to: user)
        let loaded = GameProfiles.load(bundled: bundled, user: user)
        #expect(loaded.problem == nil)
        #expect(loaded.profiles["1"] == GameProfile(name: "A", executable: "a.exe", launchMode: .direct,
                                                    environment: ["X": "1", "Y": "2"]))
        #expect(loaded.profiles["2"]?.name == "B")

        try fx.write("{bozuk", to: user)
        let broken = GameProfiles.load(bundled: bundled, user: user)
        #expect(broken.problem != nil)
        #expect(broken.profiles["1"]?.name == "A")  // paketteki varsayılan yine kullanılır
    }

    @Test("%USERPROFILE% prefix'teki kullanıcı klasörüne çözülür")
    func userProfilePath() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let users = fx.paths.steamPrefix.appending(path: "drive_c/users")
        for name in ["Public", "crossover"] {
            try FileManager.default.createDirectory(at: users.appending(path: name), withIntermediateDirectories: true)
        }
        #expect(Paths.windowsUserProfile(inPrefix: fx.paths.steamPrefix) == #"C:\users\crossover"#)
        let url = Paths.resolve(windowsPath: #"%USERPROFILE%\Documents\The Witcher 3"#, inPrefix: fx.paths.steamPrefix)
        #expect(url?.resolvingSymlinksInPath().path
                == users.appending(path: "crossover/Documents/The Witcher 3").resolvingSymlinksInPath().path)
    }

    @Test("Başlatma yolu: kullanıcı seçimi > profil > Steam; exe yolu yoksa doğrudan olmaz")
    func modeResolution() {
        let withExe = GameProfile(executable: "a.exe", launchMode: .direct)
        #expect(LaunchPlan.mode(profile: nil, settings: nil) == .steam)
        #expect(LaunchPlan.mode(profile: withExe, settings: nil) == .direct)
        #expect(LaunchPlan.mode(profile: withExe, settings: GameSettings(launchMode: .steam)) == .steam)
        #expect(LaunchPlan.mode(profile: GameProfile(), settings: GameSettings(launchMode: .direct)) == .steam)
    }

    @Test("Steam yolu: -applaunch + profil argümanları, Steam kapalıysa -cef-disable-gpu, genel grafik ayarı")
    func steamPlan() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let global = LaunchSettings(metalHUD: true, maxFPS: nil)
        let profile = GameProfile(steamArguments: ["--launcher-skip"])
        let closed = LaunchPlan.make(game: game(fx), profile: profile,
                                     settings: GameSettings(graphics: LaunchSettings(maxFPS: 30)),
                                     global: global, steamRunning: false, paths: fx.paths)
        #expect(closed.arguments == [Paths.steamExeWindows, "-cef-disable-gpu", "-applaunch", "292030", "--launcher-skip"])
        #expect(closed.graphics == global)  // oyuna özel ayar Steam yolunda uygulanamaz
        #expect(closed.extraEnvironment.isEmpty)
        #expect(closed.workingDirectory == fx.paths.steamDir)
        let open = LaunchPlan.make(game: game(fx), profile: profile, settings: nil, global: global,
                                   steamRunning: true, paths: fx.paths)
        #expect(!open.arguments.contains("-cef-disable-gpu"))
    }

    @Test("Doğrudan yol: exe Mac yolu, exe klasöründe çalışır, SteamAppId + profil ortamı, oyuna özel grafik")
    func directPlan() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let profile = GameProfile(executable: "Binaries/Win64/BatmanAK.exe", arguments: ["-nostartupmovies"],
                                  environment: ["FOO": "1"])
        let own = LaunchSettings(metalHUD: true, maxFPS: 60)
        let plan = LaunchPlan.make(game: game(fx, id: "208650", dir: "Batman Arkham Knight"), profile: profile,
                                   settings: GameSettings(launchMode: .direct, graphics: own),
                                   global: LaunchSettings(), steamRunning: true, paths: fx.paths)
        let exe = fx.paths.steamCommon.appending(path: "Batman Arkham Knight/Binaries/Win64/BatmanAK.exe")
        #expect(plan.mode == .direct)
        #expect(plan.arguments == [exe.path, "-nostartupmovies"])
        #expect(plan.workingDirectory.path == exe.deletingLastPathComponent().path)
        #expect(plan.extraEnvironment == ["FOO": "1", "SteamAppId": "208650", "SteamGameId": "208650"])
        #expect(plan.graphics == own)

        // Oyuna özel ayar yoksa genel ayar
        let fallback = LaunchPlan.make(game: game(fx), profile: profile, settings: GameSettings(launchMode: .direct),
                                       global: LaunchSettings(maxFPS: 40), steamRunning: true, paths: fx.paths)
        #expect(fallback.graphics.maxFPS == 40)
    }

    @Test("Wine: çalıştırmaya özel ortam en son eklenir, oyuna özel grafik ayarını taşır")
    func wineExtraEnvironment() throws {
        let wine = Wine(paths: Paths(root: URL(fileURLWithPath: "/tmp/kopru")), prefixName: "steam",
                        settings: LaunchSettings(metalHUD: true, maxFPS: 60), envFile: try Repo.wineEnv(),
                        extraEnvironment: ["SteamAppId": "208650"])
        let env = wine.environment
        #expect(env["SteamAppId"] == "208650")
        #expect(env["MTL_HUD_ENABLED"] == "1")
        #expect(env["D3DM_MAX_FPS"] == "60")
    }
}
