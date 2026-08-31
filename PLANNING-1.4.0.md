# ViPER 1.4.0 planning

Written 2026-08-31, at the close of the 1.3.0-rc2 work. Nothing here is decided.

## The forcing issue: no Debian release runs the full tool set

This is the finding that changes 1.4.0 from a nice-to-have into a decision that has
to be made.

| Tool | Needs | Debian 12 | Debian 13 | Ubuntu 24.04 |
|---|---|---|---|---|
| MediaConch-GUI | `libqt5webkit5` | yes | **no** | yes |
| OpenFixity | `libasound2t64` | **no** | yes | yes |

MediaConch-GUI has kept ViPER on Debian 12 for a while, because Trixie dropped
`libqt5webkit5` (Debian bug #1069574). OpenFixity pulls the other way: its published
`.deb` is built against the 64-bit `time_t` transition, and those `t64` package names
do not exist in Bookworm.

**No Debian release satisfies both.** Ubuntu 24.04 LTS satisfies both and is supported
to 2029.

1.3.0-rc2 works around this by rewriting OpenFixity's dependency and repacking the
`.deb`, which is sound on amd64 because Bookworm's `libasound2` provides the same
`libasound.so.2` soname and the `t64` transition was a no-op on that architecture. The
workaround is guarded to Debian 12 and below so it disappears on a t64 base. It is a
holding position, not a fix.

## What an Ubuntu move actually costs

Researched previously; the shape has not changed, but the OpenFixity finding raises the
value of doing it.

Gains:

- Satisfies both MediaConch-GUI and OpenFixity without a workaround
- GNOME comes off the install media rather than the network, which is the current long
  pole locally, though much less so on a GitHub runner
- `virtualbox-guest-*` sits in universe, so the Debian Fasttrack dance in
  `install-guest-additions.sh` disappears

Costs, none of them small:

- Ubuntu Desktop uses subiquity autoinstall via cloud-init, so `http/preseed.cfg` is
  rewritten rather than adjusted
- The Ansible roles assume Debian throughout: `task-gnome-desktop` does not exist,
  gdm3 paths differ, and the `t64` library renames touch package lists
- It is a platform identity decision for OPF, not a change to slide in alongside other work

Caveat worth repeating: `libqt5webkit5` is already absent from Ubuntu 25.04, so 26.04
LTS will probably drop it too. Ubuntu buys runway to roughly 2029, not a cure. The real
fix is MediaArea shipping a Qt6 or WebEngine build of MediaConch-GUI, and that is worth
asking them for regardless of what ViPER does.

## The container is a separate question

The Docker image uses `linuxserver/webtop`, pinned to a specific hash, and that pin is
deliberate: upstream moved away from KasmVNC to another remote desktop mechanism and it
broke the wider CloudViPER ecosystem. Any attempt to move to a newer webtop, or to an
Ubuntu-based one, has to be tested against CloudViPER rather than against this image
alone.

A move to Ubuntu for the VM does not require the container to follow. XFCE was chosen
for lightness and still makes sense. But if the VM moves and the container does not,
the shared Ansible roles carry two OS assumptions instead of one, which is exactly the
divergence 1.3.0-rc2 spent effort undoing. Decide deliberately.

## Provenance: record what was fetched, not just what was asked for

`manifest.json` records each tool's upstream git tag, but the installed bytes come from
a release URL. Those are two separate assertions by upstream and nothing verifies they
correspond. What ViPER can stand behind today is "we fetched this URL".

Fix is cheap: record the sha256 of each downloaded artefact at build time. `get_url`
already returns a checksum, so it is a few lines in
`ansible/roles/viper.tools/tasks/manifest.yml`. For a preservation appliance this is
worth more than it costs.

## Tool versions still to consider

- **Tika** is held at 2.9.2. 3.x is available and 4.0.0 is published. 3.x is a major
  version and was deliberately not taken into a release already carrying four
  pre-release tools. It needs its own testing pass.
- **The four pre-release tools** in rc2 (ODF Validator beta, OpenFixity alpha, veraPDF
  Arlington dev build, and Tika held back) should be revisited before 1.4.0 ships. At
  least Arlington is pinned to a build number rather than a release tag, which is not a
  sustainable pin for a final release.

## Artifact server

`artifacts.opf-labs.org` gained HEAD support and `Content-Length` on downloads during
the 1.3.0 work, which fixed the upload verification and gave every downloader a progress
bar. It still ignores `Range`, so **downloads are not resumable**: a 2.3 GB OVA that
fails at 90% restarts from zero.

Supporting `Range` is nearly free on a newer FastAPI. Starlette's `FileResponse` gained
it in 0.39, and the pinned `fastapi==0.115.0` caps Starlette below that. `fastapi 0.115.6`
pulls Starlette 0.41.3 and handles ranges, suffix ranges, open-ended ranges and 416
correctly out of the box. The change is to stop hand-rolling `StreamingResponse` in the
download handler. Note that the upload path's streaming is a separate mechanism and must
not be touched: it uses `request.stream()` with a hand-rolled multipart parser so
multi-gigabyte uploads from Actions never buffer in memory.

Parked pending real-world evidence that users are hitting failed downloads.
