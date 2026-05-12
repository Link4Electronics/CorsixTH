#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	cmake             \
	doxygen           \
	fluidsynth        \
	ibus			  \
	libdecor          \
    lua-filesystem    \
    lua-lpeg          \
	ninja			  \
	pipewire-alsa     \
	pipewire-audio    \
	pipewire-jack     \
	rtmidi            \
	sdl2_mixer        \
	timidity++		  \
	vulkan-headers	  \
	wayland-protocols

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano ffmpeg-mini

sed -i 's|EUID == 0|EUID == 69|g' /usr/bin/makepkg # because the docker image is ran as root this is needed lol
mkdir sdl2 && cd sdl2
cat <<-'EOF' > ./PKGBUILD
# Maintainer: HurricanePootis <hurricanepootis@protonmail.com>
# Contributor: Sven-Hendrik Haase <svenstaro@archlinux.org>
pkgname=sdl2
pkgver=2.32.8
pkgrel=1
pkgdesc="A library for portable low-level access to a video framebuffer, audio output, mouse, and keyboard (Version 2)"
arch=('x86_64' 'aarch64')
url="https://www.libsdl.org"
license=('Zlib')
provides=('sdl2-compat')
conflicts=('sdl2-compat')
depends=('glibc' 'libxext' 'libxrender' 'libx11' 'libgl' 'libxcursor' 'hidapi' 'libusb')
makedepends=('alsa-lib' 'dbus' 'mesa' 'libpulse' 'libxrandr' 'libxinerama' 'wayland' 'libxkbcommon'
            'wayland-protocols' 'ibus' 'libxss' 'cmake' 'jack' 'ninja' 'pipewire'
            'libdecor' 'vulkan-driver' 'vulkan-headers' 'libsamplerate')
optdepends=('alsa-lib: ALSA audio driver'
            'libpulse: PulseAudio audio driver'
            'jack: JACK audio driver'
            'pipewire: PipeWire audio driver'
            'libdecor: Wayland client decorations')
source=("https://github.com/libsdl-org/SDL/releases/download/release-${pkgver}/SDL2-${pkgver}.tar.gz")
        sha512sums=('484c33638e7bd1002815bb1f6a47a292d1eaf0b963598dde65f4a3e077dfe75ee35b9ea4b3b767365b3ef4f613c4d69ce55b5e96675de562994344e83a978272')
          
prepare(){
        cd "$srcdir/SDL2-$pkgver"
}
          
build() {
        CFLAGS+=" -ffat-lto-objects"
        cmake -S SDL2-${pkgver} -B build -G Ninja \
              -D CMAKE_INSTALL_PREFIX=/usr \
              -D SDL_STATIC=OFF \
              -D SDL_RPATH=OFF
        cmake --build build
}
          
package() {
        DESTDIR="${pkgdir}" cmake --install build
          
        # For some reason, this isn't named correctly and we have to fix it to reflect the actual staticlib name.
        sed -i "s/libSDL2\.a/libSDL2main.a/g" "$pkgdir"/usr/lib/cmake/SDL2/SDL2Targets-noconfig.cmake
          
        install -Dm644 SDL2-${pkgver}/LICENSE.txt "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
EOF

makepkg -f
pacman --noconfirm -Rsndd sdl2-compat sdl3
pacman --noconfirm -U *.pkg.tar.*
cd ..

cmake -B build \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DENABLE_UNIT_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build --parallel $(nproc)
cmake --install build

RAW_VERSION="${GITHUB_REF_NAME:-$(git rev-parse --short HEAD)}"
CLEAN_VERSION=${RAW_VERSION#v}
if [ ${#CLEAN_VERSION} -eq 40 ]; then CLEAN_VERSION=${CLEAN_VERSION:0:7}; fi
VERSION="$CLEAN_VERSION"
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=./CorsixTH/Original_Logo.svg
export DESKTOP=./CorsixTH/com.corsixth.corsixth.desktop
export DEPLOY_OPENGL=1
export DEPLOY_PIPEWIRE=1

quick-sharun /usr/bin/corsix-th /usr/lib/lua/*/lpeg.so /usr/lib/alsa-lib /usr/lib/libpulse-simple.so* /usr/lib/libfluidsynth.so*
cp -v /etc/timidity/timidity.cfg ./AppDir/bin
echo 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' >> ./AppDir/.env
mkdir -p ./AppDir/share/soundfonts
wget https://raw.githubusercontent.com/Jacalz/fluid-soundfont/master/SF3/FluidR3.sf3 -O ./AppDir/share/soundfonts/FluidR3.sf3
echo 'SDL_SOUNDFONTS=${SHARUN_DIR}/share/soundfonts/FluidR3.sf3' >> ./AppDir/.env
quick-sharun --make-appimage
