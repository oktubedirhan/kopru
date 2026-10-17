# Köprü

Windows oyunlarını Apple Silicon Mac'te çalıştıran, kişisel kullanım için yazılmış bir başlatıcı. Amaç hem çalışan bir araç elde etmek hem de bu tür araçların (Wine, D3DMetal, CrossOver, GameToMac) nasıl çalıştığını adım adım öğrenmek.

- **Dağıtım yok.** Yalnızca bu bilgisayarda kullanılır.
- **İlk hedef oyun:** Elden Ring (Steam, offline).
- **Referans:** `/Applications/GameToMac.app/Contents/Resources/Sources/` içindeki kod ve belgeler okunur, anlaşılır; kopyalanmaz.

## Katmanlar

```
Köprü (SwiftUI uygulaması)   → oyun listesi, prefix yönetimi, "Oyna" butonu
  └─ Wine                    → Windows programını macOS'ta çalıştırır
       └─ D3DMetal (GPTK)    → DirectX 11/12 çağrılarını Metal'e çevirir
            └─ Rosetta 2     → x86_64 kodu Apple Silicon'da çalıştırır
```

## Kullanım

- **Uygulama:** `scripts/build-app.sh --open` → `build/Köprü.app` (Steam prefix'indeki oyunlar, Oyna, Steam'i aç/kapat, Ayarlar ⌘,: FPS göstergesi ve FPS sınırı).
- **Testler:** `cd App && swift test`
- **Terminalden:** `scripts/kwine <prefix> <program>` (ör. `scripts/kwine steam 'C:\Program Files (x86)\Steam\steam.exe' -cef-disable-gpu`)
- **Wine'ı derlemek:** `scripts/build-crossover-wine.sh all` (yamalar: `patches/crossover-26.3/`)
- **Simge:** `tools/app-icon/build.sh`

## Yol haritası

| Aşama | İş | Tahmini süre |
|---|---|---|
| 1 | Wine'ı kurmak, terminalden bir Windows programı açmak, prefix kavramı | 1 oturum |
| 2 | Apple Game Porting Toolkit'i indirip D3DMetal'i Wine'a bağlamak | 1 oturum |
| 3 | Prefix içine Windows Steam'i kurmak, Elden Ring'i indirmek, VC++ ve DirectX paketleri | 1–2 oturum (+ ~60 GB indirme) |
| 4 | Elden Ring'i offline başlatmak, ekran/çözünürlük sorunlarını çözmek | 1–3 oturum |
| 5 | Kendi SwiftUI başlatıcımız: prefix oluşturma, tek tıkla başlatma, ayarlar | 3–5 oturum |
| 6 (isteğe bağlı) | Wine'ı kaynaktan kendimiz derlemek, dışa bağımlılığı azaltmak | 2–4 oturum |

Bir oturum ≈ 2–3 saat. İlerleme kaydı: `docs/TASKS.md`.
