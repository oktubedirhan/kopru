#!/bin/zsh
# Simgeyi çizer ve App/Resources/AppIcon.icns dosyasını üretir.
# .icns = aynı simgenin 16–1024 piksel arası boyutları tek dosyada; macOS yerine göre uygun olanı seçer.
set -euo pipefail

HERE="${0:A:h}"
REPO="${HERE:h:h}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift "$HERE/make-icon.swift" "$WORK/icon-1024.png"

SET="$WORK/AppIcon.iconset"
mkdir "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$WORK/icon-1024.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$WORK/icon-1024.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null   # Retina
done

mkdir -p "$REPO/App/Resources"
iconutil -c icns "$SET" -o "$REPO/App/Resources/AppIcon.icns"
cp "$WORK/icon-1024.png" "$REPO/App/Resources/AppIcon-1024.png"
echo "Hazır: $REPO/App/Resources/AppIcon.icns"
