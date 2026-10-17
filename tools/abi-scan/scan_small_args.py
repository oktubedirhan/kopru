#!/usr/bin/env python3
"""Wine sistem çağrılarında 32 bitten küçük argümanları bulur.

Neden: Windows (MS x64) tarafı BOOLEAN/USHORT gibi küçük bir argümanı geçirirken register'ın
(ya da yığın yuvasının) yalnızca alt baytlarını yazar. Apple clang ile derlenen Unix tarafı ise
bu argümanların 32 bite genişletilmiş geldiğini varsayar. Üst baytlarda kalan çöp değeri
bozar (bkz. patches/crossover-26.3/0004). Risk yalnızca syscall tablosundan doğrudan çağrılan
fonksiyonlarda var; __wine_unix_call parametreleri bellekteki bir yapıda geldiği için güvenli.

Kullanım:
  python3 -I tools/abi-scan/scan_small_args.py <wine-kaynak-kökü>                 # listele
  python3 -I tools/abi-scan/scan_small_args.py <wine-kaynak-kökü> --patch <çıktı>  # düzeltme yaması üret
--patch kaynağı değiştirmez; her riskli fonksiyonun başına KOPRU_CLEAN_SMALL_ARG( ad ); ekleyen
birleşik bir diff yazar (yollar a/wine/…, scripts/build-crossover-wine.sh'ın beklediği biçimde).
"""
import difflib
import re
import sys
from pathlib import Path

# 32 bitten küçük tipler (Wine/Windows typedef'leri dahil)
SMALL_TYPES = {
    "BOOLEAN", "UCHAR", "CHAR", "CCHAR", "BYTE", "INT8", "UINT8",
    "USHORT", "SHORT", "CSHORT", "WORD", "WCHAR", "INT16", "UINT16",
    "ATOM", "RTL_ATOM", "LANGID", "KPROCESSOR_MODE",
    "bool", "char", "short",
}

TABLES = [
    ("dlls/ntdll/ntsyscalls.h", ["dlls/ntdll/unix"]),
    ("dlls/win32u/win32syscalls.h", ["dlls/win32u"]),
]

# Makronun ekleneceği ortak başlıklar: (dosya, önüne eklenecek son satır)
HEADERS = [
    ("dlls/ntdll/unix/unix_private.h", "#endif /* __NTDLL_UNIX_PRIVATE_H */"),
    ("dlls/win32u/win32u_private.h", "#endif /* __WINE_WIN32U_PRIVATE */"),
]

MACRO = """
/* Köprü (patches/crossover-26.3/0005): Windows (MS x64) tarafı 32 bitten küçük bir argümanı
 * (BOOLEAN, WORD…) geçirirken register'ın/yığın yuvasının yalnızca alt baytlarını yazar; Apple
 * clang ise argümanın 32 bite genişletilmiş geldiğini varsayıp tamamına bakar. Değeri kendi
 * genişliğinde volatile belleğe yazıp geri okumak üst baytlardaki çöpü temizler. Syscall olarak
 * çağrılan fonksiyonların başında kullanılır; liste: tools/abi-scan/scan_small_args.py */
#define KOPRU_CLEAN_SMALL_ARG(x) \\
    do { volatile __typeof__(x) kopru_small_arg_ = (x); (x) = kopru_small_arg_; } while (0)

"""

# Zaten başka bir yamayla düzeltilmiş olanlar (0004: kopru_clean_boolean)
ALREADY_FIXED_MARKERS = ("kopru_clean_boolean", "KOPRU_CLEAN_SMALL_ARG")


def syscall_names(header: Path) -> list[str]:
    """ALL_SYSCALLS64 bölümündeki SYSCALL_ENTRY( id, Ad, boyut ) satırlarından adlar."""
    text = header.read_text()
    section = text.split("#define ALL_SYSCALLS64", 1)[-1]
    return sorted(set(re.findall(r"SYSCALL_ENTRY\(\s*0x[0-9a-f]+,\s*(\w+),", section)))


def strip_comments(text: str) -> str:
    """/* … */ yorumlarını boşlukla değiştirir; satır sonları kalır, böylece satır numaraları değişmez.
    (Bazı tanımlarda parametrelerle "{" arasında yorum var: NtGdiGetBitmapDimension gibi.)"""
    return re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S)


def definitions(dirs: list[Path]) -> dict[str, tuple[Path, int, str, int]]:
    """Ad → (dosya, satır, parametre listesi, gövdeyi açan "{" karakterinin konumu).
    Yalnızca gövdesi olan tanımlar ({ ile biten)."""
    found = {}
    # CrossOver bazılarını GPT_IMPORT(Ad) ile tanımlar (D3DMetal için ms_abi köprüsü; Ad → sysv_Ad).
    pattern = re.compile(
        r"\b(?:WINAPI|APIENTRY)\s+(?:GPT_IMPORT\(\s*(\w+)\s*\)|(\w+))\s*\(([^;{]*?)\)\s*\{", re.S)
    for d in dirs:
        for f in sorted(d.glob("*.c")):
            text = strip_comments(f.read_text(errors="replace"))
            for m in pattern.finditer(text):
                name, params = m.group(1) or m.group(2), " ".join(m.group(3).split())
                found.setdefault(name, (f, text.count("\n", 0, m.start()) + 1, params, m.end() - 1))
    return found


def small_params(params: str) -> list[str]:
    result = []
    for p in params.split(","):
        p = p.strip()
        if not p or "*" in p or "[" in p:
            continue
        words = re.findall(r"\w+", p)
        types = [w for w in words[:-1] if w not in ("const", "unsigned", "signed", "volatile")]
        if types and types[-1] in SMALL_TYPES:
            result.append(p)
    return result


def make_patch(root: Path, risky: list[tuple[str, Path, str, int]]) -> str:
    """Riskli fonksiyonların başına temizleme satırları ekleyen birleşik diff."""
    inserts: dict[Path, list[tuple[int, str]]] = {}
    for name, f, params, brace in risky:
        original = f.read_text(errors="replace")
        body_start = original[brace + 1: brace + 600]
        if any(marker in body_start for marker in ALREADY_FIXED_MARKERS):
            print(f"atlandı (zaten düzeltilmiş): {name}", file=sys.stderr)
            continue
        arg_names = [re.findall(r"\w+", p)[-1] for p in small_params(params)]
        lines = "".join(f"\n    KOPRU_CLEAN_SMALL_ARG( {a} );" for a in arg_names)
        inserts.setdefault(f, []).append((brace + 1, lines))

    out = []
    files = {f: f.read_text(errors="replace") for f in inserts}
    for rel, anchor in HEADERS:
        f = root / rel
        files.setdefault(f, f.read_text(errors="replace"))
        pos = files[f].rindex(anchor)
        inserts.setdefault(f, []).append((pos, MACRO.lstrip("\n")))
    for f in sorted(inserts):
        old = files[f]
        new = old
        for pos, text in sorted(inserts[f], reverse=True):  # sondan başa: konumlar kaymasın
            new = new[:pos] + text + new[pos:]
        rel = f.relative_to(root)
        out += difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
                                    fromfile=f"a/wine/{rel}", tofile=f"b/wine/{rel}")
    return "".join(out)


def main() -> None:
    args = sys.argv[1:]
    patch_out = None
    if "--patch" in args:
        i = args.index("--patch")
        patch_out = Path(args[i + 1])
        del args[i:i + 2]
    root = Path(args[0] if args else ".")
    total = 0
    risky = []
    for header, dirs in TABLES:
        names = syscall_names(root / header)
        defs = definitions([root / d for d in dirs])
        print(f"## {header}: {len(names)} sistem çağrısı")
        missing = [n for n in names if n not in defs]
        for name in names:
            if name not in defs:
                continue
            total += 1
            f, line, params, brace = defs[name]
            hits = small_params(params)
            if hits:
                risky.append((name, f, params, brace))
                print(f"{name}\t{f.relative_to(root)}:{line}\t{'; '.join(hits)}")
        if missing:
            print(f"(tanımı bulunamayan {len(missing)}: {', '.join(missing[:12])}{' …' if len(missing) > 12 else ''})")
    print(f"\nToplam: {total} tanım tarandı, {len(risky)} tanesinde küçük argüman var.")

    if patch_out:
        header = ("Köprü: syscall olarak çağrılan fonksiyonlarda 32 bitten küçük argümanların üst baytlarını temizle.\n"
                  "Üreten: tools/abi-scan/scan_small_args.py --patch (elle düzenleme yapma, yeniden üret).\n\n")
        patch_out.write_text(header + make_patch(root, risky))
        print(f"Yama yazıldı: {patch_out}")


if __name__ == "__main__":
    main()
