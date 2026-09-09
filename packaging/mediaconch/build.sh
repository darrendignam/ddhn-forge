#!/bin/bash
# Builds MediaConch 25.04 debs on Ubuntu 26.04, against a locally built libqt5webkit5.
#
# Expects the qtwebkit stage's output mounted read-only at /qtwebkit. Building rather than
# installing MediaArea's published deb is what picks up 26.04's libxml2 2.15 soname; the
# published build links libxml2.so.2, which no longer exists here.
set -euo pipefail

readonly VERSION="25.04"
readonly LOCAL_SUFFIX="viper"
readonly SRC_URL="https://mediaarea.net/download/source/mediaconch/${VERSION}/mediaconch_${VERSION}.tar.xz"
readonly SRC_SHA256="7556eb98e2d156aca08913ec91d1180aaef3f7e73397f5ec54304d6e82a5a869"

readonly QTWEBKIT_DIR="${QTWEBKIT_DIR:-/qtwebkit}"
readonly OUT_DIR="${OUT_DIR:-/out}"

log() { printf '\n== %s ==\n' "$1"; }

log "Installing the locally built QtWebKit"
# Both are needed: the runtime library to link against and the -dev package for headers,
# which is what MediaConch's Build-Depends actually names.
ls "${QTWEBKIT_DIR}"/libqt5webkit5_*.deb "${QTWEBKIT_DIR}"/libqt5webkit5-dev_*.deb >/dev/null \
  || { echo "no QtWebKit debs found in ${QTWEBKIT_DIR}" >&2; exit 1; }
apt-get update -qq
apt-get install -y --no-install-recommends \
  "${QTWEBKIT_DIR}"/libqt5webkit5_*.deb \
  "${QTWEBKIT_DIR}"/libqt5webkit5-dev_*.deb

log "Fetching MediaConch ${VERSION} source"
mkdir -p /build/src && cd /build/src
curl -fsSL --retry 5 --retry-all-errors -o "mediaconch_${VERSION}.tar.xz" "${SRC_URL}"
echo "${SRC_SHA256}  mediaconch_${VERSION}.tar.xz" | sha256sum -c - \
  || { echo "checksum mismatch for the MediaConch tarball" >&2; exit 1; }

log "Unpacking"
tar xf "mediaconch_${VERSION}.tar.xz"
cd MediaConch

log "Recording the local revision"
export DEBEMAIL="${DEBEMAIL:-viper@openpreservation.org}"
export DEBFULLNAME="${DEBFULLNAME:-ViPER release pipeline}"
dch --local "${LOCAL_SUFFIX}" \
    "Rebuild for Ubuntu 26.04 against a locally built libqt5webkit5."
dch --release ""

log "Building"
export DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)"
export DEB_BUILD_PROFILES="nocheck"
dpkg-buildpackage -us -uc -b

log "Collecting artefacts"
mkdir -p "${OUT_DIR}"
# The -dbg packages are large and nothing in ViPER consumes them.
cp -v ../*.deb "${OUT_DIR}/"
rm -f "${OUT_DIR}"/*-dbg_*.deb
cd "${OUT_DIR}" && sha256sum ./*.deb | tee SHA256SUMS
