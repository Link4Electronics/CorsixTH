#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	cmake           \
	doxygen         \
	fluidsynth      \
	libdecor        \
    lua-filesystem  \
    lua-lpeg        \
	pipewire-alsa   \
	pipewire-audio  \
	pipewire-jack   \
	rtmidi          \
	sdl2_mixer      \
	timidity++

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano ffmpeg-mini
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DENABLE_UNIT_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build --parallel $(nproc)
DESTDIR=./pkg_root cmake --install build

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

quick-sharun ./pkg_root/usr/bin/corsix-th /usr/lib/lua/*/lpeg.so /usr/lib/alsa-lib /usr/lib/libpulse-simple.so* /usr/lib/libfluidsynth.so*
cp -v /etc/timidity/timidity.cfg ./AppDir/bin
echo 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' >> ./AppDir/.env
mkdir -p ./AppDir/share/soundfonts
wget https://raw.githubusercontent.com/Jacalz/fluid-soundfont/master/SF3/FluidR3.sf3 -O ./AppDir/share/soundfonts/FluidR3.sf3
echo 'SDL_SOUNDFONTS=${SHARUN_DIR}/share/soundfonts/FluidR3.sf3' >> ./AppDir/.env
quick-sharun --make-appimage
