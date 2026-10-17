#!/bin/zsh
# net-probe.exe'yi llvm-mingw ile derler (Mac'te çalışan, Windows .exe üreten derleyici).
set -euo pipefail

HERE="${0:A:h}"
MINGW="$HOME/Library/Application Support/Kopru/toolchains/llvm-mingw-20261006-ucrt-macos-universal"

"$MINGW/bin/x86_64-w64-mingw32-clang" -O2 -Wall -municode \
  -o "$HERE/net-probe.exe" "$HERE/net_probe.c" -lwinhttp

echo "Derlendi: $HERE/net-probe.exe"
