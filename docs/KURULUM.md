# Köprü'yü başka bir Mac'e kurmak

Bu rehber, Köprü'yü sıfırdan bir Apple Silicon Mac'e kurmanın adımlarını anlatır. Adımların hepsi bu projenin geliştirildiği
Mac'te (M2 Pro, macOS 27.0.1) yapıldı; başka bir Mac'te **henüz denenmedi**.

> Köprü kişisel kullanım içindir; kaynak kod açık, hazır paket dağıtılmaz. Oyunlar kendi Steam hesabından; D3DMetal'i (Apple'ın Game Porting Toolkit'i)
> herkes Apple'dan **kendisi** indirir, kopyası paylaşılmaz.

## 0. Gerekenler

| | |
|---|---|
| Mac | Apple Silicon (M1 ve sonrası), macOS 15 veya üstü |
| Disk | Kurulum ~5 GB (derleme dahil ~10 GB) + oyunlar |
| Hesaplar | Apple Developer (ücretsiz hesap yeter), Steam |
| Araçlar | Xcode (App Store'dan) veya Xcode Command Line Tools, Homebrew |

Bütün Köprü dosyaları `~/Library/Application Support/Kopru/` altında durur. Kısa adı `~/.kopru` (derleme script'i bu
kısayolu kendisi oluşturur; "Application Support"taki boşluk derleme araçlarını bozduğu için).

## 1. Temel araçlar

```sh
# Rosetta 2: Intel (x86_64) kodunu Apple çipinde çalıştırır. Wine ve oyunlar bunsuz çalışmaz.
softwareupdate --install-rosetta --agree-to-license

# Xcode'u App Store'dan kur (Swift 6 ve clang için), sonra bir kez aç ve lisansı kabul et.
xcode-select -p   # bir yol yazmalı

# Homebrew paketleri: yalnızca derleme sırasında kullanılır.
brew install bison gnutls freetype
```

- `bison`: macOS'taki sürüm (2.3) Wine için eski.
- `gnutls`, `freetype`: yalnızca başlık dosyaları için; kütüphanelerin Intel sürümleri 4. adımda ayrıca geliyor.

## 2. Projeyi indir

```sh
mkdir -p ~/Documents/Codex && cd ~/Documents/Codex
git clone https://github.com/oktubedirhan/kopru.git Kopru
cd Kopru
```


## 3. Wine runtime — iki yol

**Wine:** Windows programlarının macOS'ta çalışmasını sağlayan katman. Köprü, CrossOver 26.3'ün açık kaynak Wine'ını
kendi yamalarıyla (`patches/crossover-26.3/`) derleyip kullanır.

### Yol A (kolay): Kendi diğer Mac'inden kopyala

Kendi Mac'lerin arasında, derlenmiş runtime klasörünü kopyalamak derlemeyle aynı sonucu verir:

```sh
# Eski Mac'te:
cd ~/Library/Application\ Support/Kopru && tar czf ~/Desktop/kopru-runtime.tgz runtime/crossover-26.3
# Yeni Mac'te (dosyayı AirDrop vb. ile taşıdıktan sonra):
mkdir -p ~/Library/Application\ Support/Kopru && cd ~/Library/Application\ Support/Kopru
tar xzf ~/Desktop/kopru-runtime.tgz
ln -s ~/Library/Application\ Support/Kopru ~/.kopru
```

Sonra 4. adıma geç. D3DMetal kancası (5. adım) ve Wine Mono (6. adım) bu klasörün içinde geldiği için o iki adım
atlanabilir; tekrar yapmak da zararsız.

### Yol B: Kaynaktan derle (~30–60 dk)

Önce derleme için gereken üç şeyi `~/.kopru` altına koy:

1. **CrossOver kaynağı** (149 MB): `https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz`
   ```sh
   mkdir -p ~/.kopru/src/crossover-26.3 ~/.kopru/downloads && cd ~/.kopru/downloads
   curl -LO https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz
   tar xzf crossover-sources-26.3.0.tar.gz -C ~/.kopru/src/crossover-26.3 sources/wine
   ```
2. **llvm-mingw** (Windows tarafı DLL'lerini Mac'te derleyen derleyici, 124 MB): GitHub `mstorsjo/llvm-mingw` sürümlerinden
   `llvm-mingw-20261006-ucrt-macos-universal.tar.xz` → `~/.kopru/toolchains/` içine aç.
3. **Intel FreeType/GnuTLS kütüphaneleri:** Gcenx'in `game-porting-toolkit-3.0-3.tar.xz` paketinden (239 MB;
   `apple/homebrew-apple` tarifinin indirdiği dosya). Paketteki uygulamanın `Contents` klasörü
   `~/.kopru/runtime/gptk-wine-3.0-3/Contents` olacak şekilde aç; script kütüphaneleri
   `…/gptk-wine-3.0-3/Contents/Resources/wine/lib` içinde arar. Bu paketten **yalnızca** bu kütüphaneler alınır;
   içindeki D3DMetal kullanılmaz.

Sonra:

```sh
cd ~/Documents/Codex/Kopru
scripts/build-crossover-wine.sh all    # deps → yamalar → configure → derleme → kurulum
```

Sonuç: `~/.kopru/runtime/crossover-26.3/` (~500 MB). Hata olursa ayrıntı `~/.kopru/src/crossover-26.3/build/make.log`
içinde; adımlar tek tek de çalıştırılabilir (`deps`, `patch`, `configure`, `build`, `install`).

## 4. D3DMetal (Apple Game Porting Toolkit 4.0 beta 3)

**D3DMetal:** Oyunların DirectX 11/12 çağrılarını Mac'in grafik sistemi Metal'e çeviren Apple kütüphanesi. Lisansı
gereği herkes kendisi indirir.

1. `https://developer.apple.com/download/all/?q=game%20porting%20toolkit` → **Game Porting Toolkit 4.0 beta 3** dmg'si.
2. dmg'yi aç, içindeki `redist` klasörünü, `Read Me` ve `License` dosyalarıyla birlikte kopyala:
   ```sh
   mkdir -p ~/.kopru/gptk/4.0-beta3
   cp -R "/Volumes/<dmg adı>/redist" ~/.kopru/gptk/4.0-beta3/
   ```
   Doğru yer: `~/.kopru/gptk/4.0-beta3/redist/lib/{external,wine}`.

## 5. D3DMetal kancası

Wine'ın, DirectX DLL'lerini D3DMetal klasöründen yüklemesini sağlayan küçük kütüphane:

```sh
tools/d3dmetal-hook/build.sh    # → runtime/crossover-26.3/lib/wine/x86_64-unix/cxcompatdb.so
```

## 6. Wine Mono (.NET programları için)

Bazı oyunların başlatıcısı .NET programı (ör. Batman: Arkham Asylum'un BmLauncher'ı). Wine'ın .NET'i Wine Mono:

```sh
mkdir -p ~/.kopru/downloads/wine-mono ~/.kopru/runtime/crossover-26.3/share/wine/mono
cd ~/.kopru/downloads/wine-mono
curl -LO https://dl.winehq.org/wine/wine-mono/10.4.1/wine-mono-10.4.1-x86.msi
cp wine-mono-10.4.1-x86.msi ~/.kopru/runtime/crossover-26.3/share/wine/mono/
```

Yeni prefix'ler Mono'yu bu klasörden kendiliğinden kurar (bu yol henüz denenmedi). Olmazsa 7. adımdan sonra elle:

```sh
scripts/kwine steam msiexec /i "$HOME/.kopru/downloads/wine-mono/wine-mono-10.4.1-x86.msi" /qn
```

## 7. Steam prefix'i

**Prefix:** Wine'ın sahte Windows klasörü (C: sürücüsü, kayıt defteri). Köprü'nün oyunları `steam` adlı prefix'te durur.

```sh
mkdir -p ~/.kopru/downloads/steam && cd ~/.kopru/downloads/steam
curl -LO https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe
cd ~/Documents/Codex/Kopru
scripts/kwine steam wineboot --init                      # prefix'i oluşturur (~20 sn)
cp ~/.kopru/downloads/steam/SteamSetup.exe ~/.kopru/prefixes/steam/drive_c/
scripts/kwine steam 'C:\SteamSetup.exe' /S                # sessiz kurulum (~40 sn)
```

## 8. Uygulama

```sh
scripts/build-app.sh --open     # → build/Köprü.app
cd App && swift test            # isteğe bağlı: testler
```

Masaüstüne kısayol (uygulama her derlemede yeniden oluşturulduğu için takma ad yerine sembolik bağlantı):

```sh
ln -s ~/Documents/Codex/Kopru/build/Köprü.app ~/Desktop/Köprü
```

Uygulamada **Steam'i Aç** → Steam'e giriş yap → oyunu Steam'den kur → Köprü'de **Oyna**.

## 9. Doğrulama

- `scripts/kwine steam notepad` → Not Defteri penceresi açılmalı (Wine çalışıyor).
- Köprü'de Steam "açık" görünmeli; oyun listesi Steam'deki kurulu oyunları göstermeli.
- DirectX 11/12 bir oyunda FPS göstergesini açınca (Ayarlar ⌘,) sağ üstte Metal HUD görünmeli (D3DMetal çalışıyor).

## Bilinen notlar

- **Save'ler:** Steam Cloud'u kullanan oyunlarda kayıtlar kendiliğinden iner. Witcher 3 kayıtları `~/Documents/The Witcher 3`
  içinde (prefix'in Documents'ı Mac'in Documents'ına bağlı).
- **Denuvo** (ör. Batman: Arkham Knight): her yeni prefix/Mac bir "etkinleştirme" sayar; günlük sınırı var.
- **Çözünürlük:** Oyunu Mac ekranının kendi çözünürlüğünde aç; farklıysa fare ekranın bir bölümünde kalabilir.
- Sorun giderme ve ayrıntılı geçmiş: `docs/TASKS.md`.
