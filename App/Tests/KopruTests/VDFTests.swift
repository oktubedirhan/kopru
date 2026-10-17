import Testing
@testable import Kopru

@Suite("VDF okuyucu")
struct VDFTests {
    @Test("İç içe nesneler ve düz değerler")
    func nested() {
        let v = VDF.parse("""
        "AppState"
        {
            "appid"     "292030"
            "InstalledDepots"
            {
                "292031" { "manifest" "8401480366474980007" }
            }
        }
        """)
        #expect(v["AppState"]?["appid"]?.string == "292030")
        #expect(v["AppState"]?["InstalledDepots"]?["292031"]?["manifest"]?.string == "8401480366474980007")
        #expect(v["AppState"]?["yok"] == nil)
    }

    @Test("Ters bölü kaçışları: Steam yollarda \\\\ yazar")
    func escapes() {
        let v = VDF.parse(#""path" "C:\\Program Files (x86)\\Steam""#)
        #expect(v["path"]?.string == #"C:\Program Files (x86)\Steam"#)
    }

    @Test("// yorum satırları atlanır")
    func comments() {
        let v = VDF.parse("""
        // başlık yorumu
        "a" "1"
        // arada yorum
        "b" "2"
        """)
        #expect(v["a"]?.string == "1")
        #expect(v["b"]?.string == "2")
    }

    @Test("Bozuk girişte çökmeden bulabildiğini döndürür")
    func malformed() {
        let v = VDF.parse(#""a" { "b" "1" "#)
        #expect(v["a"]?["b"]?.string == "1")
        #expect(VDF.parse("")["x"] == nil)
    }
}
