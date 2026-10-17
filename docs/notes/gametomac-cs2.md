# GameToMac CS2'yi nasıl çalıştırıyor (inceleme notu, 2026-10-18)

Kaynak: `/Applications/GameToMac.app/Contents/Resources/Sources/` (CS2.md, Core.swift, CS2Graphics.swift,
CS2Display.swift, CS2-VALIDATION.json) ve `Resources/CS2/`. Yalnızca okundu; kod kopyalanmadı.
"Gözlem" = dosyada yazılı; "çıkarım" = benim yorumum.

## Online / VAC
- **Gözlem:** Kaynakların hiçbirinde VAC, `-insecure`, anti-cheat kelimesi yok. Oyun sıradan Steam yoluyla açılıyor:
  `steam.exe -cef-disable-gpu -applaunch 730` (+ gerekirse `-windowed -noborder -w <gen> -h <yük>`).
- **Çıkarım:** Online için özel bir şey yapılmıyor. VAC çekirdek sürücüsü değil, kullanıcı modunda çalışan Steam/oyun
  kodu; Wine'ın taklit ettiği Windows arayüzleriyle çalışabiliyor ve Valve Wine/Proton'u engellemiyor.
  Çekirdek seviyesi anti-cheat'ler (EA Javelin, Riot Vanguard, Ricochet) bu yolla çalışmaz.
- **Gözlem:** Kendi doğrulama dosyalarında "online maçların doğrulanması" ve "kullanıcı maç onayı" **hâlâ bekleyen**
  maddeler; bilinen bir kapanışta çökme var.
- **Çıkarım (risk):** VAC, oyun dosyalarına müdahaleyi ve oyuna enjekte edilen DLL'leri izler. DXMT/D3DMetal oyunun
  klasörüne değil Wine'ın sistem DLL'lerine (d3d11/dxgi) giriyor; Linux'ta DXVK ile aynı yaklaşım. Risk düşük ama sıfır değil.

## Asıl iş: grafik
- **Gözlem:** CS2 için D3DMetal yerine **DXMT** kullanılıyor (DirectX 11 → Metal, açık kaynak, MIT, github.com/3Shain/dxmt).
  CS2'ye özel değiştirilmiş sürüm: `d3d11/dxgi/d3d10core/winemetal` DLL'leri + `winemetal.so`.
  DLL ayarı: `dxgi,d3d11,d3d10core,winemetal=b` (Wine'ın içindeki "builtin" sürüm).
- **Gözlem:** Takılmaları azaltmak için gölgelendirici ön derleme: oyun oynanırken "tarif" (shader anahtarı +
  pipeline durumu) kaydediliyor; sonraki açılışta Play'den önce ayrı bir yardımcı (`prepare-pipelines.exe`) bunları
  Metal pipeline arşivlerine derliyor. Uygulamada kendi oyunlarından yakalanmış 532 tariflik bir başlangıç paketi var.
  Ortam değişkenleri: `DXMT_CS2_EARLY_COMPILE`, `DXMT_SHADER_CACHE_PATH`, `DXMT_CS2_PIPELINE_CACHE`, `DXMT_CS2_RECIPE_DIR`.
- **Gözlem:** Ekran: ilk açılışta `cs2_video.txt` (yedek alınarak) "Fullscreen Windowed" + Mac ekranının çözünürlüğüne
  ayarlanıyor. (Batman'deki fare sorununun aynısını önlemek için.)
- **Bilinmiyor:** CS2 için neden D3DMetal değil de DXMT seçildiği yazılı değil.

## Köprü için sonuç
1. CS2 ücretsiz ve kullanıcının hesabında. İlk deneme: bizim kurulumla (D3DMetal 4) Steam üzerinden, ek bir şey olmadan.
2. Çözünürlük: Batman'deki gibi oyunu masaüstü çözünürlüğünde "pencereli tam ekran" aç.
3. Takılma / görüntü sorunu olursa: DXMT'yi asıl projesinden (3Shain/dxmt, MIT) kendimiz derleyip deneriz.
4. Anti-cheat'e dokunulmaz. Online, ancak oyun kendiliğinden çalışırsa oynanır.
