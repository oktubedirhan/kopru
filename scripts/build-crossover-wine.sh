#!/bin/zsh
# CrossOver 26.3'ün Wine kaynağını (Wine 11.0 + CodeWeavers yamaları) x86_64 için derler.
#
# Kullanım: scripts/build-crossover-wine.sh [deps|patch|configure|build|install|all]   (varsayılan: all)
#
# Neden x86_64? D3DMetal ve oyunlar Intel kodu; Wine da Rosetta 2 altında Intel olarak çalışıyor.
# Neden CrossOver? D3DMetal 4, Wine 11'in yeni unix-call mekanizmasını ve CodeWeavers'ın
# winemac.drv/d3dmetal.c dosyasındaki `macdrv_functions` tablosunu birlikte istiyor.
set -euo pipefail

# Boşluksuz kısayol: ~/.kopru -> ~/Library/Application Support/Kopru
# (configure/make, "Application Support"daki boşlukla bayrakları ikiye bölüyor).
KOPRU="$HOME/.kopru"
[[ -e $KOPRU ]] || ln -s "$HOME/Library/Application Support/Kopru" "$KOPRU"
SRC="$KOPRU/src/crossover-26.3/sources/wine"
BUILD="$KOPRU/src/crossover-26.3/build"
PREFIX="$KOPRU/runtime/crossover-26.3"
DEPS="$KOPRU/deps/x86_64"   # GPTK paketinden alınan x86_64 FreeType/GnuTLS ve bağımlılıkları
MINGW="$KOPRU/toolchains/llvm-mingw-20261006-ucrt-macos-universal"

# bison >= 3 gerekli (macOS'taki 2.3); llvm-mingw Windows tarafını (PE DLL'ler) derliyor.
# llvm-mingw'nin bin/ klasöründe de "clang" var; Mac derleyicisi karışmasın diye
# mingw PATH'in sonunda ve CC tam yoluyla veriliyor.
export PATH="/opt/homebrew/opt/bison/bin:$PATH:$MINGW/bin"
export CC="/usr/bin/clang -arch x86_64" CXX="/usr/bin/clang++ -arch x86_64"
export OBJC="/usr/bin/clang -arch x86_64"   # winemac.drv Objective-C; yoksa ARM'a derlenir
export CFLAGS="-O2" CXXFLAGS="-O2"
# Başlıklar mimariden bağımsız: ARM Homebrew'dakiler. Kütüphaneler: x86_64 kopyalar.
export FREETYPE_CFLAGS="-I/opt/homebrew/include/freetype2"
export FREETYPE_LIBS="-L$DEPS/lib -lfreetype"
export GNUTLS_CFLAGS="-I/opt/homebrew/opt/gnutls/include"
export GNUTLS_LIBS="-L$DEPS/lib -lgnutls"
# Derleme sırasında çalışan araçlar (ör. yazı tiplerini üreten sfnt2fon) da FreeType'ı bulsun.
# DYLD_* değişkenleri SIP yüzünden /usr/bin/make ve /bin/sh'tan geçerken siliniyor;
# bu yüzden kütüphane klasörü rpath olarak dosyalara gömülüyor.
export LDFLAGS="-Wl,-rpath,$DEPS/lib"

PATCHES="${0:A:h}/../patches/crossover-26.3"

step=${1:-all}

if [[ $step == deps || $step == all ]]; then
  # GPTK Wine paketindeki x86_64 FreeType + GnuTLS ve bağımlılık zinciri (otool -L ile çıkarıldı).
  GPTK_LIB="$KOPRU/runtime/gptk-wine-3.0-3/Contents/Resources/wine/lib"
  mkdir -p "$DEPS/lib"
  for n in libMacportsLegacySupport.dylib libbrotlicommon.1.dylib libbrotlidec.1.dylib \
           libbrotlienc.1.dylib libbz2.1.0.dylib libffi.8.dylib libfreetype.6.dylib libgmp.10.dylib \
           libgnutls.30.dylib libhogweed.6.dylib libiconv.2.dylib libidn2.0.dylib libintl.8.dylib \
           libnettle.8.dylib libp11-kit.0.dylib libpng16.16.dylib libtasn1.6.dylib \
           libunistring.5.dylib libz.1.dylib libzstd.1.dylib; do
    rm -f "$DEPS/lib/$n"; cp -L "$GPTK_LIB/$n" "$DEPS/lib/$n"; chmod u+w "$DEPS/lib/$n"
  done
  # Kimlik @rpath/...: derleme araçları rpath ile bulur. configure yine yalın adı
  # (libfreetype.6.dylib) kaydeder; Wine çalışırken DYLD_FALLBACK_LIBRARY_PATH ile bulunur.
  for n in libfreetype.6 libgnutls.30; do
    install_name_tool -id "@rpath/$n.dylib" "$DEPS/lib/$n.dylib" 2> /dev/null
    codesign -f -s - "$DEPS/lib/$n.dylib" 2> /dev/null
  done
  ln -sf libfreetype.6.dylib "$DEPS/lib/libfreetype.dylib"
  ln -sf libgnutls.30.dylib "$DEPS/lib/libgnutls.dylib"
  echo "deps hazır: $DEPS/lib"
fi

if [[ $step == patch || $step == all ]]; then
  # Köprü yamaları (patches/crossover-26.3/*.patch). Zaten uygulanmışsa atla.
  for p in "$PATCHES"/*.patch(N); do
    if patch -d "$SRC/.." -p1 -R --dry-run -s -f < "$p" > /dev/null 2>&1; then
      echo "yama zaten uygulanmış: ${p:t}"
    else
      patch -d "$SRC/.." -p1 -s < "$p" && echo "yama uygulandı: ${p:t}"
    fi
  done
fi

mkdir -p "$BUILD"
cd "$BUILD"

if [[ $step == configure || $step == all ]]; then
  # i386 PE: 32-bit Windows programları (Steam'in bazı parçaları) için "new WoW64" modu.
  # X11/GStreamer/Vulkan kapalı: grafik D3DMetal'den, pencere winemac.drv'den geliyor.
  "$SRC/configure" \
    --prefix="$PREFIX" \
    --build=x86_64-apple-darwin --host=x86_64-apple-darwin \
    --enable-archs=i386,x86_64 \
    --disable-tests \
    --without-x --without-gstreamer --without-vulkan \
    --without-sdl --without-cups --without-krb5 --without-netapi \
    --without-pcap --without-usb --without-inotify --without-opencl \
    2>&1 | tee "$BUILD/configure.log"
fi

if [[ $step == build || $step == all ]]; then
  # Çıktının tamamı make.log'a; ekrana yalnızca derleyici hataları ve make'in kendi hataları.
  if ! make -j"$(sysctl -n hw.ncpu)" > "$BUILD/make.log" 2>&1; then
    grep -E "error:|\*\*\*" "$BUILD/make.log" | head -20
    echo "make başarısız, ayrıntı: $BUILD/make.log"
    exit 1
  fi
  echo "make tamam"
fi

if [[ $step == install || $step == all ]]; then
  make install 2>&1 | tail -3
  # Windows (PE) DLL'lerinden yalnızca hata ayıklama bölümlerini sil; kod aynen kalır.
  # Wine her prefix'e bu DLL'lerin kopyasını koyduğu için prefix 1 GB yerine ~300 MB olur.
  find "$PREFIX/lib/wine/i386-windows" "$PREFIX/lib/wine/x86_64-windows" -type f \
    \( -name "*.dll" -o -name "*.exe" -o -name "*.drv" -o -name "*.sys" -o -name "*.ocx" \
       -o -name "*.cpl" -o -name "*.acm" -o -name "*.ax" -o -name "*.tlb" -o -name "*.ds" \
       -o -name "*.msstyles" -o -name "*.dll16" -o -name "*.exe16" -o -name "*.drv16" -o -name "*.mod16" \) \
    -print0 | xargs -0 "$MINGW/bin/llvm-strip" --strip-debug
  # Çalışma zamanında FreeType/GnuTLS bu klasörden bulunuyor (DYLD_FALLBACK_LIBRARY_PATH, bkz. scripts/kwine).
  mkdir -p "$PREFIX/lib/deps"
  cp -a "$DEPS/lib/" "$PREFIX/lib/deps/"
  echo "Kuruldu: $PREFIX"
fi
