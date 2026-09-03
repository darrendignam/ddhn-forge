#!/bin/bash
# Prepare the provisioned VM for distribution.
#
# Runs as the last Packer provisioner. Two jobs:
#
#  1. Strip everything a released appliance has no use for. Every megabyte here is
#     paid for twice, once uploading to the artifact server and again by every user
#     who downloads the image.
#  2. Remove the build identity, so that every download is not a clone of the same
#     machine carrying the same SSH host keys and the same well known Vagrant key.
#
# The vagrant account itself is locked by shutdown_command in viper.pkr.hcl rather
# than here, because this script still needs sudo and Packer still needs to log in
# as vagrant afterwards to issue the shutdown.

set -euo pipefail

log() { echo "==> $*"; }

log "Disk usage before cleanup"
df -h /

log "Removing tool source trees"
sudo rm -rf /usr/local/src/*

log "Purging Java documentation and sources"
sudo apt-get purge -y openjdk-21-doc openjdk-21-source

log "Removing orphaned packages and apt caches"
sudo apt-get autoremove --purge -y
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# Named explicitly rather than clearing all of /tmp: Packer is running this very
# script from /tmp, and deleting it out from under bash breaks the rest of the run.
log "Removing provisioning leftovers"
# Glob, not the single veraPDF path this used to name. verapdf-arlington.yml unpacks its
# own izpack tree into /tmp/vera-arlington-installer and nothing removed it, so it stayed
# allocated through fstrim and shipped inside the image. /tmp is cleared at boot, so users
# never saw it; they just downloaded it.
sudo rm -rf /tmp/vera-installer /tmp/vera-*-installer
sudo rm -f /tmp/*.jar /tmp/*.zip /tmp/*.deb /tmp/*.xml

log "Truncating logs"
sudo find /var/log -type f -name '*.gz' -delete
sudo find /var/log -type f -regextype posix-extended -regex '.*\.[0-9]+$' -delete
sudo find /var/log -type f -exec truncate -s 0 {} +

# Every home directory, not just vagrant's. The build used to copy the operator's
# public key into the shipped account, so /home/viper/.ssh survived into the release
# and v1.2 went out carrying a maintainer's personal key. That task is gone, and this
# makes sure nothing can put a key back by another route.
log "Removing SSH identities from every account"
sudo rm -rf /root/.ssh
for home in /home/*; do
  [ -d "${home}" ] && sudo rm -rf "${home}/.ssh"
done
sudo rm -f /etc/ssh/ssh_host_*

log "Disabling sshd for the shipped appliance"
# ssh.socket, not just ssh. Ubuntu 24.04 socket-activates sshd: the openssh-server
# postinst runs "systemctl disable --now ssh.service" and "systemctl enable
# ssh.socket", so disabling ssh.service disables something already disabled and
# returns 0 while the socket keeps listening on 0.0.0.0:22. A booted v1.4.0 image
# was confirmed accepting remote logins with this line as it stood.
#
# No --now: these connections are how Packer is talking to the machine right now.
# disable takes effect at next boot, which is the only boot that matters.
sudo systemctl disable ssh.socket ssh.service 2>/dev/null || true

# Staged rather than activated, because sshd re-reads its configuration for every
# new connection and Packer authenticates with a password. shutdown_command moves
# this into place as the machine is sealed, after the last thing that needs SSH.
#
# A drop-in named 00- because sshd takes the FIRST value it finds for a keyword and
# the Include sits at the top of sshd_config. That is why the role's edits to the
# main file lost to cloud-init's 50-cloud-init.conf, and why 99-packer-build.conf
# never did anything either.
sudo tee /etc/ssh/sshd_config.d/00-viper-hardening.conf.disabled >/dev/null <<'SSHCONF'
# ViPER: sshd ships disabled. If you enable it, these are the defaults you get.
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
AddressFamily inet
SSHCONF

log "Clearing machine identity"
sudo truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ] && [ ! -L /var/lib/dbus/machine-id ]; then
  sudo rm -f /var/lib/dbus/machine-id
fi

log "Clearing shell history"
sudo rm -f /root/.bash_history /home/vagrant/.bash_history

# Without this the blocks freed above stay allocated in the qcow2 and ship anyway.
# Requires disk_discard = "unmap" on the Packer source.
log "Releasing freed blocks back to the image"
sudo fstrim -av || echo "    fstrim unavailable, image will be larger than necessary"

# Prove it rather than assume it. A published appliance carrying someone's public key
# is the kind of thing nobody notices until it is downloaded a few hundred times.
log "Verifying sshd will not start on the shipped appliance"
for unit in ssh.socket ssh.service; do
  state=$(systemctl is-enabled "${unit}" 2>/dev/null || true)
  case "${state}" in
    enabled|enabled-runtime)
      echo "ERROR: ${unit} is ${state}; the appliance would ship with SSH reachable" >&2
      exit 1 ;;
    *) log "  ${unit}: ${state:-not present}" ;;
  esac
done

log "Verifying no SSH keys or authorized_keys survive"
leftover=$(sudo find /root /home /etc/skel \
  \( -name 'authorized_keys' -o -name 'id_rsa*' -o -name 'id_ecdsa*' \
     -o -name 'id_ed25519*' -o -name 'id_dsa*' \) -print 2>/dev/null || true)
if [ -n "${leftover}" ]; then
  echo "ERROR: SSH key material survived cleanup:" >&2
  echo "${leftover}" >&2
  exit 1
fi
log "  none found"

log "Disk usage after cleanup"
df -h /
sync
