# Köprü — Claude için yönergeler

Önce `README.md` ve `docs/TASKS.md` dosyalarını oku.

## Kullanıcı ve amaç
- Kullanıcıyla Türkçe, kısa ve anlaşılır konuş. Kullanıcı bu alanı öğreniyor: her adımda **ne yaptığını ve neden** bir iki cümleyle açıkla, yeni kavramları (prefix, DLL override, D3DMetal vb.) ilk geçtiği yerde tanımla.
- Amaç öğrenmek ve kişisel kullanım. Proje dağıtılmayacak.
- Adım adım ilerle; her aşamayı çalışır halde bırak. Aşama bitince dur, sonucu ve sıradaki adımı `docs/TASKS.md` içine yaz.

## GameToMac referansı
- `/Applications/GameToMac.app/Contents/Resources/Sources/` içindeki Swift kodu ve `.md` belgeleri **okunabilir**, "neden böyle yapılmış" diye açıklanabilir.
- GameToMac'in kendi kodunda lisans yok (tüm hakları saklı): **kopyalama**, kendi kodumuzu kendimiz yaz. Yöntemi anlamak serbest, metni aktarmak değil.
- `/Applications/GameToMac.app` ve onun verilerine dokunma, değiştirme, içinden dosya kullanma.
  - İstisna (kullanıcı onayı, 2026-10-16): kullanıcının kendi Steam indirmesi olan Witcher 3 oyun dosyaları ve appmanifest'leri, GameToMac'in `~/Library/Application Support/Game Library/Games/witcher3/` prefix'inden **salt okunur APFS klonu** (`cp -c`) ile bizim `steam` prefix'imize alındı. Orijinal değiştirilmez; save'lere dokunulmaz.
- Apple GPTK'nın lisansı kısıtlayıcı: D3DMetal'i kullanıcı Apple'dan kendisi indirir; GameToMac içindeki kopya kullanılmaz.

## Sınırlar
- Oyunlar kullanıcının sahip olduğu Steam kopyalarıdır. DRM kırma, crack veya korsan dosya yok.
- Anti-cheat (EAC vb.) yalnızca **offline** başlatma için devre dışı bırakılabilir; online oyuna anti-cheat atlatarak bağlanmak yok.
- Büyük indirmelerden (>1 GB), Homebrew paketi kurmadan ve sistem ayarı değiştirmeden önce kullanıcıya sor.
- Oyun kayıtlarına (save) dokunmadan önce yedek al.

## Kayıt
- `docs/TASKS.md`: tarihli kısa girişler — ne yapıldı, hangi komut, sonuç, öğrenilen şey, sıradaki adım.
- Çalışan ve çalışmayanı ayır; "denendi" ile "çalıştı" aynı şey değildir.
