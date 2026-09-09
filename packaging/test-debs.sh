#!/bin/bash
# Acceptance test for the locally built QtWebKit and MediaConch debs.
#
# Runs in a clean Ubuntu 26.04 container with no build tooling, which is the point: it
# proves the debs carry their own dependency closure rather than relying on anything the
# build environment happened to have installed.
set -uo pipefail

readonly QTWEBKIT_DIR="${1:?usage: test-debs.sh <qtwebkit-out-dir> <mediaconch-out-dir>}"
readonly MEDIACONCH_DIR="${2:?usage: test-debs.sh <qtwebkit-out-dir> <mediaconch-out-dir>}"

docker run --rm \
  -v "${QTWEBKIT_DIR}:/qtwebkit:ro" \
  -v "${MEDIACONCH_DIR}:/mediaconch:ro" \
  ubuntu:26.04 bash -c '
set -uo pipefail
fail=0
check() { if [ "$1" -eq 0 ]; then echo "  PASS  $2"; else echo "  FAIL  $2"; fail=1; fi; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1

echo "== installing =="
# MediaArea repo supplies libmediainfo0v5 and libzen0v5 at runtime.
apt-get install -y -qq --no-install-recommends curl ca-certificates >/dev/null 2>&1
curl -fsSL -o /tmp/repo.deb https://mediaarea.net/repo/deb/repo-mediaarea_1.0-25_all.deb >/dev/null 2>&1
apt-get install -y -qq /tmp/repo.deb >/dev/null 2>&1
apt-get update -qq >/dev/null 2>&1

apt-get install -y -qq --no-install-recommends \
  /qtwebkit/libqt5webkit5_*.deb \
  /mediaconch/libmediaconch0_*.deb /mediaconch/mediaconch_*.deb /mediaconch/mediaconch-gui_*.deb \
  > /tmp/install.log 2>&1
check $? "debs install with dependencies resolved"
tail -3 /tmp/install.log | sed "s/^/        /"

echo
echo "== dependency closure =="
for b in /usr/bin/mediaconch /usr/bin/mediaconch-gui; do
  [ -x "$b" ] || { echo "  FAIL  $b missing"; fail=1; continue; }
  miss=$(ldd "$b" 2>/dev/null | grep -c "not found")
  check $([ "$miss" -eq 0 ] && echo 0 || echo 1) "$(basename $b): no missing shared libraries"
  [ "$miss" -ne 0 ] && ldd "$b" | grep "not found" | sed "s/^/        /"
done

echo
echo "== the libraries that forced this whole exercise =="
ldd /usr/bin/mediaconch-gui 2>/dev/null | grep -E "WebKit|xml2" | sed "s/^/  /"

echo
echo "== CLI runs =="
out=$(mediaconch --version 2>&1); check $? "mediaconch --version"
echo "        $out"

echo
echo "== GUI starts under a virtual display =="
apt-get install -y -qq --no-install-recommends xvfb >/dev/null 2>&1
timeout 25 xvfb-run -a mediaconch-gui >/tmp/gui.log 2>&1 &
gpid=$!
sleep 15
if kill -0 $gpid 2>/dev/null; then
  echo "  PASS  mediaconch-gui still running after 15s (no crash on startup)"
  kill $gpid 2>/dev/null
else
  wait $gpid; rc=$?
  # 124 is timeout firing, which would mean it survived the full window.
  if [ $rc -eq 124 ]; then echo "  PASS  mediaconch-gui ran to the timeout"
  else echo "  FAIL  mediaconch-gui exited early (rc=$rc)"; fail=1; sed "s/^/        /" /tmp/gui.log | head -5; fi
fi

echo
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
'
