import Foundation
import Testing
@testable import Kopru

@Suite("Save yedeği")
struct SaveBackupTests {
    @Test("Yedek alınır; değişmeyince yenisi alınmaz; değişince alınır; symlink izlenir")
    func createsAndSkips() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let real = fx.root.appending(path: "Documents/The Witcher 3")
        try fx.write("save1", to: real.appending(path: "gamesaves/a.sav"))
        // Prefix'teki Documents gibi: symlink üzerinden gelen klasör
        let link = fx.root.appending(path: "link-to-saves")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let backups = fx.root.appending(path: "backups")
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)

        let first = try SaveBackup.backup(source: link, appID: "1", backups: backups, now: t0)
        #expect(first.kind == .created)
        let copied = try #require(first.folder).appending(path: "The Witcher 3/gamesaves/a.sav")
        #expect(try String(contentsOf: copied, encoding: .utf8) == "save1")

        let second = try SaveBackup.backup(source: link, appID: "1", backups: backups, now: t0 + 60)
        #expect(second.kind == .unchanged)
        // URL == sondaki "/" farkını eşit saymaz (contentsOfDirectory klasörleri "/" ile verir); yolları karşılaştır.
        #expect(second.folder?.standardizedFileURL.path == first.folder?.standardizedFileURL.path)

        try fx.write("save2-daha-uzun", to: real.appending(path: "gamesaves/a.sav"))
        let third = try SaveBackup.backup(source: link, appID: "1", backups: backups, now: t0 + 120)
        #expect(third.kind == .created)
        #expect(SaveBackup.list(appID: "1", in: backups).count == 2)
        // Eski yedek bozulmadı (klon bağımsız kopya)
        #expect(try String(contentsOf: copied, encoding: .utf8) == "save1")
    }

    @Test("Save klasörü yoksa ya da boşsa yedek alınmaz")
    func noSaves() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let backups = fx.root.appending(path: "backups")
        #expect(try SaveBackup.backup(source: fx.root.appending(path: "yok"), appID: "1", backups: backups).kind == .noSaves)
        let empty = fx.root.appending(path: "bos")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(try SaveBackup.backup(source: empty, appID: "1", backups: backups).kind == .noSaves)
    }

    @Test("Yalnızca son N yedek tutulur, en yeniler kalır")
    func prunes() throws {
        let fx = try Fixture(); defer { fx.remove() }
        let src = fx.root.appending(path: "saves"), backups = fx.root.appending(path: "backups")
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        for i in 0..<5 {
            try fx.write("v\(i)" + String(repeating: "x", count: i), to: src.appending(path: "s.sav"))
            _ = try SaveBackup.backup(source: src, appID: "9", backups: backups, keep: 3, now: t0 + Double(i) * 60)
        }
        let kept = SaveBackup.list(appID: "9", in: backups)
        #expect(kept.count == 3)
        #expect(kept.first?.lastPathComponent == SaveBackup.stamp(t0 + 240))
    }
}
