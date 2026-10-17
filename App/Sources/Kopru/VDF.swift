import Foundation

/// Steam'in "VDF / KeyValues" metin biçimi için küçük bir okuyucu.
/// Biçim:  "anahtar" "değer"   ya da   "anahtar" { ...iç içe... }
/// appmanifest_*.acf ve libraryfolders.vdf dosyaları bu biçimde.
enum VDF {
    indirect enum Value: Sendable {
        case string(String)
        case object([String: Value])

        var string: String? { if case .string(let s) = self { s } else { nil } }
        subscript(key: String) -> Value? {
            if case .object(let o) = self { o[key] } else { nil }
        }
    }

    static func parse(_ text: String) -> Value {
        var tokens = tokenize(text)[...]
        return .object(parseObject(&tokens))
    }

    private enum Token { case string(String), open, close }

    private static func parseObject(_ tokens: inout ArraySlice<Token>) -> [String: Value] {
        var result: [String: Value] = [:]
        while let token = tokens.popFirst() {
            guard case .string(let key) = token else { return result } // "}" ya da bozuk giriş
            switch tokens.popFirst() {
            case .string(let value): result[key] = .string(value)
            case .open: result[key] = .object(parseObject(&tokens))
            case .close, nil: return result
            }
        }
        return result
    }

    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var it = text.makeIterator()
        while let c = it.next() {
            switch c {
            case "{": tokens.append(.open)
            case "}": tokens.append(.close)
            case "\"":
                var s = ""
                while let d = it.next(), d != "\"" {
                    // Steam yollarda ters bölüyü çift yazar: "C:\\Program Files"
                    if d == "\\", let e = it.next() { s.append(e) } else { s.append(d) }
                }
                tokens.append(.string(s))
            case "/":
                // "//" ile başlayan yorum satırını atla
                while let d = it.next(), d != "\n" {}
            default: continue // boşluklar
            }
        }
        return tokens
    }
}
