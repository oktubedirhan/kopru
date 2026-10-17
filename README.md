# Köprü

Windows oyunlarını Apple Silicon Mac'te çalıştıran, kişisel kullanım için yazılmış bir başlatıcı. Amaç hem çalışan bir araç elde etmek hem de bu tür araçların (Wine, D3DMetal, CrossOver, GameToMac) nasıl çalıştığını adım adım öğrenmek.

- **Dağıtım yok.** Yalnızca kendi Mac'lerimde kullanılır.
- **Çalışan oyunlar:** The Witcher 3 (Steam, DX12, D3DMetal 4); Batman: Arkham Asylum (DX9 → wined3d/OpenGL, 32-bit; ses sorunu açık). Yeni oyunlar (Elden Ring, RDR2…) şimdilik rafta.
- **Referans:** `/Applications/GameToMac.app/Contents/Resources/Sources/` içindeki kod ve belgeler okunur, anlaşılır; kopyalanmaz.

## Katmanlar

```
Köprü (SwiftUI uygulaması)   → oyun listesi, prefix yönetimi, "Oyna" butonu
  └─ Wine                    → Windows programını macOS'ta çalıştırır
       └─ D3DMetal (GPTK)    → DirectX 11/12 çağrılarını Metal'e çevirir
            └─ Rosetta 2     → x86_64 kodu Apple Silicon'da çalıştırır
```

## Kurulum

Apple Silicon Mac + macOS 15 veya üstü. Kısaca:

1. Rosetta 2, Xcode, Homebrew (`bison gnutls freetype`)
2. `git clone https://github.com/oktubedirhan/kopru.git`
3. Wine runtime: diğer Mac'ten kopyala **ya da** `scripts/build-crossover-wine.sh all` ile derle
4. D3DMetal: Game Porting Toolkit 4.0 beta 3'ü Apple'dan **kendin** indir → `~/.kopru/gptk/4.0-beta3/redist`
5. `tools/d3dmetal-hook/build.sh`, Wine Mono, Steam prefix'i (`SteamSetup.exe /S`)
6. `scripts/build-app.sh --open`

Adım adım komutlar, indirme adresleri ve açıklamalar: **[docs/KURULUM.md](docs/KURULUM.md)**

## Kullanım

- **Uygulama:** `scripts/build-app.sh --open` → `build/Köprü.app` (Steam prefix'indeki oyunlar, Oyna, Steam'i aç/kapat, Ayarlar ⌘,: FPS göstergesi ve FPS sınırı).
- **Testler:** `cd App && swift test`
- **Terminalden:** `scripts/kwine <prefix> <program>` (ör. `scripts/kwine steam 'C:\Program Files (x86)\Steam\steam.exe' -cef-disable-gpu`)
- **Wine ortam değişkenleri:** `config/wine.env` (kwine ve uygulama ortak okur)
- **Wine'ı derlemek:** `scripts/build-crossover-wine.sh all` (yamalar: `patches/crossover-26.3/`)
- **Simge:** `tools/app-icon/build.sh`

## Yol haritası

| Aşama | İş | Durum |
|---|---|---|
| 1 | Wine'ı kurmak, terminalden bir Windows programı açmak, prefix kavramı | ✅ |
| 2 | Apple Game Porting Toolkit'i indirip D3DMetal'i Wine'a bağlamak | ✅ |
| 3 | Prefix içine Windows Steam'i kurmak, bir DirectX oyunu (Witcher 3) | ✅ |
| 4 | Yeni oyunlar: Elden Ring (offline), RDR2, Batman: Arkham Knight… | ⏸ rafta |
| 5 | Kendi SwiftUI başlatıcımız: oyun listesi, tek tıkla başlatma, ayarlar, prefix yönetimi | 🔄 sürüyor |
| 6 | Wine'ı (CrossOver 26.3) kaynaktan kendimiz derlemek + kendi yamalarımız | ✅ |

Ayrıntılı ilerleme kaydı ve sıradaki işler: `docs/TASKS.md`.
