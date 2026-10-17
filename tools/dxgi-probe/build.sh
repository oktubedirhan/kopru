#!/bin/zsh
# dxgi-probe.exe'yi llvm-mingw ile derler (Mac'te çalışan, Windows .exe üreten derleyici).
set -euo pipefail

HERE="${0:A:h}"
MINGW="$HOME/Library/Application Support/Kopru/toolchains/llvm-mingw-20261006-ucrt-macos-universal"

"$MINGW/bin/x86_64-w64-mingw32-clang" -O2 -Wall \
  -o "$HERE/dxgi-probe.exe" "$HERE/dxgi_probe.c" \
  -ldxgi -ld3d11 -ld3d12 -ldxguid

echo "Derlendi: $HERE/dxgi-probe.exe"
