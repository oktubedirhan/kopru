import Foundation
@testable import Kopru

/// Geçici klasörde sahte bir Köprü kökü: prefixes/steam/drive_c/…/Steam, dosdevices bağlantıları.
/// Testler gerçek Steam klasörüne dokunmaz.
struct Fixture {
    let root: URL
    let paths: Paths

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "kopru-test-\(UUID().uuidString)")
        paths = Paths(root: root)
        try FileManager.default.createDirectory(at: paths.steamApps, withIntermediateDirectories: true)
        let dos = paths.steamPrefix.appending(path: "dosdevices")
        try FileManager.default.createDirectory(at: dos, withIntermediateDirectories: true)
        // Wine'daki gibi göreli bağlantı: c: → ../drive_c
        try FileManager.default.createSymbolicLink(atPath: dos.appending(path: "c:").path, withDestinationPath: "../drive_c")
    }

    func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func manifest(appID: String, name: String, installDir: String, flags: Int = 4, size: Int64 = 1000) -> String {
        """
        "AppState"
        {
        \t"appid"\t\t"\(appID)"
        \t"name"\t\t"\(name)"
        \t"StateFlags"\t\t"\(flags)"
        \t"installdir"\t\t"\(installDir)"
        \t"SizeOnDisk"\t\t"\(size)"
        }
        """
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
