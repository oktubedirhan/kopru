#!/bin/zsh
# D3DMetal kancasını derleyip CrossOver Wine runtime'ına `cxcompatdb.so` adıyla koyar.
set -euo pipefail

HERE="${0:A:h}"
RUNTIME="$HOME/.kopru/runtime/crossover-26.3"
OUT="$RUNTIME/lib/wine/x86_64-unix/cxcompatdb.so"

/usr/bin/clang -arch x86_64 -O2 -Wall -dynamiclib -o "$OUT" "$HERE/d3dmetal_hook.c"
codesign -f -s - "$OUT" 2>/dev/null
echo "Kuruldu: $OUT"
