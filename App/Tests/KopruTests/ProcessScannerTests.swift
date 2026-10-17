import Foundation
import Testing
@testable import Kopru

@Suite("Süreç tanıma")
struct ProcessScannerTests {
    // Gerçek `ps -axo pid=,command=` çıktısına benzer örnek (2026-10-17'de görülen biçim)
    let ps = """
      530 /Applications/Köprü.app/Contents/MacOS/Kopru
    86653 C:\\Program Files (x86)\\Steam\\steam.exe -cef-disable-gpu
    86662 /Users/u/Library/Application Support/Kopru/runtime/crossover-26.3/bin/wineserver
    88568 C:\\Program Files (x86)\\Steam\\steamapps\\common\\The Witcher 3\\bin\\x64_dx12\\witcher3.exe
    """

    @Test("Yalnızca .exe içeren satırların pid'leri alınır")
    func candidates() {
        #expect(ProcessScanner.candidatePIDs(psOutput: ps) == ["86653", "88568"])
    }

    @Test("lsof -Fn çıktısından yalnızca .exe yolları, küçük harfle")
    func lsofParsing() {
        let lsof = """
        p86653
        n/Users/u/Library/Application Support/Kopru/prefixes/steam/drive_c/Program Files (x86)/Steam/steam.exe
        n/usr/lib/dyld
        p88568
        n/Users/u/X/The Witcher 3/bin/x64_dx12/Witcher3.EXE
        """
        #expect(ProcessScanner.exePaths(lsofOutput: lsof) == [
            "/users/u/library/application support/kopru/prefixes/steam/drive_c/program files (x86)/steam/steam.exe",
            "/users/u/x/the witcher 3/bin/x64_dx12/witcher3.exe",
        ])
    }

    @Test("Bizim prefix'teki Steam ve oyun tanınır; başka prefix'teki (GameToMac) tanınmaz")
    func ownPrefixOnly() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let game = InstalledGame(appID: "292030", name: "The Witcher 3", installDir: "The Witcher 3",
                                 commonDir: fx.paths.steamCommon, sizeOnDisk: 0, stateFlags: 4,
                                 heroImage: nil, capsuleImage: nil, logoImage: nil)
        let ours = fx.paths.steamExe.path.lowercased()
        let ourGame = game.installURL.appending(path: "bin/x64_dx12/witcher3.exe").path.lowercased()
        let other = "/users/u/library/application support/game library/games/witcher3/prefix/drive_c/program files (x86)/steam/steam.exe"

        let running = ProcessScanner.snapshot(exePaths: [ours, ourGame], paths: fx.paths, games: [game])
        #expect(running.steamRunning)
        #expect(running.runningGameIDs == ["292030"])

        let foreign = ProcessScanner.snapshot(exePaths: [other], paths: fx.paths, games: [game])
        #expect(!foreign.steamRunning)
        #expect(foreign.runningGameIDs.isEmpty)
    }

    @Test("Adı ötekinin öneki olan oyun klasörleri karışmaz")
    func prefixCollision() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let short = InstalledGame(appID: "1", name: "Game", installDir: "Game", commonDir: fx.paths.steamCommon,
                                  sizeOnDisk: 0, stateFlags: 4, heroImage: nil, capsuleImage: nil, logoImage: nil)
        let exe = fx.paths.steamCommon.appending(path: "Game 2/game.exe").path.lowercased()
        #expect(ProcessScanner.snapshot(exePaths: [exe], paths: fx.paths, games: [short]).runningGameIDs.isEmpty)
    }
}
