import Foundation

/// Oyun kayıtlarının (save) tarihli yedekleri: backups/<appid>/<yyyy-MM-dd_HHmmss>/<save klasörü>
/// Oyna'dan önce alınır; klasör son yedekten beri değişmediyse yeni yedek alınmaz; son `keep` yedek tutulur.
/// FileManager.copyItem APFS'te dosyaları klonlar: anında biter, ek yer kaplamaz, ama bağımsız bir kopyadır.
enum SaveBackup {
    struct Result: Equatable, Sendable {
        enum Kind: Equatable, Sendable { case created, unchanged, noSaves }
        let kind: Kind
        let folder: URL?
    }

    static let fingerprintFile = ".kopru-fingerprint"

    static func directory(for appID: String, in backups: URL) -> URL {
        backups.appending(path: appID)
    }

    /// Bu oyunun yedekleri, yeniden eskiye.
    static func list(appID: String, in backups: URL) -> [URL] {
        let dir = directory(for: appID, in: backups)
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return items.filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func backup(source: URL, appID: String, backups: URL, keep: Int = 10, now: Date = .now) throws -> Result {
        let fm = FileManager.default
        // Save klasörü bir symlink üzerinden gelebilir (prefix'teki Documents → ~/Documents).
        let source = source.resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: source.path, isDirectory: &isDir), isDir.boolValue,
              let fingerprint = fingerprint(of: source), !fingerprint.isEmpty
        else { return Result(kind: .noSaves, folder: nil) }

        if let latest = list(appID: appID, in: backups).first,
           (try? String(contentsOf: latest.appending(path: fingerprintFile), encoding: .utf8)) == fingerprint {
            return Result(kind: .unchanged, folder: latest)
        }

        let folder = directory(for: appID, in: backups).appending(path: stamp(now))
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try fm.copyItem(at: source, to: folder.appending(path: source.lastPathComponent))
        try fingerprint.write(to: folder.appending(path: fingerprintFile), atomically: true, encoding: .utf8)

        for old in list(appID: appID, in: backups).dropFirst(keep) { try? fm.removeItem(at: old) }
        return Result(kind: .created, folder: folder)
    }

    /// Klasördeki dosyaların göreli yolu + boyutu + değişiklik zamanı (sıralı). İçerik okunmaz; hızlı.
    static func fingerprint(of folder: URL) -> String? {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys) else { return nil }
        let base = folder.standardizedFileURL.path
        var lines: [String] = []
        for case let url as URL in walker {
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            let rel = url.standardizedFileURL.path.replacingOccurrences(of: base, with: "")
            let mtime = v.contentModificationDate?.timeIntervalSince1970 ?? 0
            lines.append("\(rel)|\(v.fileSize ?? 0)|\(Int(mtime))")
        }
        return lines.sorted().joined(separator: "\n")
    }

    static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f.string(from: date)
    }
}
