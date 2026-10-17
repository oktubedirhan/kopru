#!/bin/zsh
# d3d-window.exe'yi llvm-mingw ile derler (Mac'te çalışan, Windows .exe üreten derleyici).
set -euo pipefail

HERE="${0:A:h}"
MINGW="$HOME/Library/Application Support/Kopru/toolchains/llvm-mingw-20261006-ucrt-macos-universal"

"$MINGW/bin/x86_64-w64-mingw32-clang" -O2 -Wall \
  -o "$HERE/d3d-window.exe" "$HERE/d3d_window.c" \
  -ld3d11 -ld3d12 -ldxgi -ldxguid -luser32

echo "Derlendi: $HERE/d3d-window.exe"
