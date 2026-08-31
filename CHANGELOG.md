# Changelog

Notable changes to the ViPER appliance. Dates are release dates; unreleased work sits
under the next version heading.

The GitHub "What's Changed" list is generated from pull request titles and does not
surface behaviour changes that affect existing users. Those belong here, under
**Behaviour changes**, so they can be lifted straight into release notes.

## v1.3.0 (unreleased)

First release from the reworked Packer release pipeline. Candidate `v1.3.0-rc1`;
`rc2` adds tools and brings the Docker image into the same release, so one tag now
publishes both the VM images and the container.

### Pre-release tools, read this first

Four of the nine tools in `rc2` are **not stable upstream releases**. This is
deliberate, but anyone relying on ViPER for production work should know which
results come from pre-release software. Each is recorded in
`/usr/local/share/viper/manifest.json` with its exact version and origin.

| Tool | Version | Status |
|---|---|---|
| ODF Validator | `0.20-beta-1` | Beta. Carries substantial improvements over the 0.18.x line and was close to becoming a release candidate. Chosen over stable `0.18.5` for those improvements. |
| OpenFixity | `0.1.1-ALPHA` | Alpha, and the only line published so far. |
| veraPDF Arlington | `1.31.174` | Published under `/dev/` and versioned by build number, so this pins a development build rather than a release tag. Installed alongside stable veraPDF, not replacing it. |
| Apache Tika | `2.9.2` | Held at 2.x deliberately. 3.x is available, but a major bump on top of the above would make any failure hard to attribute. |


### Behaviour changes

Read these before upgrading. Each is deliberate, but each can break an existing workflow.

- **The `vagrant` build account is removed, along with the well-known Vagrant public key.**
  Anyone logging into the appliance as `vagrant/vagrant` loses that access. The account
  existed only so Packer could provision the image and was never intended to ship.
- **SSH host keys are wiped and `sshd` ships disabled.** Every previously published image
  carried identical host keys, so any two downloads were indistinguishable to a client and
  trivially impersonated. Enable `ssh` with `sudo systemctl enable --now ssh` if you need it.
- **Tool source trees are no longer installed under `/usr/local/src`.** Full git histories
  of JHOVE, DROID, Tika and veraPDF added gigabytes to every image and every download, for
  trees nobody opened. The upstream repository and tag for each tool are recorded in
  `/usr/local/share/viper/manifest.json` instead.
- **`openjdk-17-doc` and `openjdk-17-source` are no longer installed.** Several hundred
  megabytes of Java reference material on an appliance with no offline development story.
- **The `viper` account now has administrative access** via sudo.

### Added

- **A Docker image built from the same Ansible roles as the VM.** The Packer and
  Docker lines had diverged into two copies of the same roles; from here one tag
  releases both. The container never installs `task-gnome-desktop`, gdm3 autologin
  or the GNOME dconf settings, because its webtop base supplies XFCE.
- Four tools that were previously only on one line or absent entirely: FIDO,
  jpylyzer, ODF Validator, OpenFixity, and veraPDF Arlington alongside veraPDF.

- `/usr/local/share/viper/manifest.json`, recording the ViPER version, build timestamp, OS
  release, and for each tool its version, upstream repository, tag and installer location,
  plus the MediaArea and Debian packages installed.
- Continuous integration on pull requests: yamllint, ansible-lint, Ansible syntax checks,
  shellcheck, and `packer fmt`/`packer validate`. Previously nothing ran until a release.
- `republish.yml`, which re-uploads an image from an earlier run's artifact so a transfer
  that fails near the end no longer requires rebuilding the appliance.

### Changed

- The release workflow builds the image once and publishes it from two independent jobs, so
  each upload gets its own GitHub Actions timeout budget. Previously both uploads shared one
  six hour job and the OVA upload was killed at roughly 80%.
- Artifacts are roughly half their previous size: QCOW2 4.95 GB to 2.36 GB, OVA about
  5.2 GB to 2.24 GiB.
- Release tags must now be three-component (`v1.3.0`, not `v1.3`). The workflow triggers on
  `v*.*.*`, and a two-component tag silently does not build.
- Tags matching a bare semver triple publish as full releases; anything with a suffix, such
  as `v1.3.0-rc1`, publishes as a prerelease.

### Fixed

- The OVF descriptor declared a machine that did not exist. Disk capacity, CPU count and
  memory were hardcoded and disagreed with the built image, which is what causes strict OVF
  importers to reject an appliance. All three are now derived from the image.
- The unattended install upgraded packages twice, once in the preseed and again in
  `viper.setup`. The preseed copy ran inside Packer's SSH timeout and grew with every month
  the pinned ISO aged, until builds stopped fitting.
- Guest additions no longer install `dkms`, `build-essential` or `linux-headers`. The
  modules ship in Debian's stock kernel, and pinning headers to the ISO's kernel version
  broke the build once that version aged out of the archive.

### Known limitations

- **The OVA is not VMware compatible.** The descriptor declares
  `VirtualSystemType = virtualbox-2.2` where VMware expects `vmx-NN`, inherited from the
  existing export format, and `ovftool` acceptance is unverified. See #75.
- **`manifest.json` records intent, not measurement.** It captures the tag Ansible was told
  to install rather than a checksum of what landed on disk.
- **`grub-pc` is removed** so a single-OS appliance shows no boot menu. The MBR and
  `/boot/grub/i386-pc/` are not package-owned so the image still boots, but a future kernel
  upgrade would leave `grub.cfg` stale.
- **The ISO stays pinned at Debian 12.8.0.** Bumping to 12.15.0 was tried and reverted; it
  made the unattended install roughly ten times slower, reproducibly. Measurements are
  recorded beside the pin in `viper.pkr.hcl`.
