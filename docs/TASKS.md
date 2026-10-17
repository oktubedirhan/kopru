# Köprü — ilerleme kaydı

## 2026-10-16 — Proje açıldı
- Klasör, `README.md` (yol haritası) ve `CLAUDE.md` (kurallar) oluşturuldu.
- Bilgisayar: Apple M2 Pro, 16 GB RAM, macOS 27.0.1, ~650 GB boş disk. Rosetta 2 kurulu. Homebrew kurulu.
- Referans incelendi: GameToMac Elden Ring'i şöyle çalıştırıyor:
  - Wine 11 + D3DMetal + MSync,
  - prefix içinde Windows Steam,
  - `eldenring.exe` doğrudan, `SteamAppId=1245620` ile (anti-cheat olmadan, yalnızca offline),
  - ilk açılışta VC++ 2019 ve DirectX June 2010 paketleri.
  - Kendi testleri M4 Pro'da; M2 Pro'da performans bilinmiyor.
- Kullanıcının Apple Developer hesabı var (D3DMetal indirmesi için yeterli).
- Elden Ring henüz satın alınmadı; Aşama 4'e kadar alınacak. O zamana kadar Aşama 1–3 ve 5, ücretsiz/eldeki bir DirectX oyunuyla denenebilir.
- Açık soru: Wine hangi kaynaktan kurulacak (Homebrew hazır paket mi, kaynaktan derleme mi)?

**Sıradaki adım:** Aşama 1 — Wine kurulumu ve ilk Windows programı.

## 2026-10-16 — Aşama 1: Wine kuruldu, ilk Windows programı açıldı ✅
- **Kaynak seçimi:** Homebrew'daki `wine-stable` / `wine@devel` cask'ları 2026-09-01'de kapatılmış (Gatekeeper denetiminden geçmiyor). Seçenekler: (A) WineHQ resmi macOS paketi, (B) Gcenx `game-porting-toolkit` (içinde D3DMetal geliyor, kuralımıza aykırı), (C) CrossOver kaynağından derleme (Aşama 6), (D) ticari CrossOver. **A seçildi: `wine-stable 11.0_1`.**
- **İndirme:** `github.com/Gcenx/macOS_Wine_builds` → `wine-stable-11.0_1-osx64.tar.xz` (191 MB). SHA-256 GitHub'daki değerle eşleşti (`b50dc50e…2388`). `curl` karantina işareti koymadığı için `xattr` gerekmedi.
- **Konumlar** (repo dışında, sistemin geri kalanına dokunmadan):
  - Wine: `~/Library/Application Support/Kopru/runtime/wine-stable-11.0/` (682 MB, x86_64 → Rosetta 2 ile çalışıyor)
  - Prefix'ler: `~/Library/Application Support/Kopru/prefixes/<ad>/`
- **Prefix:** `WINEPREFIX=…/prefixes/test wine wineboot --init` → 19 sn, 329 MB. İçinde `drive_c/` (C: sürücüsü) ve `system.reg`/`user.reg` (kayıt defteri). `WINEDLLOVERRIDES="mscoree,mshtml="` ile Mono/Gecko indirmesi kapatıldı.
- **Çalıştı:** `notepad.exe` açıldı. Kullanıcı pencereyi gördü, yazı yazdı, menüler çalıştı. `cmd /c ver` → `Microsoft Windows 10.0.19045`.
- **Yardımcı betik:** `scripts/kwine <prefix> <program>` (ör. `scripts/kwine test notepad`).
- **Öğrenilenler:**
  - Wine emülatör değil; Windows API çağrılarını macOS çağrılarına çeviriyor. x86 kodu Rosetta 2 çeviriyor.
  - `wineserver`, Windows çekirdeğinin işlerini taklit eden arka plan servisi; aynı prefix'teki programlar onu paylaşıyor.
  - Paket MoltenVK (Vulkan → Metal) ile geliyor; DirectX → Metal için D3DMetal Aşama 2'de eklenecek.
  - GameToMac, CrossOver 26.3 kaynağından (Wine 11.0) kendi derlediği Wine'ı kullanıyor (`RUNTIME-BUILD.md`).
- **Açık soru (Aşama 2):** D3DMetal upstream WineHQ ile çalışıyor mu, yoksa CrossOver tabanlı Wine mı gerekiyor? Denenmedi.

**Sıradaki adım:** Aşama 2. Kullanıcı Apple Developer sitesinden Game Porting Toolkit'i indirir, D3DMetal'in yapısını inceleriz, `wine-stable` ile çalışıp çalışmadığını deneriz.

## 2026-10-16 — Aşama 2 (başlangıç): GPTK 4.0 beta 3 indirildi ve incelendi
- **İndirme (kullanıcı):** developer.apple.com/download/all → `Game_Porting_Toolkit_4.0_beta_3.dmg` (105 MB, `~/Downloads/MC Download Manager/Apps/`). `hdiutil verify` → checksum VALID. dmg'nin kendisi imzasız (Apple geliştirici indirmelerinde olağan).
- **İçerik:** Asıl işimize yarayan `Evaluation environment for Windows games 4.0 beta 3.dmg` (68 MB). Kalanlar (Metal Shader Converter, örnek kodlar, metal-cpp) oyunu Mac'e port eden geliştiriciler için.
  - `redist/lib/external/D3DMetal.framework` + `libd3dshared.dylib` → DirectX'i Metal'e çeviren motor.
  - `redist/lib/wine/x86_64-windows/*.dll` + `x86_64-unix/*.so` → Wine'ın kendi `d3d11/d3d12/dxgi` DLL'lerinin yerine geçen köprüler (PE tarafı Windows'ta, .so tarafı macOS'ta çalışıyor).
  - `nvapi64` + `nvngx-on-metalfx` → DLSS çağrılarını MetalFX'e çevirme (deneysel).
- **Kopyalandı:** `~/Library/Application Support/Kopru/gptk/4.0-beta3/` (redist + Read Me + License). Kalıplar kapatıldı, orijinal dmg yerinde duruyor.
- **Read Me'den önemli notlar:** macOS 15+ ve Apple Silicon gerekiyor. Ortam değişkenleri: `D3DM_SUPPORT_DXR` (M2'de varsayılan kapalı), `ROSETTA_ADVERTISE_AVX`, `D3DM_ENABLE_METALFX`, `D3DM_MTL4` (macOS 27'de varsayılan açık), `D3DM_MAX_FPS`. Loglar `D3DM` önekiyle Console'da görünüyor. Shader önbelleği `$(getconf DARWIN_USER_CACHE_DIR)/d3dm/` altında.
- **Açık soru cevaplandı (denenmedi, kanıta dayanıyor):** D3DMetal, upstream `wine-stable` ile **çalışmaz**.
  - Read Me: "custom version of Wine" gerekli diyor.
  - `libd3dshared.dylib`, Wine'ın Mac sürücüsünde `macdrv_functions` adlı bir tablo arıyor (oyunun penceresini bulup üstüne Metal ile çizmek için). Hata mesajı: "No macdrv window data for hwnd".
  - `nm -gU winemac.so` → bizim `wine-stable` bu tabloyu dışa açmıyor. Bu tablo CrossOver'ın yamalarında var.
- **CrossOver kaynağı erişilebilir:** `media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz` (149 MB, 2026-07-21).

**Sıradaki adım:** CrossOver tabanlı bir Wine edinmek (kullanıcı seçecek).

## 2026-10-16 — Aşama 2: CrossOver tabanlı Wine + kullanıcının D3DMetal'i birleştirildi (kısmen doğrulandı)
- **Seçim:** A, yani Gcenx `game-porting-toolkit-3.0-3.tar.xz` (239 MB). SHA-256 eşleşti (`d3776839…392e`). Kaynak: `apple/homebrew-apple` tarifi.
- **Konum:** `~/Library/Application Support/Kopru/runtime/gptk-wine-3.0-3/` (804 MB). Komut `wine64` (bu sürümde `wine` yok).
- **Wine sürümü: `wine-7.7 (Game Porting Toolkit 1.1)`.** Apple'ın tarifi hâlâ eski CrossOver tabanında. `wine-stable` 11.0'dan çok eski; Steam gibi modern programlarda sorun çıkabilir (Aşama 3'te göreceğiz).
- **`macdrv_functions` var** (`nm -gU lib/wine/x86_64-unix/winemac.drv.so`). D3DMetal'in pencereyi bulmak için aradığı giriş noktası bu Wine'da mevcut.
- **D3DMetal değişimi:** Paketle gelen D3DMetal **3.0** tamamen silindi; yerine kullanıcının Apple'dan indirdiği **4.0b3** kondu:
  - `lib/external/` → silindi, `gptk/4.0-beta3/redist/lib/external` ile değiştirildi.
  - `lib/wine/x86_64-{windows,unix}/` içindeki `d3d10, d3d11, d3d12, d3d12core (yeni), dxgi, nvapi64, nvngx-on-metalfx` tek tek değiştirildi. `nvngx.*` (MetalFX) da bizim kopyadan yeniden oluşturuldu.
  - Doğrulama: 16 dosya `cmp` ile aynı. `D3DMetal` ve `libd3dshared.dylib` SHA-256 aynı. Framework sürümü `4.0b3`.
  - Not: Apple Read Me'deki `mv wine wine.old` talimatı bu pakette Wine'ın bütün DLL'lerini kenara alırdı; uygulanmadı.
- **Öğrenilen:** Apple paketindeki `x86_64-unix/*.so` dosyalarının hepsi `libd3dshared.dylib`'e giden symlink. D3DMetal'in macOS tarafı tek bir kütüphane; Windows tarafında her DirectX DLL'i için ince bir köprü var.
- **Prefix:** `prefixes/gptk-test` (23 sn, 327 MB). `cmd /c ver` → `10.0.19043`.
- **Test (yarım):** `WINEDEBUG=+loaddll wine64 rundll32 dxgi.dll,CreateDXGIFactory` → `system32/dxgi.dll` yüklendi (dosya birebir Apple'ınki), ancak rundll32 "entry point bulunamadı" dedi. Export listesinde `CreateDXGIFactory` var (`xcrun llvm-objdump -p`); rundll32 bu tür işlevleri çağırmak için uygun araç değil. **D3DMetal'in gerçekten çizim yaptığı henüz doğrulanmadı.**
- Not: macOS'ta `timeout` komutu yok; yerine `perl -e 'alarm 40; exec @ARGV' <komut>`.

## 2026-10-16 — Aşama 2: kendi DirectX test programımız → D3DMetal 4 + Wine 7.7 uyumsuz ❌
- **Derleyici:** llvm-mingw 20261006 (ucrt, macOS universal, 124 MB indirme, SHA-256 eşleşti) → `~/Library/Application Support/Kopru/toolchains/` (783 MB). Mac'te Windows `.exe` üretiyor.
- **Test programı:** `tools/dxgi-probe/` (`dxgi_probe.c` + `build.sh`). DXGI ile GPU'ları listeliyor, D3D11 ve D3D12 cihazı açmayı deniyor, yüklenen DLL yollarını yazıyor.
- **Sonuç: wine-stable 11.0 (wined3d, D3DMetal yok):** GPU "NVIDIA GeForce 6800" (wined3d'nin sahte varsayılanı), D3D11 feature level 9.3, D3D12 açıldı (vkd3d + MoltenVK). Çalışıyor ama modern oyunlar için yetersiz.
- **Sonuç: GPTK Wine 7.7 + D3DMetal 4.0b3:** çıktı yok, çıkış kodu 66. `WINEDEBUG=+err` → `"dxgi.dll" failed to initialize, aborting` (status c0000142).
- **Kök neden (kanıtlı):** D3DMetal 4'ün `dxgi.dll`'i başlarken `GetProcAddress(ntdll, "__wine_unix_call_dispatcher")` yapıyor (dll içinde bu dize var). Bu, Windows tarafının macOS tarafına seslendiği yeni Wine mekanizması:
  - Wine 7.7 (GPTK) ntdll: `__wine_unix_call_dispatcher` **YOK** (yalnızca eski `__wine_unix_call` var).
  - Wine 11.0 (stable) ntdll: **VAR**, ama orada da `macdrv_functions` yok.
  - Sonuç: D3DMetal 4, **yeni Wine (≥8/9) + CrossOver yamaları** istiyor. Paketteki eski Wine'ı ancak D3DMetal 3.0 ile eşleştirmek mümkün.
- **Hazır alternatif bulundu:** Sikarugir-App/Engines → `WS12WineCX24.0.7_7.tar.xz` (CrossOver 24.0.7 = Wine 9.0, 172 MB). D3DMetal 4 ile uyumu bilinmiyor.
- Eski D3DMetal 3.0 kopyası (Gcenx paketinden) **kullanılmadı**, silindi.

### Karar ve plan (2026-10-16, henüz başlanmadı)
Kullanıcı önerilen yolu seçti: **önce 1, sonra 3.**

**Adım 2a: D3DMetal'i GPTK 3.0 ile çalışırken görmek (Aşama 2'yi bitirir)**
1. *Kullanıcı:* developer.apple.com/download/all/?q=game%20porting%20toolkit → **Game Porting Toolkit 3.0** dmg'sini indirir (4.0b3'ü silmez).
2. dmg'yi `hdiutil verify` + `hdiutil attach -readonly -nobrowse` ile aç → içindeki `Evaluation environment … 3.0.dmg` → `redist/lib/` → `~/Library/Application Support/Kopru/gptk/3.0/` altına kopyala.
3. `runtime/gptk-wine-3.0-3/Contents/Resources/wine/lib/` içinde D3DMetal 4.0b3 dosyalarını 3.0 ile değiştir: `external/` klasörü + `wine/x86_64-{windows,unix}/` içindeki `d3d10, d3d11, d3d12, d3d12core, dxgi, nvapi64, nvngx(-on-metalfx)`. Symlink'leri `cp -P` ile koru. Wine'ın diğer DLL'lerine dokunma (Apple Read Me'deki `mv wine wine.old` bu pakette yanlış). 3.0'da `d3d12core` yoksa 4.0b3'ten kalanı sil. `cmp`/`shasum` ile doğrula.
4. `prefixes/gptk-test` prefix'ini sil ve yeniden oluştur (system32'ye eski DLL'ler kopyalanmıştı).
5. `tools/dxgi-probe/dxgi-probe.exe`'yi çalıştır. Beklenen: GPU adı "Apple M2 Pro", D3D11 feature level 11.x/12.x, D3D12 TAMAM. Console'da `D3DM` logları.
6. Sonucu buraya yaz (çalıştı/çalışmadı ayrımıyla).

**Adım 2b: CrossOver 26.3'ü kaynaktan derlemek (Elden Ring için asıl yol; Aşama 3'ten önce)**
- Neden: D3DMetal 4, `__wine_unix_call_dispatcher` (yeni Wine) + `macdrv_functions` (CrossOver yaması) istiyor. GameToMac de CrossOver 26.3 (Wine 11.0) kullanıyor.
- Kaynak: `https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz` (149 MB).
- Derleyici hazır: `~/Library/Application Support/Kopru/toolchains/llvm-mingw-20261006-ucrt-macos-universal`.
- Gerekecekler (kurmadan önce kullanıcıya sor): x86_64 freetype + gnutls kütüphaneleri; muhtemelen Homebrew `bison`, `flex`, `pkg-config`.
- GameToMac'in `RUNTIME-BUILD.md` notundaki configure bayrakları referans (okunur, kopyalanmaz): `--enable-archs=i386,x86_64 --with-mingw=llvm-mingw --without-x`, x86_64 hedefi.
- Hedef: `runtime/crossover-26.3/` + D3DMetal 4.0b3 → `dxgi-probe` ile doğrula.

**Mevcut durum özeti (yeni oturum için):**
- `~/Library/Application Support/Kopru/`
  - `runtime/wine-stable-11.0/`: WineHQ resmi, çalışıyor (wined3d).
  - `runtime/gptk-wine-3.0-3/`: Gcenx, Wine 7.7. **Şu an içinde D3DMetal 4.0b3 var ve çalışmıyor.**
  - `gptk/4.0-beta3/`: kullanıcının Apple'dan indirdiği redist + Read Me.
  - `toolchains/llvm-mingw-…/`: Windows derleyicisi.
  - `prefixes/test` (wine-stable), `prefixes/gptk-test` (gptk-wine).
- Repo: `scripts/kwine` (yalnızca wine-stable için), `tools/dxgi-probe/`.
- Orijinal GPTK 4.0b3 dmg: `~/Downloads/MC Download Manager/Apps/Game_Porting_Toolkit_4.0_beta_3.dmg`.

**Sıradaki adım:** Kullanıcı GPTK 3.0'ı indirince Adım 2a'ya başla.

## 2026-10-16 — Aşama 2 (Adım 2a): D3DMetal 3.0 + GPTK Wine 7.7 → DirectX cihazı açıldı ✅
- **İndirme (kullanıcı):** `Game_Porting_Toolkit_3.0.dmg` (94 MB, `~/Downloads/MC Download Manager/Apps/`). `hdiutil verify` → VALID; iç `Evaluation environment for Windows games 3.0.dmg` de VALID.
- **Uyum kontrolü (kopyalamadan önce):** 3.0'ın `dxgi/d3d11/d3d12.dll`'leri yalnızca eski `__wine_unix_call`'u kullanıyor; `__wine_unix_call_dispatcher` yok (4.0b3'te var). Wine 7.7 ile uyumlu olması beklendi.
- **Kopya:** redist + Read Me/License/Acknowledgements → `~/Library/Application Support/Kopru/gptk/3.0/` (63 MB, `diff -r` aynı). Framework sürümü `3.0`.
- **3.0'ın 4.0b3'ten farkı:** `d3d12core` yok; `atidxx64` (AMD sürücü uzantısı köprüsü) var.
- **Runtime değişimi** (`runtime/gptk-wine-3.0-3/Contents/Resources/wine/lib/`):
  - `external/` silindi → 3.0'ınki kondu.
  - `x86_64-windows/*.dll` + `x86_64-unix/*.so` (symlink): `atidxx64, d3d10, d3d11, d3d12, dxgi, nvapi64, nvngx-on-metalfx` değiştirildi; `nvngx.dll/.so` 3.0'dan yeniden üretildi.
  - `d3d12core.dll/.so` (4.0b3 kalıntısı) silindi.
  - Doğrulama: 17 dosya `cmp` aynı, kırık symlink yok. SHA-256 (ilk 16): `libd3dshared` `5131e631eee8b542`, `D3DMetal` `05a7beaed4494a4f`.
- **Prefix:** `prefixes/gptk-test` silinip yeniden oluşturuldu (15 sn, 329 MB). `system32/dxgi,d3d11,d3d12.dll` = 3.0.
- **dxgi-probe güncellendi:** D3D11'e 12.1→10.0 seviye listesi veriliyor (liste verilmezse en fazla 11.0 istiyor), seviye ondalık yazılıyor.
- **Sonuç (çalıştı):**
  ```
  Ekran kartı 0: AMD Compatibility Mode   VendorId=0x1002 DeviceId=0x66af
  Ayrılmış video belleği: 12124 MB
  D3D11 cihazı: TAMAM, feature level 12.1
  D3D12 cihazı: TAMAM
  ```
  Çıkış kodu 0, `WINEDEBUG=+err` temiz.
- **Kanıt (D3DMetal'in devrede olduğu):** "AMD Compatibility Mode" dizesi yalnızca `D3DMetal.framework/Versions/A/D3DMetal` içinde var; `wined3d.dll`, `dxgi.dll` ve `libd3dshared.dylib`'de yok. Karşılaştırma: wine-stable (wined3d) "NVIDIA GeForce 6800", FL 9.3 vermişti.
- **Öğrenilen:** D3DMetal, ekran kartını bilerek AMD (Radeon VII kimliği `0x66af`) olarak tanıtıyor. Oyunlar böylece bilinen, iyi test edilmiş AMD kod yolunu seçiyor. `atidxx64.dll` de bu yüzden var (AMD'nin sürücü uzantılarını soran oyunlara cevap veriyor). Video belleği 12 GB = 16 GB birleşik belleğin GPU'ya ayrılabilen kısmı.
- **Denenmedi / doğrulanmadı:**
  - Pencereye gerçek çizim (swapchain + `Present`). Probe pencere açmıyor; `macdrv_functions` yolu henüz test edilmedi.
  - Sistem logunda `D3DM` satırı çıkmadı (`log show … category == "D3DMetal"` boş). Muhtemelen yalnızca çizim başlayınca log yazıyor.
  - `DYLD_PRINT_LIBRARIES=1` Wine başlatıcısından geçmedi; `lsof` kısa ömürlü süreci yakalayamadı.
- Kapatılan kalıplar: yalnızca bu oturumda açılanlar. Kullanıcının Finder'dan açtığı "Game Porting Toolkit" (4.0b3) ve "Game Porting Toolkit 1" (3.0) açık bırakıldı.

**Mevcut durum:** `runtime/gptk-wine-3.0-3/` = Wine 7.7 + **D3DMetal 3.0** (çalışıyor). `gptk/4.0-beta3/` Adım 2b için duruyor.

**Sıradaki adım:** (İsteğe bağlı, küçük) Probe'a pencere açıp ekranı bir renge boyayan D3D11 testi eklemek → D3DMetal'in pencereye çizdiğini görmek. Ardından **Adım 2b**: CrossOver 26.3'ü kaynaktan derlemek (Homebrew paketleri gerekecek, kurmadan önce kullanıcıya sorulacak).

## 2026-10-16 — Aşama 2: D3DMetal 3.0 pencereye çiziyor ✅ (Aşama 2 tamam, eski Wine ile)
- **Yeni test programı:** `tools/d3d-window/` (`d3d_window.c` + `build.sh`). Pencere açıyor, D3D11 swapchain kuruyor (önce `FLIP_DISCARD`, olmazsa `DISCARD`), pencereyi her saniye kırmızı → yeşil → mavi boyuyor, `Present(1, 0)` (vsync) ile ekrana veriyor. `d3d-window.exe [saniye]`, Esc ile erken kapanıyor.
- **Komut:** `WINEPREFIX=…/prefixes/gptk-test WINEDEBUG=+err wine64 tools/d3d-window/d3d-window.exe 10` (GPTK Wine 7.7 + D3DMetal 3.0).
- **Sonuç (çalıştı):**
  - Program çıktısı: `Swapchain: TAMAM (FLIP_DISCARD)`, FL 12.1, 1204 kare / 10 sn = **120 FPS** (ekranın 120 Hz ProMotion yenilemesine kilitli), `Present: hatasız`, çıkış kodu 0.
  - **Kullanıcı gözüyle doğruladı:** renkler kırmızı → yeşil → mavi geçti, titreme ve yanlış boyut yok. (Pencere başlığına dikkat etmedi; başlık doğrulanmadı, önemsiz.)
  - stderr'de yalnızca `fixme:imm` (Wine'ın IME/giriş yöntemi taslakları), zararsız.
- **D3DMetal'in devrede olduğunun ek kanıtı:** `$(getconf DARWIN_USER_CACHE_DIR)/d3dm/` altında `d3d-window.exe/` ve `dxgi-probe.exe/` klasörleri bu testlerle oluştu (D3DMetal her program için shader önbelleği açıyor). Sistem logunda `D3DM` satırı yine yok.
- **Bu ne demek:** D3DMetal, Wine'ın Mac pencere sürücüsündeki `macdrv_functions` tablosunu bulup oyun penceresinin üstüne Metal ile çizebiliyor. Oyunların ihtiyaç duyduğu zincirin tamamı (DXGI → D3D11 → D3DMetal → Metal → pencere) uçtan uca çalışıyor.
- **Not:** Aynı `d3dm/` klasöründe `steam.exe`, `witcher3.exe`, `REDlauncher.exe` vb. 3–4 Ekim tarihli klasörler var (GameToMac kullanımından). Onlara dokunulmadı.
- **Denenmedi:** D3D12 ile pencereye çizim (yalnızca cihaz açıldı), gerçek shader çalıştırma (yalnızca ekran temizleme), tam ekran.
- **Sınır:** Bu kurulum Wine 7.7 (2022). Modern Steam ve Elden Ring için yetersiz olabilir. D3DMetal 4 ise yeni Wine istiyor, Adım 2b'nin sebebi bu.

**Sıradaki adım:** **Adım 2b**: CrossOver 26.3'ü (Wine 11.0) kaynaktan derlemek, D3DMetal 4.0b3'ü bağlamak, `dxgi-probe` ve `d3d-window` ile doğrulamak. Homebrew paketleri (`bison`, `flex`, `pkg-config` ve x86_64 freetype/gnutls) gerekecek; kurmadan önce kullanıcıya sorulacak.

## 2026-10-16 — Aşama 2 (Adım 2b): CrossOver 26.3 Wine'ı kaynaktan derlendi + D3DMetal 4 çalışıyor ✅
Kullanıcı bu adımda "onay bekleme, en mantıklısını yap" dedi; aşağıdaki seçimler gerekçesiyle.

- **Kaynak:** `media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz` (149.054.023 bayt, sunucu boyutuyla aynı; resmi checksum yok, SHA-256 `ac99c8ca…6872`). Yalnızca `sources/wine` açıldı → `~/Library/Application Support/Kopru/src/crossover-26.3/` (Wine 11.0, 332 MB).
- **Kaynakta doğrulanan:** `dlls/winemac.drv/d3dmetal.c` → `macdrv_functions`; ntdll'de `__wine_unix_call_dispatcher`; `CX_APPLEGPTK_LIBD3DSHARED_PATH` (ntdll, libd3dshared'i erkenden yükleyip Rosetta'ya "non-native code region" bildiriyor + D3DMetal çağrıları için ms_abi/sysv thunk'ları).
- **Homebrew (ARM, yalnızca derleme aracı/başlık):** `bison` 3.8.2 (macOS'taki 2.3 eski), `gnutls` 3.8.13 (yalnızca başlıklar için). `freetype` 2.14 zaten vardı.
- **x86_64 bağımlılıklar:** GPTK Wine paketindeki FreeType 2.13 + GnuTLS 3.8.7 ve `otool -L` ile çıkarılan zincir (20 dylib, 11 MB) → `Kopru/deps/x86_64/lib/`. Kimlikleri `@rpath/libfreetype.6.dylib`, `@rpath/libgnutls.30.dylib` yapılıp ad-hoc imzalandı. Ayrı bir Intel Homebrew (`/usr/local`) kurulmadı.
- **Derleme betiği:** `scripts/build-crossover-wine.sh [deps|patch|configure|build|install|all]`.
  - `CC/OBJC="/usr/bin/clang -arch x86_64"`, llvm-mingw (i386 + x86_64 PE), `--enable-archs=i386,x86_64 --without-x --without-gstreamer --without-vulkan` (+ Linux'a özgüler kapalı), `--disable-tests`.
  - Kurulum: `~/Library/Application Support/Kopru/runtime/crossover-26.3/` (513 MB). FreeType/GnuTLS `lib/deps/` altında.
  - Derleme süresi: toplam ~6 dk (12 çekirdek).
- **Karşılaşılan sorunlar ve çözümler (öğrenilenler):**
  1. `C compiler cannot create executables`: llvm-mingw'nin `bin/`inde de `clang` var, PATH'te önde olunca Mac derleyicisinin yerine geçti → CC tam yol, mingw PATH sonunda.
  2. Objective-C derleyicisi `gcc` (= ARM clang) seçilmişti → `OBJC` ayrıca verildi (winemac.drv Obj-C).
  3. `-L…/Application Support/…` boşlukta bölündü → boşluksuz kısayol **`~/.kopru` → `~/Library/Application Support/Kopru`**.
  4. `sfnt2fon` (yazı tipi aracı) `Abort trap: 6`: libfreetype bulunamadı. `DYLD_FALLBACK_LIBRARY_PATH` işe yaramadı çünkü **SIP, `DYLD_*` değişkenlerini `/usr/bin/make` ve `/bin/sh`'tan geçerken siliyor** → `LDFLAGS=-Wl,-rpath,<deps>`. (configure, `@rpath/` önekini atıp yalın `libfreetype.6.dylib` adını kaydediyor.)
  5. `--without-vulkan` ile `win32u/vulkan.c` derlenmedi (CW HACK 25909 `SONAME_LIBVULKAN` varsayıyor) → **yama 0001**: tanımlı değilse `"libvulkan.1.dylib"`; dlopen başarısız olunca Vulkan'sız devam ediyor.
  6. wineboot `EXCEPTION_WINE_ASSERTION` ile ölüyordu. Sebep: Vulkan yüklenemeyince yazılan ERR mesajı macOS'un uzun `dlerror()` metnini (denenen tüm yollar) içeriyor, Wine'ın log tamponu taşınca `debug.c` **abort()** ediyor → **yama 0002**: `%.200s`.
  7. Prefix 1 GB'tı (PE DLL'lerde `-g` debug bilgisi, her prefix'e kopyalanıyor) → install adımında `llvm-strip --strip-debug` (yalnızca debug bölümleri). Runtime 1,1 GB → 513 MB, prefix 424 MB.
  - Yamalar: `patches/crossover-26.3/*.patch`, betik idempotent uyguluyor.
- **D3DMetal bağlantısı, kendi kancamız:** CrossOver ntdll'i açılışta kendi klasöründeki `cxcompatdb.so`'yu (CrossOver'da kapalı kaynak) dlopen ediyor. Biz aynı adla kendi küçük kütüphanemizi yazdık: `tools/d3dmetal-hook/` → `KOPRU_D3DMETAL_DLLPATH` ayarlıysa ntdll'in `prepend_dll_path()` fonksiyonuyla o klasörü DLL arama listesinin **başına** koyuyor. (`WINEDLLPATH` yetmiyor: Wine kendi `dll_dir`'ine önce bakıyor.)
  - Sonuç: Wine kurulumu bozulmuyor, D3DMetal dosyaları kopyalanmıyor (`gptk/4.0-beta3/redist/lib` doğrudan kullanılıyor), D3DMetal her çalıştırmada açılıp kapatılabiliyor.
- **`scripts/kwine` yenilendi:** `kwine [-r cx|stable] [--no-d3dmetal] <prefix> <program>`. Varsayılan `cx` + D3DMetal açık; `DYLD_FALLBACK_LIBRARY_PATH`, `KOPRU_D3DMETAL_DLLPATH`, `CX_APPLEGPTK_LIBD3DSHARED_PATH` ayarlıyor. Not: bir prefix'i tek runtime'la kullan.
- **Prefix:** `prefixes/cx-test` (17 sn, 424 MB, `cmd /c ver` → `10.0.19045`, system32 + syswow64 dolu).
- **Test: `dxgi-probe`, D3DMetal kapalı ↔ açık (çalıştı):**
  | | `--no-d3dmetal` (wined3d) | D3DMetal 4.0b3 |
  |---|---|---|
  | Ekran kartı | NVIDIA GeForce 8800 GTX (sahte) | AMD Compatibility Mode |
  | D3D11 | FL 10.1 | FL 12.1 |
  | D3D12 | başarısız 0x80004005 (Vulkan yok → vkd3d yok) | TAMAM |
- **`d3d-window` D3D12 modu eklendi** (`--d3d12`: komut kuyruğu, swapchain, RTV heap, kaynak durum geçişleri, fence ile bekleme). Elden Ring DX12 kullandığı için önemli.
- **Test: pencereye çizim, D3DMetal 4 (teknik olarak çalıştı):** D3D11 → 924 kare / 8 sn, 115 FPS, Present hatasız. D3D12 → 922 kare / 8 sn, 115 FPS, Present hatasız. Çıkış kodları 0; `d3dm/d3d-window.exe/shaders.cache` oluştu.
  - Görsel doğrulama (kullanıcı): "tamamdır" dedi, renk değişimini açıkça teyit etmedi. Teknik olarak doğrulandı, görsel olarak kesin değil.
- **Zararsız uyarılar:** Apple Neural Engine `doCompileModel … Bad argument` (D3DMetal 4 açılışında, muhtemelen MetalFX modeli), `winebth` (Bluetooth sürücüsü) başlatılamadı, servislerin 1115 hatası (wineboot kapanırken).
- **Denenmedi:** gerçek shader/3D sahne, tam ekran, MetalFX (`nvngx` adlandırması bu düzende yok), 32-bit (i386) bir programın çalışması.
- **Bilinen eksik:** GameToMac'in Wine'ında Steam için ek yamalar var ("Steam CEF single-process" vb.). Bizde yok; Steam arayüzü sorun çıkarırsa Aşama 3'te ele alınacak.

**Mevcut durum:** Asıl runtime artık `runtime/crossover-26.3` (Wine 11.0 + CrossOver yamaları) + D3DMetal 4.0b3. `gptk-wine-3.0-3` (Wine 7.7 + D3DMetal 3.0) ve `wine-stable-11.0` karşılaştırma için duruyor.

**Sıradaki adım:** Aşama 3: yeni bir `steam` prefix'i, Windows Steam kurulumu (Steam'in resmi `SteamSetup.exe`'si), giriş ve arayüzün açılması. Elden Ring henüz satın alınmadı; Steam kurulumu ve ücretsiz bir DirectX oyunuyla deneme yapılabilir.

## 2026-10-16 — Aşama 3 (başlangıç): Windows Steam kuruldu, arayüz kendi Wine yamamızla açıldı ✅
- **kwine varsayılanları (cx):** `WINEMSYNC=1` (Mach tabanlı senkronizasyon; wineserver ile aynı olmalı), `ROSETTA_ADVERTISE_AVX=1`, `WINEDLLOVERRIDES` += `winemenubuilder.exe=` ve `gameoverlayrenderer,gameoverlayrenderer64=` (Steam katmanı kapalı), `KOPRU_STEAMWEBHELPER_ARGS=--single-process` (aşağıda).
- **Yöntem kaynağı:** GameToMac `Core.swift` okundu (kopyalanmadı): `SteamSetup.exe /S`, `steam.exe -cef-disable-gpu`, MSync, AVX, overlay kapalı.
- **Yükleyici:** `cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe` (2,38 MB, SHA-256 `7d365453…12bcb`) → `Kopru/downloads/steam/`. `osslsigncode verify` (Homebrew'dan kuruldu): imzalayan **Valve Corp.**, özet eşleşiyor, zincir DigiCert'e kadar geçerli.
- **Prefix:** `prefixes/steam` (cx runtime). Kurulum: yükleyici `C:\`'ye kopyalandı, `kwine steam 'C:\SteamSetup.exe' /S` → 42 sn, `C:\Program Files (x86)\Steam\Steam.exe`.
- **İlk açılış:** Steam kendini güncelledi (336 MB, istemci sürümü 1791918634, klasör ~1,4 GB).
  - ⚠️ **Bilinen sorun:** Güncelleme bitince güncelleyici kendini yeniden başlatırken `err:virtual:virtual_setup_exception nested exception on signal stack addr 0x2086f31c9` ile donuyor/çöküyor (iki kez, hep aynı adres). Elle kapatıp (`wineserver -k`) Steam'i yeniden başlatınca sorun yok. Steam her güncellendiğinde tekrarlayabilir. **Kök neden henüz araştırılmadı.**
  - Benim hatam: `perl alarm` süre sınırı, Wine'da `steam.exe`'ye dönüşen süreci öldürüyor. Uzun süre açık kalacak programlarda süre sınırı kullanma.
- **Sorun: giriş penceresi siyah.** Log'lara göre arayüz çalışıyordu (`webhelper.txt`: `DesktopLoginWindow BrowserCreated`), yazılım ile görüntü oluşturma (`gpu_compositing: disabled_software`) açıktı. Teşhis: Chromium görüntüyü ayrı bir GPU sürecinde birleştirip ana sürecin penceresinin içine kendi çocuk penceresini açarak çiziyor. Wine'ın Mac sürücüsünde başka süreçteki çocuk pencere siyah kalıyor.
  - Denendi, işe yaramadı: `steam.exe -cef-in-process-gpu` (Steam bu seçeneği steamwebhelper'a iletmiyor; `ps` ile görüldü).
  - GameToMac'in Wine kaynağı (`wine-source.tar.gz`) diske açılmadan okundu: `kernelbase/process.c`'de steamwebhelper ana sürecine `--single-process` ekleyen, ortam değişkeniyle açılan bir yama var.
  - **Kendi yamamız: `patches/crossover-26.3/0003-kernelbase-steamwebhelper-extra-args.patch`.** `CreateProcessInternalW` içinde, başlatılan program `steamwebhelper.exe` ana süreciyse (`--type=` yoksa) `KOPRU_STEAMWEBHELPER_ARGS` değerini komut satırına ekliyor. Daha genel: Wine'ı yeniden derlemeden istenen Chromium seçeneği denenebilir.
  - **Sonuç (çalıştı, kullanıcı gördü):** `--single-process` ile tek steamwebhelper süreci, çocuk süreç yok; giriş ekranı görünüyor.
- **Zararsız log satırları:** Kerberos yok, Toast/PenDevice WinRT sınıfları yok, `gldriverquery.exe` SDL2 bulamadı, `Steam Client Service` başlamadı, Vulkan yok.
- **Sorun 2: QR kod gelmiyor, "yükleniyor"da kalıyor.** `connection_log.txt`: sürekli `[Logged Off] EConnect called - scheduling connection for 50ms from now` (~15/sn), gerçek bağlanma denemesi yok.
  - Elenenler (denendi, sebep değil): GnuTLS/HTTPS (kendi `tools/net-probe` WinHTTP aracımız CM listesini HTTP 200 ile indirdi), CPU frekansı `~MHz` (=1000, doğru), MSync (`WINEMSYNC=0` ile aynı sorun; kwine artık `WINEMSYNC` değişkenini dışarıdan kabul ediyor), GameToMac'in Wine değişiklikleri (kendi kaynaklarıyla dosya dosya karşılaştırıldı: 9 dosya, Steam ağıyla ilgili bir şey yok; tek süreç ayarı onlarda da varsayılan açık).
  - `+winsock` izlemesi: Steam `*.steamserver.net` için hiç DNS sorgusu yapmamış, yani bağlantıya hiç başlamamış.
  - **`sample <pid>` (macOS) ile bulundu:** `MachineIDInfoThread` zamanının tamamını `NtQueryDirectoryObject`'te geçiriyor.
  - Geçici `TRACE_(kopru)` ile ölçüldü: 40 sn'de 2,4 milyon çağrı, hep `index 0`. `restart` (BOOLEAN) değerleri `147906048` / `1280`: alt bayt 0 (FALSE), üst baytlar çöp.
  - **Kök neden:** Windows (MS x64) çağıranı BOOLEAN argümanın yalnızca alt baytını yazıyor. Apple clang ise (x86-64 SysV alışkanlığı) küçük tamsayı argümanların 32 bite genişletilmiş geldiğini varsayıp tüm register'ı test ediyor. Çöp yüzünden `restart` hep TRUE sayılıyor, dizin okuması hiç ilerlemiyor, makine kimliği hesaplanamıyor, Steam CM bağlantısını sonsuza kadar erteliyor. Linux'ta (GCC) bu sorun yok; Mac'te clang ile derlenen her BOOLEAN alan syscall'da gizli risk var.
  - **Yama 0004** (`patches/crossover-26.3/0004-ntdll-NtQueryDirectoryObject-clean-boolean-args.patch`): `kopru_clean_boolean()` değeri volatile bir bayta yazıp geri okuyor (gerçek tek bayt okuma). `single_entry` ve `restart` için uygulandı.
  - **Sonuç (çalıştı):** dizin okuması `index 0→61` ilerliyor (186 çağrı), `EConnect` yağmuru 0; `YieldingConnect → GetCMListForConnect (216 CM) → Connect() ext1-par1.steamserver.net:27022 WebSocket → ConnectionCompleted`.
  - Not: GameToMac'te neden görülmediği bilinmiyor; test ettikleri Steam derlemesi (25080141) bizimkinden (1791918634, 13 Eki 2026) farklı. Doğrulanmadı.
  - Kurulum notu: kalıcı yama (tanılama satırı olmadan) derlendi; Steam kapanınca `install` yapılacak. Şu an kurulu olan sürüm aynı düzeltmeyi + geçici `kopru` log kanalını içeriyor.
- **Öğrenilen araç:** macOS `sample <pid> <sn>` Wine süreçlerinde Wine'ın Mac tarafı fonksiyon adlarını ve Steam'in iş parçacığı adlarını gösteriyor. PE (Windows) kodu `???` görünüyor ama hangi syscall'da takıldığı anlaşılıyor.
- **Denenmedi:** QR/şifre ile giriş, kütüphane/mağaza, oyun indirme, Steam'in tekrar güncellenmesi.

**Sıradaki adım:** Kullanıcı giriş yapar (QR ya da şifre). Steam kapanınca kalıcı yama kurulur. Sonra BOOLEAN alan diğer ntdll syscall'ları gözden geçirilir (aynı sınıf hata). Ardından küçük ve ücretsiz bir DirectX 11/12 oyun.

## 2026-10-16 — Aşama 3: Steam'e giriş yapıldı, Witcher 3 APFS klonuyla eklendi ✅
- **Giriş (kullanıcı):** Steam hesabına girildi, mağaza sorunsuz çalışıyor (kullanıcı gördü).
- Kalıcı yama 0004 (tanılama satırı olmadan) kuruldu; `ntdll.so`'da geçici log kanalı kalmadığı doğrulandı.
- **Soru:** GameToMac'te indirilen Witcher 3 neden görünmüyor? → Her prefix ayrı bir "Windows"; GameToMac'in Steam'i ayrı prefix'te (`~/Library/Application Support/Game Library/Games/witcher3/prefix`, oyun 65 GB).
- **Karar (kullanıcı, AskUserQuestion):** APFS klonu. CLAUDE.md'ye istisna olarak yazıldı.
  - Klonlananlar: `steamapps/common/The Witcher 3` (1.928 dosya, 65 GB), `common/Steamworks Shared` (153 MB, VC++/DirectX yükleyicileri), `appmanifest_292030.acf`, `appmanifest_228980.acf` → `prefixes/steam/.../steamapps/`.
  - Komut: `cp -c -R -p` (APFS klonu: anında, ek disk yeri yok, kopya-üzerine-yazma). Süre 1 sn, boş disk 635 GB (değişmedi).
  - Doğrulama: kaynak ağacın (yol|boyut|mtime) SHA-256 parmak izi önce/sonra aynı (`8f83722d8549cc77`). Save'lere (`users/crossover/Documents/The Witcher 3`) dokunulmadı.
- **Sonuç:** Steam `content_log`: `AppID 292030 state changed : Update Required,Fully Installed` (güncelleme ~10 saat ertelenmiş); `libraryfolders.vdf`'e 228980 ve 292030 eklendi.
- **Dikkat (Steam Cloud):** Bizim prefix'te Witcher 3 save'i yok. Oyun ilk açılışta Steam Cloud'dan save çekebilir ve yeni save'ler buluta yüklenebilir; bu GameToMac tarafındaki save'leri de etkileyebilir. Oyunu açmadan önce GameToMac prefix'indeki save klasörünün yedeği alınmalı (salt okunur kopya).
- **Denenmedi:** Witcher 3 güncellemesi, başlatma (DX12/DX11, D3DMetal), save senkronizasyonu.

**Sıradaki adım:** Witcher 3 güncellenir; save yedeği alınır; Witcher 3 D3DMetal ile başlatılır (Elden Ring öncesi gerçek DX12 oyun testi). Ayrıca: BOOLEAN alan diğer ntdll syscall'ları gözden geçirilecek; güncelleme sonrası "nested exception" donması araştırılacak.

## 2026-10-17 — Aşama 3: Witcher 3 save yedeği + Steam Cloud durumu ✅
- **Bulgu: bizim prefix'in `Documents`'ı Mac'in gerçek `~/Documents`'ına symlink.** Wine prefix oluştururken `users/crossover/{Documents,Downloads,Music,Pictures,Videos}` klasörlerini Mac ev klasörüne bağlıyor (GameToMac/CrossOver bunu kapatıyor, onlarda gerçek klasör). Sonuç: Witcher 3 save'leri `~/Documents/The Witcher 3/` içinde.
- **Steam Cloud zaten çalışmış:** 16 Eki 17:33'te bizim Steam, bulut save'lerini `~/Documents/The Witcher 3/` içine indirmiş (`steam_autocloud.vdf` = Auto-Cloud işareti, `accountid 1053270386`). `localconfig.vdf`: Witcher 3 için `"last_sync_state" "synchronized"`. Cloud açık bırakıldı (ikinci güvence).
- **Karşılaştırma (SHA-1, `remotecache.vdf` içindeki değerlerle):** buluttaki 8 dosya (3 save `.sav` + `.png`/`.json` + `user.settings`) = GameToMac yereli = bizim `~/Documents`. Fark yalnızca sıra ve 1 sn'lik `localtime`. GameToMac'te buluta gitmeyen yerel ayarlar da var: `dx12user.settings`, `input.settings`, `profile.settings` (+ `.bak`).
- **Yedek:** `~/.kopru/backups/witcher3-saves-2026-10-17/` (1,6 MB, 27 dosya, `chmod -R a-w`):
  - `gametomac/The Witcher 3/` (GameToMac prefix'inden, okuma ile `cp -Rp`), `kopru-documents/The Witcher 3/`, `remotecache/` (iki Steam'in bulut kaydı), `SHA1SUMS`.
  - Doğrulama: `diff -r` her iki kaynakla aynı; `shasum -c SHA1SUMS` hatasız.
- **Karar:** `Documents` symlink'i şimdilik değiştirilmedi. Steam bulut kaydında dosyalar o yolda görünüyor; klasör taşınırsa Steam bunu "yerelde silindi" diye yorumlayıp buluttan da silebilir.
- **Bulgu: klonla GameToMac'in Witcher 3 yaması da gelmiş.** `bin/x64_dx12/amd_fidelityfx_loader_dx12.dll` Steam'in dosyası değil: GameToMac'in derlediği "ffxproxy" (59.904 bayt, içinde `ffxproxy attached`, `FFXPROXY_NO_DPI`). Orijinal `amd_fidelityfx_loader_dx12_orig.dll` adıyla yanında (SHA-256 `e2d85aa0…08aa`, 26.376 bayt).
  - GameToMac'in `WITCHER3.md` notu (okundu): D3DMetal, Witcher 3'te "stream output'lu, pixel shader'sız geometry shader" pipeline'ını derlerken Apple'ın `libmetalirconverter.dylib`'inde çöküyor; proxy o pipeline'ı atlıyor. Proxy, MIT lisanslı topluluk projesi `github.com/tholtman1-del/witcher3-crossover-fix`'ten derlenmiş.
  - CLAUDE.md gereği (GameToMac'ten dosya kullanılmaz; istisna yalnızca Steam oyun dosyaları) proxy kaldırılıp orijinal geri konacak. Önce orijinalle denenecek.
- **Witcher 3 güncellemesi:** 581 MB (`content_log`: `update prefetch finished : 581463998 bytes`), dün başlamış, Steam kapanınca yarıda kalmış. Steam yeniden açıldı: `scripts/kwine steam '…\steam.exe' -cef-disable-gpu`, log `~/.kopru/logs/steam-2026-10-17.log`.

## 2026-10-17 — Aşama 3: Witcher 3 güncellendi ve D3DMetal 4 ile oynanıyor ✅
- **Güncelleme (kullanıcı "Güncelle"ye bastı):** build 25646871 → **25773555**, 3 dk, `No Error`.
  - `content\metadata.store` için delta yaması başarısız oldu (`Invalid delta chunk … Corrupted`). Sebep: oyun bu dizini çalışırken kendisi yeniden yazıyor, yani yerel dosya Steam'in beklediği taban değil. Steam o parçaları tam indirerek kendisi düzeltti.
  - Staging ~53 GB'lık paket dosyasını yeniden yazdı → APFS klon paylaşımı o dosyalarda bitti: boş disk 635 → 585 GB.
- **GameToMac proxy'si kaldırıldı:** güncelleme ona dokunmamıştı. `rm amd_fidelityfx_loader_dx12.dll` + `mv …_orig.dll amd_fidelityfx_loader_dx12.dll` → SHA-256 `e2d85aa0…08aa` (Steam orijinali). GameToMac tarafındaki dosyalar değişmedi (ayrı klon, `ls` ile doğrulandı).
- **D3DMetal shader önbelleği ortak:** `$(getconf DARWIN_USER_CACHE_DIR)d3dm/<exe adı>/` (D3DMetal içinde `%s/d3dm/%s/shaders.cache/`). GameToMac'in `witcher3.exe/` önbelleği (14 MB) orada duruyordu.
  - `D3DM_EXE_OVERRIDE` adı değiştirirdi ama kullanılmadı: D3DMetal 4.0b3 içinde 54 oyuna özel exe profili var, **`witcher3.exe` de listede**. Ad değişirse Apple'ın Witcher 3 düzeltmeleri kapanır.
  - Bunun yerine önce yedek alındı: `~/.kopru/backups/d3dm-cache-witcher3-gametomac-2026-10-17/` (salt okunur, `diff -r` aynı).
  - D3DMetal'in diğer ayarları (`strings` ile bulundu): `D3DM_MAX_FPS`, `D3DM_SHOW_HUD_STATS`, `D3DM_NO_WINDOW`, `D3DM_VENDOR_ID/DEVICE_ID`, `D3DM_LOD_BIAS`, `D3DM_SUPPORT_DXR`, `D3DM_ENABLE_METALFX` …
- **Başlatma:** Steam açıkken `scripts/kwine steam '…\steam.exe' -applaunch 292030 --launcher-skip` (yöntem GameToMac `WITCHER3.md`'den; `--launcher-skip`, REDprelauncher'ın REDlauncher penceresini atlatıyor). Çalışan Steam komutu alıp kendisi başlatıyor; oyun Steam'in ortamını (D3DMetal açık) devralıyor.
  1. İlk denemede Steam **EULA** gösterdi. Kullanıcı kabul etti (`webhelper_js`: `accepted eula`) ama bekleyen başlatma devam etmedi. Komut yeniden gönderilince geçti.
  2. İlk açılış kurulumu: `SteamService.exe /installscript …\Steamworks Shared\runasadmin.vdf 292030` → `DXSETUP.exe /silent` (DirectX June 2010), sorunsuz.
  3. `redprelauncher.exe` → `witcher3.exe` (bin/x64_dx12). D3DMetal önbelleğe yazdı (`functions.data` 5,7 MB, `libraries.data` 5,3 MB…), oyun `~/Documents/The Witcher 3/` içine `dx12user.settings`, `profile.settings` oluşturdu.
- **Sonuç (çalıştı, kullanıcı gördü):** "oyun açıldı ve oynanıyor, 1080p'ye aldım ve 60 FPS limit verdim, akıcı." **GameToMac'in ffxproxy yaması olmadan**, orijinal Steam dosyalarıyla.
  - GameToMac'in çökme notu (libmetalirconverter, stream output'lu geometry shader) bu açılışta yaşanmadı. Neden: bilinmiyor. Olasılıklar: D3DMetal 4.0b3'teki `witcher3.exe` profili ya da daha yeni D3DMetal'in hatayı düzeltmiş olması; ya da o pipeline'ın oyunun ilerisinde derlenmesi. **Doğrulanmadı.**
- **Öğrenilen (kendi hatam):** `pgrep -f witcher3.exe` izleme betiğinin kendi komut satırını da yakalıyor (iki yanlış "başladı" alarmı). Doğrusu: `ps -axo pid=,command= | grep -v -E 'zsh|grep'`.
- **İlk oyun oturumu (çalıştı):** `witcher3.exe` 02:40:32 → 03:03:23 (~23 dk), düzgün kapandı. `CrashInfo.json` 0 bayt (açılışta oluşuyor, GameToMac'te de böyle), macOS DiagnosticReports'ta yeni rapor yok.
  - Save: oyun içinde checkpoint'ler + kullanıcının elle kaydı (`ManualSave_8559a_7ea4c000_c321df.sav`, 03:03).
  - Steam Cloud: `cloud_log.txt` → `Starting sync (up,AC Exit,)` → yeni `.sav/.png/.json` dosyaları `steamcloud-eu-fra…` adresine yüklendi → `Upload complete, result OK`. Çakışma/silme yok.
  - Bu ilk açılışta Steam VC++ yükleyicilerini de çalıştırdı (`AppData/Local/Temp/dd_vcredist_*.log`).
- **Denenmedi:** daha uzun oyun (ör. 1 saat+), ses/kumanda ayrıca sorulmadı, FPS sayısal ölçülmedi (kullanıcı "akıcı" dedi), GameToMac'in yeni save'leri buluttan çekmesi.

## 2026-10-17 — Plan değişikliği: yeni oyunlar rafa, önce uygulama (Aşama 5)
- Kullanıcı RDR2'yi sordu (Elden Ring'den ucuz). Bulgu (GameToMac `games.json` + `RedDead.swift` okundu): RDR2 için Rockstar Games Launcher zorunlu (CEF tabanlı; GameToMac'te ayrı Wine yaması `rockstar-cef.patch` + başlatıcıya SwiftShader), Rockstar hesabı ve Steam bağlantısı gerekiyor, `system.xml`'de API `kSettingAPI_DX12` yapılmalı (bizim Wine'da Vulkan yok). ~120 GB.
- **Karar (kullanıcı):** yeni oyunlar şimdilik rafta; önce kendi uygulamamız.

## 2026-10-17 — Aşama 5a: Köprü.app ilk sürüm (SwiftUI) ✅
- **Seçimler:** SwiftUI + Swift Package (`App/Package.swift`; Xcode projesi yok, düz metin, `open App/Package.swift` ile Xcode'da da açılır). `.app` paketi elle: `scripts/build-app.sh [--open]` → `build/Köprü.app` (`Info.plist` + `Contents/MacOS/Kopru` + ad-hoc imza). Xcode 27.1 / Swift 6.4, ek kurulum yok. `.gitignore`: `build/`, `App/.build/`.
- **Dosyalar (`App/Sources/Kopru/`):**
  - `Paths.swift`: `~/Library/Application Support/Kopru` altındaki yollar.
  - `VDF.swift`: Steam'in KeyValues biçimi için küçük okuyucu (`"anahtar" "değer"` / `{ }`).
  - `SteamLibrary.swift`: `steamapps/appmanifest_*.acf` → kurulu oyunlar (ad, klasör, boyut, `StateFlags`: 4 kurulu, 2 güncelleme gerekli); görseller `appcache/librarycache/<appid>/…/library_hero.jpg, library_capsule.jpg, logo.png`. `GameProfiles`: 292030 → `--launcher-skip`. 228980 (Steamworks Common Redistributables) gizli.
  - `Wine.swift`: `kwine`'ın (cx) ortam değişkenleri Swift'te; `launch` beklemez, çıktı `logs/<ad>-<tarih>.log`'a eklenir; `killAll` = `wineserver -k`.
  - `ProcessScanner.swift`: hangi Windows programı **bizim** prefix'te çalışıyor? (3 sn'de bir)
  - `AppModel.swift` (durum + eylemler), `ContentView.swift` (arayüz), `KopruApp.swift`, `WindowSnapshot.swift`.
- **Özellikler:** oyun listesi (kapak), ayrıntı (büyük görsel, logo, boyut, AppID, ek seçenekler), **Oyna** (Steam kapalıysa `steam.exe -cef-disable-gpu -applaunch <id> …`, açıksa yalnızca `-applaunch`), Steam'i Aç/Kapat (`-shutdown`), Zorla Kapat (onay penceresiyle `wineserver -k`), prefix/oyun/günlük klasörünü göster, "Steam açık" ve "Çalışıyor" göstergeleri.
- **Süreç tanıma (öğrenilen):**
  - Wine süreçleri `ps`'te yalnızca Windows yolu gösteriyor (`C:\Program Files (x86)\Steam\steam.exe`); GameToMac'in Steam'i de aynı. `ps -E` ortam değişkenlerini **göstermiyor** (Wine komut satırı alanının üzerine yazıyor).
  - Çözüm: `lsof -a -p <pid'ler> -d txt -Fn` → belleğe yüklenmiş `.exe`'nin gerçek Mac yolu, ör. `…/prefixes/steam/drive_c/Program Files (x86)/Steam/steam.exe`. Yol bizim prefix'teyse süreç bizim.
  - Yan bulgu: `wineserver`'ın çalışma klasörü `/tmp/.wine-501/server-<aygıt>-<inode>`; sayılar prefix klasörünün `stat` değerleri (`100000e-961837`). Wine prefix → sunucu eşleşmesini böyle yapıyor.
- **Hata ve düzeltme (kullanıcının ekran görüntüsüyle):** kenar çubuğu daralmış, satır soldan kesik. Sebep: büyük görsel `scaledToFill`; görsel kendini pencereden geniş bildirdi, `.clipped()` yalnızca çizimi kırpıyor, yerleşimi değil → ayrıntı sütunu genişledi, kenar çubuğu sıkıştı. Düzeltme: sabit boyutlu `Color.clear` + görsel `.overlay` ile.
- **Kendi penceresinin görüntüsü:** `screencapture -l` ekran kaydı izni istiyor (Terminal'e verilirse Terminal yeniden başlamalı → oturum kapanır). Bunun yerine uygulama kendini çiziyor: `open build/Köprü.app --args --snapshot <dosya.png>` → 5 sn sonra pencereyi PNG kaydeder (`NSView.cacheDisplay`, izin gerekmez).
- Not: `pgrep -f 'Köprü'` eşleşmiyor ("ü" farklı Unicode biçiminde saklanıyor); `ps … | grep 'MacOS/Kopru'` kullan.
- **Doğrulanan:** derleme uyarısız; arayüz düzgün (kendi görüntüsüyle); Steam açıkken "Steam açık" doğru; manifest/görseller doğru okundu.
- **Denenmedi:** Oyna / Steam'i Aç / Kapat / Zorla Kapat düğmelerinin uygulamadan kullanımı.
- **Uygulama simgesi (kullanıcı istedi):** gün batımında suyun üstünde tek kemerli, hafif sivri (Mostar tarzı) taş köprü + yansıması; "bir yakadan öbürüne geçiş". Windows/Apple logoları bilerek kullanılmadı (marka).
  - Kodla çiziliyor: `tools/app-icon/make-icon.swift` (CoreGraphics, 1024 px; Apple ızgarası: 824 px gövde, köşe ~185, gölge). `tools/app-icon/build.sh` → `sips` ile 16–1024 boyutlar + `iconutil` → `App/Resources/AppIcon.icns` (+ `AppIcon-1024.png`).
  - İlk taslak kalın ve yuvarlaktı, yansımasıyla bir **göze** benziyordu. Düzeltme: kemer büyütüldü, kübik eğrilerle tepesi sivriltildi, korkuluk çizgisi eklendi, yansıma %20'ye indirildi. 32 px'te de okunuyor.
  - `build-app.sh` simgeyi `Contents/Resources/`'a kopyalıyor; `Info.plist`: `CFBundleIconFile = AppIcon`.

## 2026-10-17 — Wine: küçük argüman hatasının taranması ve genel düzeltme (yama 0005) ✅
Kullanıcı oyun testlerini durdurup "kodda eksik kalanları yap" dedi. TASKS'taki 4. madde.
- **Araç:** `tools/abi-scan/scan_small_args.py <wine-kökü> [--patch <çıktı>]`.
  - `ntsyscalls.h` / `win32syscalls.h` (ALL_SYSCALLS64) → syscall adları; `dlls/ntdll/unix/*.c` ve `dlls/win32u/*.c` içinde gövdeli tanımlar; 32 bitten küçük tipte (BOOLEAN, UCHAR, WORD, WCHAR, BYTE, ATOM, LANGID…) işaretçi olmayan parametreler.
  - Tuzaklar (düzeltildi): CrossOver bazılarını `GPT_IMPORT(Ad)` ile tanımlıyor; `win32u/main.c` Windows tarafı giriş kapısı (`SYSCALL_API`, gerçek kod değil); bazı tanımlarda `)` ile `{` arasında yorum var.
  - Kapsam: 738 tanım (ntdll 257 + win32u 481; tanımsızlar yalnızca otomatik taslaklar/ARM64EC). **47 riskli** (ntdll 39, win32u 8), ör. `NtWaitForSingleObject/MultipleObjects` (alertable), `NtDelayExecution`, `NtCreateEvent` (state), `NtCreateMutant` (owned), `NtLockFile` (dont_wait, exclusive), `NtQueryDirectoryFile`, `NtCreateThread` (suspended), `NtAdjustPrivilegesToken`, `NtUserVkKeyScanEx` (WCHAR).
- **CrossOver'ın D3DMetal köprüsü (öğrenilen):** `GPT_ABI_WRAPPER` (montaj) çağıranın dönüş adresine bakıyor: libd3dshared içinden geliyorsa `msthunk_Ad`'a (`__attribute__((ms_abi))`, Windows kuralı, küçük argümanları doğru okur), değilse `sysv_Ad`'a gidiyor. Windows programlarının syscall'ları `sysv_` yoluna düşüyor → onlar da riskli.
- **Yama 0005** (`patches/crossover-26.3/0005-ntdll-win32u-clean-small-syscall-args.patch`, betikle üretildi, elle düzenlenmez): `unix_private.h` ve `win32u_private.h`'ye `KOPRU_CLEAN_SMALL_ARG(x)` (volatile, kendi genişliğinde yaz-oku) + 46 fonksiyonun başına 52 satır. `NtQueryDirectoryObject` 0004'te olduğu için atlandı.
- **Derleme:** `build-crossover-wine.sh patch` + `build` (5 sn, yalnızca değişenler). **Makine koduyla doğrulandı:** 47 fonksiyonun hepsinde argüman önce `movb/movw` ile belleğe yazılıp tek bayt/kelime olarak okunuyor (ör. `NtDelayExecution`: `movb %dil,-0x38(%rbp)` → `cmpb $0x0,-0x38(%rbp)`).
- **Kurulum:** Steam `-shutdown` ile kapatıldı → `install` → kurulu `ntdll.so` = derlenen. Steam yeniden açıldı: `ConnectionCompleted` → `LogOnResponse 'OK'`, EConnect yağmuru yok. (Gerileme yok; çalıştı.)
- **Denenmedi:** Witcher 3'ün yeni yamalı Wine ile açılması (kullanıcı oyun testini erteledi). Bu sınıftaki hatanın başka bir oyunda gerçekten bir sorunu çözdüğü henüz gözlenmedi; önleyici düzeltme.
- **Kapsam dışı kalan:** syscall olmayan Unix çağrıları (`__wine_unix_call`; parametreler bellekte, güvenli). D3DMetal'in kendi çağrıları (ms_abi köprüsü). 32-bit (i386/WoW64) yol ayrıca incelenmedi; wow64 thunk'ları 64-bit syscall'ları çağırdığı için aynı düzeltmeden geçiyor.

## 2026-10-17 — Aşama 5b: uygulama — ayarlar, çoklu kütüphane, testler ✅
- **Ayarlar (⌘,):** `LaunchSettings` (UserDefaults'ta JSON): FPS göstergesi → `MTL_HUD_ENABLED=1` (Apple Metal performans HUD'u), FPS sınırı (30/40/60/120) → `D3DM_MAX_FPS` (GPTK Read Me: "uygulamanın kare hızını belirtilen sayıyla sınırlar").
  - Oyun ortamı **Steam'den miras alıyor**, bu yüzden ayar değişince üstte turuncu şerit + "Steam'i Yeniden Başlat" (`-shutdown` → kapanana kadar bekle (en fazla ~2 dk) → yeni ortamla aç). Uygulama Steam'i hangi ayarla açtığını hatırlıyor; Steam dışarıdan (kwine) açıldıysa varsayılanla açıldığını varsayıyor.
  - `Wine.environment` dışarıdan gelen `MTL_*` değişkenlerini de siliyor.
- **Birden fazla Steam kütüphanesi:** `libraryfolders.vdf` → Windows yolu (`D:\SteamLibrary`) → `Paths.unixPath`: `<prefix>/dosdevices/d:` symlink hedefi + kalan yol. `InstalledGame.commonDir/installURL`; süreç tanıma da bunu kullanıyor.
- **Yan bulgu (değiştirilmedi):** Wine, takılı diskleri `d:`–`g:` yapmış, `z:` → `/` (Mac'in tamamı). Windows programları Mac'teki bütün dosyaları görebiliyor. GameToMac bunu kaldırıyor ("no Z: host mapping"). Sonra değerlendirilecek.
- **Testler (Swift Testing, `cd App && swift test`):** 15 test / 4 grup, hepsi geçti. VDF (iç içe, `\\` kaçışı, yorum, bozuk giriş); Steam kütüphanesi (geçici klasörde sahte prefix: manifestler, gizli 228980, sıralama, görseller, `D:` ikinci kütüphane, C:'nin iki kez sayılmaması); süreç tanıma (`ps`/`lsof` çıktısı ayrıştırma, GameToMac prefix'inin tanınmaması, "Game"/"Game 2" önek çakışması); ayarlar (ortam, kaydet/oku, Wine ortamı). `ProcessScanner` bunun için saf ayrıştırma fonksiyonlarına bölündü.
- **Gerçek veriyle kontrol (kendi pencere görüntüsü):** Witcher 3 tek kez listeleniyor, "Steam açık" doğru, ayarlar varsayılanken şerit yok.
- **Denenmedi (kullanıcı oyun testlerini erteledi):** Oyna/Steam'i Kapat/Zorla Kapat/Yeniden Başlat düğmeleri; FPS göstergesinin oyunda görünmesi ve FPS sınırının etkisi.
- README'ye "Kullanım" bölümü eklendi.

## 2026-10-17 — Git: ilk commit + gizli GitHub deposu ✅
- Kullanıcı istedi: yerel commit + GitHub. Depo: **https://github.com/oktubedirhan/kopru** (private), dal `main`, `origin` ayarlı.
- İlk commit `263a7d4`: 42 dosya (betikler, yamalar 0001–0005, tools kaynakları, App + testler, docs, simge).
- Depoya girmeyenler (`.gitignore`): `build/`, `App/.build/`, `tools/**/*.exe` (build.sh ile yeniden üretilir). Wine runtime, D3DMetal (Apple lisansı), oyunlar, save'ler zaten repo dışında (`~/Library/Application Support/Kopru/`).
- Push öncesi gizli bilgi taraması yapıldı (şifre/anahtar yok). Notlarda Steam hesap numarası (accountid) geçiyor; depo gizli.
- Bundan sonra: her çalışan aşamadan sonra `git add -A && git commit` + `git push`.

## 2026-10-17 — Plan (onaylandı) ve B1/B3: Wine ayarları tek kaynakta, README ✅
- Kalan işler planı (kullanıcı onayladı): A kullanıcı testleri · B sağlamlaştırma (B1 tek kaynak, B2 `Z:` kaldırma, B3 README) · C uygulama (C1 profil dosyası, C2 doğrudan başlatma, C3 otomatik save yedeği, C4 günlük görüntüleyici, C5 prefix sihirbazı) · D araştırmalar (nested exception, 32-bit, DX9, Vulkan) · E yeni oyunlar (rafta). Sıra: B1 → B3 → B2 → C1 → C2 → C3 → C4 → C5.
- **B1:** `config/wine.env` = cx runtime ortam değişkenlerinin tek kaynağı. Biçim: `A=değer`, `A?=değer` (kwine'da dışarıdan verilen kazanır), `[all]`/`[d3dmetal]`, `${RUNTIME}` `${GPTK}` `${PREFIX}`.
  - `scripts/kwine` dosyayı okuyor (stable runtime ayrı, değişmedi). `build-app.sh` dosyayı `Contents/Resources/wine.env`'e kopyalıyor; `WineEnvFile.swift` okuyor; paket içinde yoksa uygulama "Kurulum eksik" diyor.
  - **Doğrulama:** eski ve yeni kwine'ın ortamı karşılaştırıldı (son satır `export -p` ile değiştirilerek): varsayılan 9 değişken, `--no-d3dmetal` 7, `WINEMSYNC=0` dışarıdan, stable 3 → hepsi AYNI. (İlk karşılaştırmada stable'da `gameoverlayrenderer` eksik çıktı, düzeltildi.)
  - Öğrenilen: `/usr/bin/env` ile yazdırınca `DYLD_*` görünmüyor, SIP siliyor; kabuğun kendi `export -p`'si siler değil.
  - **Testler:** 18/18. Yeni `WineEnvFileTests`: ayrıştırma, depodaki dosya, **kwine eşlik testi** (gerçek kwine'ı `export -p` ile çalıştırıp `Wine.environment` ile karşılaştırıyor; D3DMetal açık/kapalı). Kasıtlı bozma denemesi (kwine'a `WINEMSYNC=5`) testi düşürdü → test gerçekten yakalıyor; kwine geri alındı.
  - Uygulama yeniden derlendi, paket içinde `wine.env` var, normal açılıyor (kendi görüntüsü).
- **B3:** README yol haritası durum sütunlu (1–3, 6 ✅; 4 rafta; 5 sürüyor), "Çalışan oyun: Witcher 3".

## 2026-10-17 — B2: `Z:` → `/` kaldırıldı + bulunan Wine hatası (yama 0006) ✅
- **Neden:** `prefixes/steam/dosdevices/z:` → `/`: Windows programları Mac'in tüm dosyalarını görüyordu (`cmd /c dir Z:\` → Applications, bin, etc…). GameToMac de kaldırıyor.
- **Araştırma (kaynak):** `z:` yalnızca `server.c: setup_config_dir()` içinde, `dosdevices` klasörü **ilk kez** oluşturulurken yaratılıyor → kaldırınca geri gelmiyor. `file.c`'deki tek kullanım kozmetik (yol kısaltma). `d:`–`h:` ise takılı diskler için mountmgr'ın her açılışta dinamik oluşturduğu bağlantılar (ayrı konu, dokunulmadı). `Documents` vb. Mac bağlantıları Steam Cloud için bilerek korundu.
- **Uygulama:** Steam `-shutdown` → `rm dosdevices/z:` (geri almak: `ln -s / dosdevices/z:`).
- **Ortaya çıkan hata:** Mac yolundan program başlatmak (`kwine steam /…/dxgi-probe.exe`, test araçlarımız böyle çalışıyor) **SIGSEGV, çıkış 139**.
  - macOS çökme raporu (`~/Library/Logs/DiagnosticReports/wine-*.ips`): `init_startup_info+3972`, `rip` = ntdll.so+`0xec40`, adres 0x0. Makine kodu: `get_full_path+0x290` → `cmpw $0x0,(%r15,%rax)` = `init_unicode_string(nt_name, ret)` ile `ret` NULL.
  - **Kök neden:** `find_drive_nt_root()` yol hiçbir sürücünün altında değilse `STATUS_SUCCESS` döndürüp sonucu NULL bırakıyor. `unix_to_nt_file_name()` bunu kontrol edip `\??\unix\…` yoluna düşüyor; `get_full_path()` kontrol etmiyor. `z:` → `/` varken her yol Z:'ye düştüğü için hiç görülmüyordu. (Upstream Wine'da da aynı olabilir; doğrulanmadı.)
  - **Yama 0006** (`patches/crossover-26.3/0006-ntdll-get_full_path-unix-path-without-drive.patch`): `get_full_path` Mac yolları için `unix_to_nt_file_name()` kullanıyor.
- **Doğrulama (çalıştı):** derleme + kurulum; `dxgi-probe` Mac yolundan → AMD Compatibility Mode, D3D11 FL 12.1, D3D12 TAMAM, çıkış 0; `if exist Z:\` → "Z YOK"; Steam açılış → `LogOnResponse 'OK'` (22 sn), EConnect 0; Wine çalıştıktan sonra `z:` yeniden oluşmadı.
- **Zararsız yeni uyarı:** terminal Mac klasöründeyken `cmd` "could not open working directory unix\…, starting in the Windows directory" diyor (Mac klasörü artık bir sürücüye eşlenmiyor).
- **Denenmedi:** Witcher 3'ün `z:` olmadan açılması (kullanıcı testi A4 ile birlikte). Diğer test prefix'lerinde (`test`, `gptk-test`, `cx-test`) `z:` duruyor; yalnızca `steam` prefix'i değişti. C5 (prefix sihirbazı) yeni prefix'lerde `z:`'yi otomatik kaldırmalı.

## 2026-10-17 — Hedef oyun değişti: Elden Ring yerine Batman: Arkham Knight (araştırma)
- Kullanıcı kararı: GameToMac kütüphanesinden bağımsız ilk yeni oyun **Batman: Arkham Knight** (Steam AppID 208650). Elden Ring rafta.
- Araştırma (Steam mağaza API'si + ProtonDB API; PCGamingWiki ve CodeWeavers sayfaları 403 verdi):
  - DirectX 11, 64-bit, tek oyunculu, Steam Cloud var, ek hesap/başlatıcı yok. En az 45 GB (DLC ile ~50–55 GB). Fiyat $3.99 (2026-10-17).
  - **`drm_notice: Denuvo Antitamper`**. Denuvo kopya koruması, anti-cheat değil; kırılmayacak/atlatılmayacak. Wine altında çalışıyor: ProtonDB **Platinum**, 333 rapor, güven "strong". Dikkat: Denuvo etkinleştirme sınırı → oyunu tek prefix'te (`steam`) tut, runtime/prefix değiştirmekten kaçın; ilk açılışta internet.
  - CodeWeavers, CrossOver 23.5 (2023) duyurusunda D3DMetal ile çalışan oyunlar arasında saydı (üretici iddiası, bağımsız test değil).
- Kullanıcı şimdilik almadı; kodlamaya (C1/C2) devam.

## 2026-10-17 — C1 + C2: oyun profilleri dosyada, doğrudan başlatma ✅ (kod; oyunla denenmedi)
- **C1:** `App/Resources/profiles.json` (pakete kopyalanıyor) + isteğe bağlı `~/Library/Application Support/Kopru/profiles.json` (alan alan ezer; ortam değişkenleri birleşir; bozuksa uyarı + varsayılanlar). Alanlar: `name, steamArguments, executable, arguments, launchMode (steam|direct), environment, saveDirectory, notes`. Koddaki `GameProfiles.extraArguments` sözlüğü kaldırıldı.
  - Profiller: Witcher 3 (`--launcher-skip`, `bin/x64_dx12/witcher3.exe`, save `%USERPROFILE%\Documents\The Witcher 3`), Batman AK (`Binaries/Win64/BatmanAK.exe` — **doğrulanmadı**, oyun kurulu değil).
  - `Paths.windowsUserProfile` (drive_c/users'ta Public dışı klasör → `C:\users\crossover`), `Paths.resolve(windowsPath:)` (`%USERPROFILE%` + dosdevices).
- **C2:** `LaunchPlan` (saf hesap): yol = kullanıcı seçimi > profil > Steam; exe yolu yoksa Steam.
  - Steam yolu: `steam.exe [-cef-disable-gpu] -applaunch <id> <steamArguments>`, çalışma klasörü Steam klasörü, grafik = genel ayar (ortam Steam'den miras).
  - Doğrudan yol: `wine <exe Mac yolu> <arguments>`, çalışma klasörü exe klasörü, ortam += profil + `SteamAppId`/`SteamGameId`, grafik = oyuna özel (varsa) yoksa genel. Steam kapalıysa önce açılır, görünmesi beklenir (≤90 sn) + 15 sn giriş payı.
  - `GameSettings` (UserDefaults): oyun başına başlatma yolu + oyuna özel grafik. Arayüz: ayrıntıda "Başlatma: Steam üzerinden / Doğrudan" + doğrudan modda "Bu oyuna özel grafik ayarı" (FPS göstergesi, FPS sınırı); açıklama metni Cloud eşitlemesinin atlandığını söylüyor; profil notları gösteriliyor.
  - `Wine`: `extraEnvironment`; çalışma klasörü parametre, varsayılan `drive_c` (z: kaldırıldığından prefix klasörü artık eşlenmiyor); `PWD` çalışma klasörüyle aynı (Wine `get_initial_directory` önce PWD'ye bakıyor).
- **Doğrulama:** 25/25 test (yeni: profil dosyası, kullanıcı ezmesi/bozuk dosya, `%USERPROFILE%`, yol seçimi, Steam/doğrudan planları, Wine ek ortamı). Gerçek Wine'da çalışma klasörü eşlemesi: Steam klasörü → `C:\Program Files (x86)\Steam`, exe klasörü → `C:\…\The Witcher 3\bin\x64_dx12`. Uygulama görüntüsü: Başlatma seçimi ve profil argümanları görünüyor.
- **Denenmedi:** doğrudan başlatma ile gerçek bir oyun (Witcher 3 ya da Batman) — `steam_api`'nin SteamAppId ile açık Steam'e bağlanması, doğrudan modda Steam Cloud'un kapanışta eşitleyip eşitlemediği, oyuna özel FPS ayarının etkisi. Kullanıcı testine eklendi.

## 2026-10-17 — Batman sırası: önce Arkham Asylum (hazırlık)
- Kullanıcı Arkham Knight'ı satın aldı (henüz indirilmedi). Sonra seriye çıkış sırasıyla başlamak istedi: **Asylum (2009) → City (2011) → Origins (2013) → Knight (2015)**. İlk hedef Asylum.
- Köprü ve Steam kullanıcı isteğiyle yeniden başlatıldı (Steam `-shutdown` ~8 sn, yeniden giriş ~20 sn).
- Araştırma (Steam API + ProtonDB):
  - **Asylum GOTY** (AppID 35140): $2.99, ~8 GB, DRM yok (eski GFWL kaldırılmış), **DirectX 9, 32-bit**. ProtonDB Gold (en iyi Platinum), 492 rapor.
  - **City GOTY** (200260): $3.99, 17 GB, DRM yok, DX9.0c (+DX11 modu). ProtonDB Gold/Platinum, 277 rapor.
- **Teknik anlamı:** D3DMetal paketinde `d3d9` yok (yalnızca 10/11/12) → Asylum'da çeviri Wine'ın **wined3d**'si: DX9 → OpenGL → (Apple'ın OpenGL'i Metal üstünde). Bizde wined3d'nin OpenGL yolu çalışıyor (Aşama 2b, `--no-d3dmetal` ile DX11 FL 10.1). 32-bit (WoW64) yolu **ilk kez** denenecek (plan D2). FPS sınırı (`D3DM_MAX_FPS`) wined3d'de etkisiz; Metal HUD OpenGL'de görünür mü bilinmiyor.
- Profiller: `directX` alanı eklendi; Asylum (35140, `Binaries/ShippingPC-BmGame.exe`, doğrulanmadı), City (200260, alınmadı), Knight (DX11). Arayüzün "Grafik" satırı artık DirectX sürümüne göre: DX9 → "wined3d (OpenGL)", 10–12 → "D3DMetal 4". 26/26 test.
- **Sıradaki:** kullanıcı Asylum'u alıp Köprü'nün Steam'inden kurar (~8 GB) → exe/launcher yolunu doğrula → ilk açılış (BmLauncher, DX9/wined3d, 32-bit).

---
## 📌 Yeni oturum için özet (2026-10-17 güncellemesi)
- Witcher 3 (build 25773555) **çalışıyor**: Steam açıkken `scripts/kwine steam 'C:\Program Files (x86)\Steam\steam.exe' -applaunch 292030 --launcher-skip`. Orijinal Steam dosyaları, proxy yok.
- Save'ler: `~/Documents/The Witcher 3/` (prefix'in Documents'ı Mac'e symlink). Yedek: `~/.kopru/backups/witcher3-saves-2026-10-17/`. Steam Cloud açık ve eşit.
- GameToMac'teki Witcher 3 kopyası: kullanıcı, bizde uzun oynamada sorun olmadığı görülünce GameToMac arayüzünden silebilir (~53 GB açılır). Bizim klon etkilenmez.
- İlk oturum: 23 dk oynandı, elle kayıt yapıldı, düzgün kapandı, Cloud'a yükleme `result OK`. Uzun oyunda çökme olursa crashreporter'a ve libmetalirconverter'a bak.
- Yeni oyunlar (RDR2/Elden Ring) kullanıcı kararıyla rafta. Aşağıdaki 4. madde (küçük argüman taraması) **yama 0005 ile yapıldı**.
- **Uygulama:** `scripts/build-app.sh --open` → `build/Köprü.app`. Testler `cd App && swift test` (15/15). Kodu `App/Sources/Kopru/`.
- **Sıradaki adaylar:** (a) uygulama düğmelerinin kullanıcıyla denenmesi (Oyna, Kapat, Yeniden Başlat, FPS göstergesi); (b) 5. madde: Steam güncellemesi sonrası "nested exception" donması (yeniden üretmek için Steam güncellemesi gerekiyor); (c) `z:` → `/` bağlantısını kaldırmayı değerlendirmek; (d) `scripts/kwine` ile `Wine.swift` aynı ortam değişkenlerini ayrı ayrı tutuyor (biri değişirse diğeri de güncellenmeli).

## 📌 Yeni oturum için özet (2026-10-16 sonu)

**Çalışan durum:**
- Runtime: `~/.kopru/runtime/crossover-26.3` (= `~/Library/Application Support/Kopru/...`): CrossOver 26.3 Wine 11.0, kendimiz derledik + D3DMetal 4.0b3 (kanca: `tools/d3dmetal-hook`).
- Derleme: `scripts/build-crossover-wine.sh [deps|patch|configure|build|install|all]`. Kaynak `~/.kopru/src/crossover-26.3/`.
- Yamalar `patches/crossover-26.3/`: 0001/0002 Vulkan'sız derleme ve log taşması, 0003 steamwebhelper ek seçenekleri (siyah ekran), 0004 NtQueryDirectoryObject BOOLEAN (Steam bağlanamıyordu).
- Başlatıcı: `scripts/kwine [-r cx|stable] [--no-d3dmetal] <prefix> <program>`.
- Steam: `scripts/kwine steam 'C:\Program Files (x86)\Steam\steam.exe' -cef-disable-gpu`. Giriş yapıldı, mağaza çalışıyor.
- Witcher 3 `prefixes/steam` içinde yüklü (APFS klonu), "Update Required".

**Sıradaki yapılacaklar (sırayla):**
1. Witcher 3'ü Steam'den güncelle (kullanıcı "Update"e basar).
2. **Save yedeği:** GameToMac prefix'indeki `drive_c/users/crossover/Documents/The Witcher 3` klasörünü salt okunur kopyayla `~/.kopru/backups/witcher3-saves-<tarih>/` altına al. Steam Cloud ayarını kontrol et.
3. Witcher 3'ü D3DMetal ile başlat (önce DX12, sonra gerekirse DX11). FPS, görüntü, ses, kumanda/klavye kontrol edilir. Log: `~/.kopru/logs/`.
4. Aynı sınıf hata taraması: ntdll'de BOOLEAN argüman alan diğer syscall'lar (NtQueryDirectoryFile, NtWaitFor*, NtDelayExecution, NtAdjustPrivilegesToken…) için yama 0004 yaklaşımını genelleştirmeyi değerlendir.
5. Steam güncellemesinden sonra yeniden başlarken oluşan `nested exception on signal stack` (ntdll.so içinde, adres 0x2086f31c9) donmasını araştır.
6. Aşama 4: Elden Ring (satın alınınca): offline, `SteamAppId=1245620`, VC++ 2019 + DirectX June 2010.

**Bilinen pratik notlar:**
- Uzun çalışan programlarda `perl alarm` süre sınırı kullanma: Wine'da `steam.exe`'yi öldürüyor.
- Steam'i kapatmak/takılınca: `WINEPREFIX=~/.kopru/prefixes/steam WINEMSYNC=1 ~/.kopru/runtime/crossover-26.3/bin/wineserver -k`.
- Steam açıkken `install` yapma (çalışan `ntdll.so`'nun üzerine yazılır).
