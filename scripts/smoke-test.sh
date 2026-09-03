#!/bin/bash
# Assert the bundled tools actually work before the image is published.
#
# Runs as a Packer provisioner after Ansible and before cleanup. A release build
# spends hours uploading multi-gigabyte artifacts, so a broken tool needs to fail
# the build here rather than be discovered by a user after the download.
#
# GUI launchers are checked for resolvable targets rather than executed, because
# starting a Swing application on a headless build would hang.

set -uo pipefail

failures=0

pass() { echo "  ok    $1"; }
fail() { echo "  FAIL  $1"; failures=$((failures + 1)); }

# Runs a CLI tool and accepts whatever exit status it chooses for a help or version
# flag. What we care about is that the launcher resolved and the JVM found its jar,
# so we fail on "command not found" and on the classic missing-jar stack traces.
check_runs() {
  local label="$1"
  shift
  local output status
  output=$("$@" 2>&1)
  status=$?

  if [ "${status}" -eq 127 ]; then
    fail "${label}: command not found"
    return
  fi
  # Bash regex rather than a pipe into grep -q. Under `set -o pipefail` the producer
  # can be killed by SIGPIPE when grep exits early, which makes the pipeline report
  # failure on a successful match. Here that would silently pass a broken tool.
  if [[ "${output}" =~ (Unable\ to\ access\ jarfile|ClassNotFoundException|NoClassDefFoundError|No\ such\ file\ or\ directory) ]]; then
    fail "${label}: launcher ran but could not load its application"
    printf '%s\n' "${output}" | head -5 | sed 's/^/          /'
    return
  fi
  pass "${label}"
}

check_resolves() {
  local label="$1" path="$2"
  if [ ! -e "${path}" ]; then
    fail "${label}: ${path} is missing"
  elif [ ! -x "${path}" ]; then
    fail "${label}: ${path} is not executable"
  elif ! readlink -e "${path}" >/dev/null; then
    fail "${label}: ${path} is a dangling symlink"
  else
    pass "${label}"
  fi
}

check_exists() {
  local label="$1" path="$2"
  if [ -e "${path}" ]; then
    pass "${label}"
  else
    fail "${label}: ${path} is missing"
  fi
}

echo "==> Java runtime"
check_runs "java" java -version

# DROID 6.9.13 ships jars built for Java 21. On a Java 17 runtime every one of them
# died with UnsupportedClassVersionError, and because the GUI checks below only test
# that a launcher resolves, both droid and droid-gui shipped broken and unnoticed.
# Comparing class file versions catches that without launching a Swing application.
echo "==> Bundled jars match the installed Java runtime"
# [^"]* not .* : a greedy match runs past the closing quote and yields an empty version,
# which would make every jar below look incompatible.
jre_major=$(java -version 2>&1 | sed -n '1s/[^"]*"\([0-9]*\).*/\1/p')
jre_class=$((jre_major + 44))
for jar in $(find /usr/local/lib -name '*.jar' 2>/dev/null | grep -vi uninstaller); do
  first_class=$(unzip -l "${jar}" 2>/dev/null | awk '/\.class$/{print $4; exit}')
  [ -n "${first_class}" ] || continue
  jar_class=$(unzip -p "${jar}" "${first_class}" 2>/dev/null | od -An -tu1 -j6 -N2 | awk '{print $2}')
  [ -n "${jar_class}" ] || continue
  if [ "${jar_class}" -gt "${jre_class}" ]; then
    fail "$(basename "${jar}"): needs Java $((jar_class - 44)), runtime is Java ${jre_major}"
  fi
done
[ "${failures}" -eq 0 ] && pass "all jars run on Java ${jre_major}"

echo "==> Command line tools"
check_runs "jhove" /usr/local/bin/jhove -h
check_runs "verapdf" /usr/local/bin/verapdf --version

echo "==> GUI launchers resolve"
check_resolves "jhove-gui" /usr/local/bin/jhove-gui
check_resolves "droid-gui" /usr/local/bin/droid-gui
check_resolves "tika-gui" /usr/local/bin/tika-gui
check_resolves "verapdf-gui" /usr/local/bin/verapdf-gui

echo "==> Desktop entries"
for tool in jhove droid tika verapdf; do
  check_exists "${tool}.desktop" "/usr/share/applications/${tool}.desktop"
done
for tool in atril gimp org.inkscape.Inkscape mediainfo-gui mediaconch-gui fr.handbrake.ghb; do
  check_exists "${tool}.desktop" "/usr/share/applications/${tool}.desktop"
done

echo "==> Tool manifest"
check_exists "manifest" /usr/local/share/viper/manifest.json

# The viper account is the only way to root on the shipped appliance: the build
# account is locked during cleanup and root has no password. That rests on Ubuntu
# shipping nullok in common-auth, so prove it here rather than discover it after
# the image is published. -k clears any cached credentials so the password path is
# genuinely exercised.
echo "==> Administrative access"
if sudo -u viper -- sh -c 'echo "" | sudo -S -k true' >/dev/null 2>&1; then
  pass "viper can obtain root via sudo"
else
  fail "viper cannot obtain root: the appliance would ship with no admin path"
fi

# The appliance fetches nothing at run time, but a missing CA bundle is the single
# failure that silently breaks every tool that talks to a network: rclone to cloud
# storage, veraPDF's updater, any user script. It has been broken before, by a removal
# list that purged openssl and took ca-certificates with it as a reverse dependency,
# and nothing in the build noticed. Assert it rather than assume it.
echo "==> TLS trust store"
check_exists "ca-certificates package" /usr/share/ca-certificates
if [ -s /etc/ssl/certs/ca-certificates.crt ]; then
  pass "CA bundle is present and not empty"
else
  fail "/etc/ssl/certs/ca-certificates.crt is missing or empty: HTTPS will not verify"
fi

# An actual handshake, because a present bundle can still be unreadable or stale.
# Distinguishes a certificate problem, which must fail the build, from the build host
# simply having no route out, which must not.
curl -sS --max-time 20 -o /dev/null https://github.com 2>/dev/null
case $? in
  0)     pass "HTTPS certificate verification works" ;;
  6|7|28) echo "  skip  no network on the build host, certificate path not exercised" ;;
  *)     fail "HTTPS request failed certificate verification" ;;
esac

echo
if [ "${failures}" -gt 0 ]; then
  echo "Smoke test FAILED with ${failures} problem(s). Not publishing this image."
  exit 1
fi
echo "Smoke test passed."
