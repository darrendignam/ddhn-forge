#!/bin/bash
# Rebuilds Ubuntu noble's qtwebkit-opensource-src on a release that no longer ships it.
#
# Ubuntu's packaging is used rather than upstream's tarball because it produces correctly
# structured debs with the right shlibs and symbols. Onto that goes the newer toolchain
# patch stack that Arch and Fedora maintain, which Ubuntu's noble revision predates.
set -euo pipefail

readonly UPSTREAM_VERSION="5.212.0~alpha4"
readonly DEBIAN_REVISION="36"
readonly LOCAL_SUFFIX="viper"
readonly POOL="http://archive.ubuntu.com/ubuntu/pool/universe/q/qtwebkit-opensource-src"

readonly ORIG_SHA256="9ca126da9273664dd23a3ccd0c9bebceb7bb534bddd743db31caf6a5a6d4a9e6"
readonly DEBIAN_SHA256="8eab437ed9dad397198d1296f89a9fba6ca468b8a4616b1d102cb71abdc60a33"

readonly OUT_DIR="${OUT_DIR:-/out}"
readonly SRC_DIR="/build/src"

log() { printf '\n== %s ==\n' "$1"; }

fetch() {
  local name="$1" want="$2"
  curl -fsSL --retry 5 --retry-all-errors -o "${name}" "${POOL}/${name}"
  echo "${want}  ${name}" | sha256sum -c - \
    || { echo "checksum mismatch for ${name}" >&2; exit 1; }
}

log "Fetching Ubuntu source package"
mkdir -p "${SRC_DIR}" && cd "${SRC_DIR}"
fetch "qtwebkit-opensource-src_${UPSTREAM_VERSION}.orig.tar.xz" "${ORIG_SHA256}"
fetch "qtwebkit-opensource-src_${UPSTREAM_VERSION}-${DEBIAN_REVISION}.debian.tar.xz" "${DEBIAN_SHA256}"

log "Unpacking"
# The orig tarball unpacks to the upstream name, with the tilde written as a hyphen.
readonly UPSTREAM_DIR="qtwebkit-${UPSTREAM_VERSION/\~/-}"
tar xf "qtwebkit-opensource-src_${UPSTREAM_VERSION}.orig.tar.xz"
cd "${UPSTREAM_DIR}"
tar xf "../qtwebkit-opensource-src_${UPSTREAM_VERSION}-${DEBIAN_REVISION}.debian.tar.xz"

log "Adding toolchain patches newer than Ubuntu's revision"
# Ubuntu's series already carries icu_68, gcc_13, libxml2_2.12, glib_2.68, bison_3.7,
# python_3.9 and offlineasm_ruby_3.2. These are the ones it predates: 26.04 ships
# GCC 15.2 and ICU 78, both well past what the noble revision was built against.
#
# Fedora's cstdint patch is deliberately not here: gcc_13.diff already adds the same
# include to ANGLE's mathutil.h, and applying both fails the build at the patch stage.
for p in qtwebkit-fix-build-gcc14.patch \
         qt5-webkit-icu75.patch \
         qt5-webkit-icu76.patch \
         qt5-webkit-gcc16-sourceprovider-rtti.patch; do
  cp "/build/extra-patches/${p}" debian/patches/
  echo "${p}" >> debian/patches/series
  echo "  queued ${p}"
done

log "Allowing CMake 4 to configure a CMake 2.8 tree"
# 26.04 ships CMake 4, which removed compatibility with cmake_minimum_required below 3.5.
# QtWebKit's top-level CMakeLists.txt still declares 2.8. Rewriting every CMakeLists in a
# three-million-line tree is not proportionate, and CMake provides this exact escape hatch.
grep -q 'dh_auto_configure -- -DPORT=Qt' debian/rules \
  || { echo "debian/rules no longer matches the expected configure line" >&2; exit 1; }
sed -i 's/dh_auto_configure -- -DPORT=Qt/dh_auto_configure -- -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DPORT=Qt/' debian/rules

log "Recording the local revision"
export DEBEMAIL="${DEBEMAIL:-viper@openpreservation.org}"
export DEBFULLNAME="${DEBFULLNAME:-ViPER release pipeline}"
dch --local "${LOCAL_SUFFIX}" \
    "Rebuild for Ubuntu 26.04: add ICU 75/76 and GCC 14/16 patches from Arch and Fedora."
dch --release ""

log "Building (this is a large build, expect 30-90 minutes)"
# Tests need an X server and add a long tail to a build we only want the libraries from.
# Both variables are needed: DEB_BUILD_OPTIONS skips running them, DEB_BUILD_PROFILES is
# what satisfies the "<!nocheck>" restriction on xauth and xvfb in Build-Depends.
export DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)"
export DEB_BUILD_PROFILES="nocheck"
dpkg-buildpackage -us -uc -b

log "Collecting artefacts"
mkdir -p "${OUT_DIR}"
cp -v ../*.deb "${OUT_DIR}/"
cd "${OUT_DIR}" && sha256sum ./*.deb | tee SHA256SUMS
