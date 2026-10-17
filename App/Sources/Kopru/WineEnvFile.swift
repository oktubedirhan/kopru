import Foundation

/// config/wine.env okuyucusu: Wine ortam değişkenlerinin tek kaynağı (scripts/kwine de aynı dosyayı okur).
/// Biçim dosyanın başında açıklanıyor: "ANAHTAR=değer", "ANAHTAR?=değer", [all] / [d3dmetal] bölümleri,
/// ${RUNTIME} ${GPTK} ${PREFIX} yer tutucuları. Uygulama dışarıdan gelen değerleri kullanmadığı için
/// "?=" burada "=" ile aynıdır.
struct WineEnvFile: Sendable, Equatable {
    struct Entry: Sendable, Equatable {
        let key: String
        let value: String
        let d3dmetalOnly: Bool
    }

    let entries: [Entry]

    init(text: String) {
        var entries: [Entry] = []
        var section = "all"
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("["), line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast())
                continue
            }
            // İlk "?=" ya da "=" anahtarı ayırır; değerin içinde "=" olabilir (WINEDLLOVERRIDES).
            guard let eq = line.firstIndex(of: "=") else { continue }
            var key = String(line[..<eq])
            if key.hasSuffix("?") { key.removeLast() }
            entries.append(Entry(key: key, value: String(line[line.index(after: eq)...]),
                                 d3dmetalOnly: section == "d3dmetal"))
        }
        self.entries = entries
    }

    /// Uygulama paketindeki kopya (scripts/build-app.sh → Contents/Resources/wine.env).
    static func bundled() -> WineEnvFile? {
        guard let url = Bundle.main.url(forResource: "wine", withExtension: "env"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return WineEnvFile(text: text)
    }

    func environment(runtime: URL, gptk: URL, prefix: URL, d3dmetal: Bool) -> [String: String] {
        var env: [String: String] = [:]
        for entry in entries where d3dmetal || !entry.d3dmetalOnly {
            env[entry.key] = entry.value
                .replacingOccurrences(of: "${RUNTIME}", with: runtime.path)
                .replacingOccurrences(of: "${GPTK}", with: gptk.path)
                .replacingOccurrences(of: "${PREFIX}", with: prefix.path)
        }
        return env
    }
}
