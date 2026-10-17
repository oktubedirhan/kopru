import Foundation

/// Kurulu olmayan oyunların görselleri. Steam yalnızca hesaptaki oyunların görsellerini önbelleğe alıyor;
/// diğerleri Steam'in herkese açık resim sunucusundan indirilip Köprü'nün klasöründe (images/<appid>/) saklanır.
/// Steam'in kendi önbelleğine yazılmaz.
enum GameImages {
    /// Steam kütüphanesinin kullandığı dosya adları (kapak, büyük görsel, logo).
    static let libraryFiles = ["library_600x900.jpg", "library_hero.jpg", "logo.png"]

    static func cdnURL(appID: String, file: String) -> URL {
        URL(string: "https://cdn.akamai.steamstatic.com/steam/apps/\(appID)/\(file)")!
    }

    /// Kütüphane görsellerini indirir. Çok yeni oyunlarda bu adresler yok (görseller özetli klasörlerde);
    /// o zaman mağaza bilgi servisindeki (appdetails) yatay başlık görseli header.jpg olarak kaydedilir.
    static func download(appID: String, to folder: URL) async {
        let dir = folder.appending(path: appID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var gotCapsule = false
        for file in libraryFiles {
            if await fetch(cdnURL(appID: appID, file: file), to: dir.appending(path: file)),
               file == "library_600x900.jpg" { gotCapsule = true }
        }
        guard !gotCapsule,
              let api = URL(string: "https://store.steampowered.com/api/appdetails?appids=\(appID)&filters=basic"),
              let (data, _) = try? await URLSession.shared.data(from: api),
              let header = headerImage(appDetails: data, appID: appID)
        else { return }
        _ = await fetch(header, to: dir.appending(path: "header.jpg"))
    }

    /// appdetails yanıtından header_image adresi.
    static func headerImage(appDetails data: Data, appID: String) -> URL? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let app = root[appID] as? [String: Any],
              let details = app["data"] as? [String: Any],
              let header = details["header_image"] as? String
        else { return nil }
        return URL(string: header)
    }

    /// Yalnızca 200 yanıtı ve resim içeriği kaydedilir (404 sayfası görsel diye yazılmasın).
    private static func fetch(_ url: URL, to destination: URL) async -> Bool {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType?.hasPrefix("image/") == true
        else { return false }
        return (try? data.write(to: destination, options: .atomic)) != nil
    }
}
