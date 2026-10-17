#!/bin/zsh
# Köprü uygulamasını derler ve build/Köprü.app paketini oluşturur.
# Kullanım: scripts/build-app.sh [--open]
#
# Bir .app aslında belirli düzende bir klasördür:
#   Köprü.app/Contents/Info.plist      → uygulamanın kimliği (ad, sürüm, çalıştırılacak dosya)
#   Köprü.app/Contents/MacOS/Kopru     → derlenmiş program
#   Köprü.app/Contents/Resources/      → simge (AppIcon.icns; yeniden çizmek için tools/app-icon/build.sh)
set -euo pipefail

REPO="${0:A:h:h}"
APP="$REPO/build/Köprü.app"

cd "$REPO/App"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/Kopru"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Kopru"
cp "$REPO/App/Resources/AppIcon.icns" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>        <string>local.kopru.Kopru</string>
	<key>CFBundleName</key>              <string>Köprü</string>
	<key>CFBundleDisplayName</key>       <string>Köprü</string>
	<key>CFBundleExecutable</key>        <string>Kopru</string>
	<key>CFBundleIconFile</key>          <string>AppIcon</string>
	<key>CFBundlePackageType</key>       <string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.1</string>
	<key>CFBundleVersion</key>           <string>1</string>
	<key>LSMinimumSystemVersion</key>    <string>15.0</string>
	<key>LSApplicationCategoryType</key> <string>public.app-category.games</string>
	<key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
PLIST

# Ad-hoc imza ("-"): kimlik yok, yalnızca bu Mac'te çalışması için. Apple Silicon imzasız programı çalıştırmaz.
codesign --force --sign - "$APP"
echo "Hazır: $APP"

if [[ ${1:-} == --open ]]; then open "$APP"; fi
