import Foundation
import Testing
@testable import Kopru

/// Depodaki dosyalara erişim (testler App/Tests/KopruTests içinde).
enum Repo {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func wineEnv() throws -> WineEnvFile {
        WineEnvFile(text: try String(contentsOf: root.appending(path: "config/wine.env"), encoding: .utf8))
    }
}

@Suite("config/wine.env")
struct WineEnvFileTests {
    let runtime = URL(fileURLWithPath: "/R")
    let gptk = URL(fileURLWithPath: "/G")
    let prefix = URL(fileURLWithPath: "/P x")

    @Test("Bölümler, ?=, yorumlar ve değerin içindeki = işareti")
    func parsing() {
        let file = WineEnvFile(text: """
        # yorum
        [all]
        A=1
        B?=x=y;z=
        PATHY=${RUNTIME}/lib:${PREFIX}

        [d3dmetal]
        D=${GPTK}/wine
        [all]
        E=son
        """)
        let on = file.environment(runtime: runtime, gptk: gptk, prefix: prefix, d3dmetal: true)
        #expect(on == ["A": "1", "B": "x=y;z=", "PATHY": "/R/lib:/P x", "D": "/G/wine", "E": "son"])
        let off = file.environment(runtime: runtime, gptk: gptk, prefix: prefix, d3dmetal: false)
        #expect(off["D"] == nil)
        #expect(off["E"] == "son")
    }

    @Test("Depodaki dosya beklenen anahtarları veriyor")
    func repoFile() throws {
        let env = try Repo.wineEnv().environment(runtime: runtime, gptk: gptk, prefix: prefix, d3dmetal: true)
        #expect(env["WINEPREFIX"] == "/P x")
        #expect(env["WINEMSYNC"] == "1")
        #expect(env["KOPRU_D3DMETAL_DLLPATH"] == "/G/wine")
        #expect(env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] == "/G/external/libd3dshared.dylib")
        #expect(env["DYLD_FALLBACK_LIBRARY_PATH"]?.hasPrefix("/R/lib/deps") == true)
        #expect(env.count == 9)
    }

    /// scripts/kwine'ın son satırı ("exec wine") "export -p" ile değiştirilip çalıştırılır;
    /// çıkan ortam, uygulamanın Wine.environment'ı ile karşılaştırılır. İkisi ayrılırsa bu test düşer.
    @Test("kwine ile uygulama aynı ortamı üretiyor", arguments: [true, false])
    func parityWithKwine(d3dmetal: Bool) throws {
        let temp = FileManager.default.temporaryDirectory.appending(path: "kwine-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.createDirectory(at: temp.appending(path: "scripts"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: temp.appending(path: "config"),
                                                   withDestinationURL: Repo.root.appending(path: "config"))
        let script = try String(contentsOf: Repo.root.appending(path: "scripts/kwine"), encoding: .utf8)
            .replacingOccurrences(of: #"exec "$WINE" "$@""#, with: "export -p")
        let kwine = temp.appending(path: "scripts/kwine")
        try script.write(to: kwine, atomically: true, encoding: .utf8)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = [kwine.path] + (d3dmetal ? [] : ["--no-d3dmetal"]) + ["steam", "x"]
        // Testi çalıştıran ortamdaki Wine değişkenleri sonucu etkilemesin.
        p.environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("WINE") }
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        #expect(p.terminationStatus == 0)

        // "export ANAHTAR='değer'" satırları → sözlük (yalnızca wine.env anahtarları)
        let file = try Repo.wineEnv()
        let keys = Set(file.entries.map(\.key))
        var fromKwine: [String: String] = [:]
        for line in out.split(separator: "\n") {
            let text = line.hasPrefix("export ") ? line.dropFirst(7) : line[...]
            guard let eq = text.firstIndex(of: "=") else { continue }
            let key = String(text[..<eq])
            guard keys.contains(key) else { continue }
            var value = String(text[text.index(after: eq)...])
            if value.hasPrefix("'"), value.hasSuffix("'") { value = String(value.dropFirst().dropLast()) }
            fromKwine[key] = value
        }

        let wine = Wine(paths: Paths(), prefixName: "steam", d3dmetal: d3dmetal, envFile: file)
        let fromApp = wine.environment.filter { keys.contains($0.key) }
        #expect(fromKwine == fromApp)
        #expect(fromApp.count == (d3dmetal ? 9 : 7))
    }
}
