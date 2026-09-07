# Changelog

Notable changes to the ViPER appliance. Dates are release dates; unreleased work sits
under the next version heading.

The GitHub "What's Changed" list is generated from pull request titles and does not
surface behaviour changes that affect existing users. Those belong here, under
**Behaviour changes**, so they can be lifted straight into release notes.

## v1.4.0-alpha (unreleased)

An alpha. Three of the bundled tools are pre-release upstream, and the operating
system and desktop have both changed, so this is for evaluation rather than for
production work.

**It supersedes `v1.3.0-rc1`**, published 2026-08-31, which carried the reworked
Packer pipeline and the new tools but still ran Debian 12 with GNOME. No final
v1.3.0 followed, so that candidate's notes are folded in here rather than left
stranded: everything below applies to anyone moving from it.

The last full release is **ViPER v1.2**, from August 2024. Anyone upgrading from
there is reading one note covering three releases' worth of change, and every
behaviour change below applies to them.

Two things define this release. The appliance moves from Debian 12 with GNOME to
**Ubuntu 24.04 with the MATE desktop and Linux Mint theming**, and the Packer
pipeline that builds it now publishes the VM images and the Docker container from a
single tag.

The operating system moved because no Debian release runs the full tool set.
MediaConch-GUI needs `libqt5webkit5`, which Debian 13 dropped, and OpenFixity needs
`libasound2t64`, which Debian 12 has no concept of. Noble carries both. Mint supplies
the theming on top rather than the base, because Mint ships no unattended installer.

### Pre-release tools, read this first

Three of the bundled tools are **not stable upstream releases**. This is deliberate,
but anyone relying on ViPER for production work should know which results come from
pre-release software. Each is recorded in `/usr/local/share/viper/manifest.json` with
its exact version and origin.

| Tool | Version | Status |
|---|---|---|
| ODF Validator | `0.20-beta-1` | Beta. Carries substantial improvements over the 0.18.x line and was close to becoming a release candidate. Chosen over stable `0.18.5` for those improvements. |
| OpenFixity | `0.1.1-ALPHA` | Alpha, and the only line published so far. |
| veraPDF Arlington | `1.31.174` | Published under `/dev/` and versioned by build number, so this pins a development build rather than a release tag. Installed alongside stable veraPDF, not replacing it. |

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
- **The `viper` account now has a password, and `sudo` asks for it.** Earlier images
  left it blank, which Ubuntu's `nullok` accepted, so `sudo` was satisfied by pressing
  Enter. The password ships with the machine rather than being published here. Treat it
  as a speed bump against an accidental administrative command, not a security boundary:
  console access to a ViPER machine, or a copy of its disk image, is root access.
- **The desktop is MATE with Linux Mint theming, not GNOME.** Panel layout, the
  applications menu, the file manager (Caja, not Nautilus) and the settings tools are all
  different. Anything scripted against GNOME tooling on a v1.2 image needs revisiting.
- **The operating system is Ubuntu 24.04, not Debian 12.** Apt sources, package names and
  release codenames all change. Anything a user installed with `apt` on a previous image
  should be reinstalled rather than assumed present.
- **The tools run on Java 21, not Java 17.** DROID 6.9.13's jars are compiled for class
  file version 65 and fail on a 17 runtime. JHOVE, Tika, veraPDF, Arlington and the ODF
  validator all run unchanged on 21, so one runtime serves everything.
- **Apache Tika moves to 3.3.2**, a major version, because that is the current stable
  line and the tool should track it. `v1.3.0-rc1` held it at 2.9.2 so that any failure
  during the pipeline rework stayed attributable; with that rework settled, the hold has
  served its purpose. Parser behaviour and metadata field names may differ from a v1.2
  image, and upstream's changelog does not enumerate the differences, so re-check any
  workflow that parses Tika's output.

### Added

- **A Docker image built from the same Ansible roles as the VM.** The Packer and
  Docker lines had diverged into two copies of the same roles; from here one tag
  releases both. The container runs the same MATE desktop and Mint theming as the VM,
  reached in a browser through its webtop base, and skips only what a container has no
  use for: the display manager, autologin and the host level security packages.
- Four tools that were previously only on one line or absent entirely: FIDO,
  jpylyzer, ODF Validator, OpenFixity, and veraPDF Arlington alongside veraPDF.

- `/usr/local/share/viper/manifest.json`, recording the ViPER version, build timestamp, OS
  release, and for each tool its version, upstream repository, tag and installer location,
  plus the MediaArea and Debian packages installed.
- Continuous integration on pull requests: yamllint, ansible-lint, Ansible syntax checks,
  shellcheck, and `packer fmt`/`packer validate`. Previously nothing ran until a release.
- `republish.yml`, which re-uploads an image from an earlier run's artifact so a transfer
  that fails near the end no longer requires rebuilding the appliance.
- **A full height system monitor sidebar** built on Conky, and an applications menu entry
  to toggle it. A virtual machine gives none of the cues a physical one does: no fans
  spinning up, no drive noise. Some tools appear to hang under load, and the sidebar shows
  that the machine is working.
- **Desktop launchers are marked trusted for Caja**, so they run on a double click rather
  than showing "Untrusted application launcher".
- `acl`, so Ansible can hand a file to an unprivileged account during the build.

### Changed

- The release workflow builds the image once and publishes it from two independent jobs, so
  each upload gets its own GitHub Actions timeout budget. Previously both uploads shared one
  six hour job and the OVA upload was killed at roughly 80%.
- Artifacts are smaller than v1.2 despite carrying more tools and a full desktop: QCOW2
  4.95 GB to 3.33 GB, OVA about 5.2 GB to 3.20 GB. Both are published with an md5 and a
  sha256 that the artifact server verifies on receipt.
- Release tags must now be three-component (`v1.4.0`, not `v1.4`). The workflow triggers on
  `v*.*.*`, and a two-component tag silently does not build.
- Tags matching a bare semver triple publish as full releases; anything with a suffix, such
  as `v1.4.0-rc1`, publishes as a prerelease.
- The unattended install is an Ubuntu autoinstall document rather than a Debian preseed.
  Ubuntu Server is used rather than the Mint ISO because Mint ships only the live session
  installer, which has no supported unattended path.
- The network is left to NetworkManager rather than being configured twice.

### Fixed

- The OVF descriptor declared a machine that did not exist. Disk capacity, CPU count and
  memory were hardcoded and disagreed with the built image, which is what causes strict OVF
  importers to reject an appliance. All three are now derived from the image.
- The unattended install upgraded packages twice, once in the preseed and again in
  `viper.setup`. The preseed copy ran inside Packer's SSH timeout and grew with every month
  the pinned ISO aged, until builds stopped fitting.
- Guest additions no longer install `dkms`, `build-essential` or `linux-headers`. The
  modules ship in the distribution's stock kernel, and pinning headers to the ISO's kernel
  version broke the build once that version aged out of the archive.
- The installer ISO is fetched with retries that resume, rather than by Packer's own
  getter, which makes a single attempt and abandons it at a hardcoded thirty minutes. One
  stalled connection used to cost an entire build.
- The container's desktop session starts on its own message bus. It previously used
  `dbus-launch --exit-with-session`, which ties the bus to an X connection that may not
  exist yet, and roughly one container start in nine came up to an error dialog and no
  desktop.
- The published container no longer carries the build container's `sleep infinity` command,
  and now records the ViPER commit that produced it. It previously described itself as its
  upstream base image.

### Known limitations

- **The OVA is not VMware compatible.** The descriptor declares
  `VirtualSystemType = virtualbox-2.2` where VMware expects `vmx-NN`, inherited from the
  existing export format, and `ovftool` acceptance is unverified. See #75.
- **`manifest.json` records intent, not measurement.** It captures the tag Ansible was told
  to install rather than a checksum of what landed on disk.
- **`grub-pc` is removed** so a single-OS appliance shows no boot menu. The MBR and
  `/boot/grub/i386-pc/` are not package-owned so the image still boots, but a future kernel
  upgrade would leave `grub.cfg` stale.
- **The ISO is pinned at Ubuntu 24.04.4.** Measure the install rate before bumping it: a
  Debian point release bump once made the unattended install roughly ten times slower,
  reproducibly, and cost a day. The reasoning is recorded beside the pin in
  `viper.pkr.hcl`.
- **No `spice-vdagent`.** QEMU and KVM users get no automatic resizing, no shared clipboard
  and no drag and drop. The desktop is not resolution capped and `xrandr` applies a larger
  mode by hand, it simply does not follow the client window. Tracked as
  openpreserve/ViPER#111.
- **Twelve desktop launchers overflow a 768 pixel high screen.** They are all present and
  work; the lowest are below the fold until the display is made taller.
- **`manifest.json` distinguishes the two appliances only by `"platform"`**, which reads
  `"vm"` or `"container"`. Both are otherwise built from the same roles at the same tool
  versions.
