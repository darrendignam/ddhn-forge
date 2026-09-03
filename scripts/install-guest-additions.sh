#!/bin/bash
# Install guest tooling for both hypervisors the image is used under.
#
# The image is built with the Packer QEMU builder but released as an OVA that users
# import into VirtualBox, so it needs guest drivers for both. Installing both is
# harmless: each set only activates when its hypervisor is detected.
#
# Ubuntu 24.04 carries all of these in its own archive, so unlike the Debian 12 build
# that preceded this there is no third-party repository to add. virtualbox-guest-* live
# in multiverse, which an Ubuntu Server install already enables; add-apt-repository is
# kept below as insurance for an ISO that does not, and is a no-op when it is on.
#
# The availability check below deliberately does not pipe into grep. Three VM builds
# were lost to this:
#
#   apt-cache policy pkg | grep -q 'Candidate: [0-9]'
#
# grep -q exits on the first match and closes the pipe, apt-cache takes SIGPIPE and
# exits non-zero, `set -o pipefail` makes that the status of the whole pipeline, and
# `if !` turns a successful match into the failure branch. It reported "not available"
# for a package apt could see perfectly well, and the same construct misreports any
# package at all, including bash.

set -euo pipefail

echo "Installing guest tooling..."

# Use the tool built for it rather than editing sources files by hand.
sudo add-apt-repository -y multiverse

sudo apt-get update

# No pipe, so pipefail has nothing to misreport. See the note at the top of the file.
guest_x11_policy=$(apt-cache policy virtualbox-guest-x11)
if [[ ! "${guest_x11_policy}" =~ Candidate:[[:space:]]+[0-9] ]]; then
    echo "ERROR: virtualbox-guest-x11 has no installation candidate." >&2
    echo "apt-cache policy said:" >&2
    echo "${guest_x11_policy}" >&2
    echo "Apt sources:" >&2
    grep -rHE '^(Components|deb )' /etc/apt/sources.list /etc/apt/sources.list.d/ >&2 2>/dev/null || true
    exit 1
fi

# No dkms, headers or toolchain. The vboxguest and vboxsf modules ship in Ubuntu's
# stock kernel, and neither guest additions package depends on dkms. Installing
# linux-headers-$(uname -r) also tied the build to a kernel version that only exists
# in the archive while the pinned ISO is current, so it broke on its own once that
# point release aged out.
sudo apt-get install -y --no-install-recommends \
    virtualbox-guest-utils \
    virtualbox-guest-x11 \
    qemu-guest-agent \
    spice-vdagent

# Enabled, not started. VirtualBox services cannot start under QEMU, where this script
# is running, and systemd would report the failure as a provisioner error.
sudo systemctl enable virtualbox-guest-utils
sudo systemctl enable qemu-guest-agent

echo "Guest tooling installed successfully"
