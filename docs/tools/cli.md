---
layout: page
title: ViPER Command Line Reference
---
# Command Line Reference

Every tool below is on `PATH` in a ViPER terminal. The examples are the ones seeded into
the shell history, so typing the first word offers the rest of the line as a grey
suggestion; press the right arrow to accept it.

The GUI tools are unchanged and still available from the desktop and the menu. This page
covers running the same tools from a terminal, which is what you need for batch work,
scripting, scheduled jobs and feeding output into other systems.

## Identification and validation

### JHOVE

Format identification, validation and characterisation. Pick a module with `-m`.

```bash
jhove -m PDF-hul  -h xml -o report.xml document.pdf
jhove -m TIFF-hul -h xml -o report.xml image.tif
jhove -m JPEG-hul -h xml -o report.xml photo.jpg
jhove -l                                   # list installed modules
```

`-h` selects the output handler: `xml`, `text`, `json` or `audit`.

### DROID

Format identification against PRONOM. DROID works in profiles: build one over a
directory, then export it.

```bash
droid -a /path/to/collection -p profile.droid    # build a profile
droid -p profile.droid -e report.csv             # export to CSV
droid -x                                          # list signature file versions
```

Running `droid` with no arguments opens the GUI, which is why `droid-gui` is the same
script.

### FIDO

Fast format identification, PRONOM based. Well suited to piping.

```bash
fido -recurse /path/to/collection
fido -matchprintf "%(info.filename)s,%(info.puid)s\n" file.pdf
fido -input filelist.txt
```

### Siegfried-style output from FIDO

FIDO's `-matchprintf` and `-nomatchprintf` take Python format strings, so you can shape
CSV or TSV directly rather than post-processing.

### veraPDF

PDF/A and PDF/UA validation.

```bash
verapdf -f 2b --format text document.pdf
verapdf -f 1b --format xml  document.pdf
verapdf --format mrr -f 2b document.pdf > report.xml    # machine readable report
verapdf -f 0 document.pdf                               # auto detect flavour
```

Flavours are `1a 1b 2a 2b 2u 3a 3b 3u 4 4e 4f`, or `0` to detect from the file.

### Arlington PDF Model Checker

Checks PDF structure against the Arlington PDF Model. A veraPDF development build.

```bash
arlington-pdf-model-checker document.pdf
```

### jpylyzer

JP2 validation.

```bash
jpylyzer image.jp2
jpylyzer --recurse /path/to/images
```

### ODF Validator

```bash
odf-validator document.odt
```

### MediaConch

Policy checking for audiovisual files.

```bash
mediaconch -p policy.xml video.mkv
mediaconch --Format=XML video.mkv
mediaconch -iv video.mkv                   # implementation checks
```

### MediaInfo

Technical metadata for audiovisual files.

```bash
mediainfo --Output=XML  video.mkv
mediainfo --Output=JSON video.mkv
mediainfo --Inform="Video;%Width%x%Height%" video.mkv
```

## Characterisation and text extraction

### Apache Tika

```bash
tika --detect document.docx                # media type only
tika --text document.docx > document.txt
tika --metadata --json document.docx
tika --config=tika-config.xml file.pdf
```

`tika-gui` opens the graphical version of the same jar.

### ExifTool

Reads and writes embedded metadata across most formats.

```bash
exiftool -a -G1 file.tif                   # all tags, grouped
exiftool -json -r /path/to/collection      # recursive, JSON out
exiftool -all= -overwrite_original copy.jpg    # strip all metadata
exiftool -csv -r /path > metadata.csv
```

## PDF

### Ghostscript

```bash
gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress \
   -sOutputFile=out.pdf in.pdf
gs -dNOPAUSE -dBATCH -sDEVICE=png16m -r300 -sOutputFile=page%03d.png in.pdf
```

### qpdf

Structural PDF work that does not re-render the page content.

```bash
qpdf --check document.pdf                  # structural report
qpdf --linearize in.pdf out.pdf            # fast web view
qpdf --decrypt --password=secret locked.pdf open.pdf
qpdf --split-pages in.pdf page.pdf
qpdf --json in.pdf                          # structure as JSON
```

### poppler-utils

```bash
pdfinfo document.pdf
pdftotext -layout document.pdf out.txt
pdfimages -list document.pdf
pdftoppm -r 300 -png document.pdf page
```

### OCRmyPDF, and PDF to PDF/A

This is the normalisation path. `--output-type pdfa` produces a file that the bundled
veraPDF then validates as compliant.

```bash
ocrmypdf --skip-text --output-type pdfa in.pdf pdfa.pdf     # no OCR, just normalise
ocrmypdf -l eng --output-type pdfa scanned.pdf pdfa.pdf     # OCR then normalise
ocrmypdf --output-type pdfa --optimize 3 in.pdf out.pdf
```

Round trip, both halves shipped in ViPER:

```bash
verapdf -f 2b --format text in.pdf                          # not compliant
ocrmypdf --skip-text --output-type pdfa in.pdf pdfa.pdf
verapdf -f 2b --format text pdfa.pdf                        # compliant
```

### img2pdf

Wraps images in a PDF without re-encoding them, so the pixels are untouched.

```bash
img2pdf scan1.tif scan2.tif -o scanned.pdf
```

## Images

### ImageMagick

Ubuntu 24.04 ships ImageMagick 6, so the commands are `convert`, `identify` and
`mogrify`. Most current ImageMagick documentation online shows the version 7 syntax,
where everything is a subcommand of `magick`. That binary does not exist here.

```bash
convert input.jpg -resize 50% output.jpg
convert input.tif -colorspace sRGB -quality 90 output.jpg
convert input.tif -compress lzw output.tif
identify -verbose image.tif
mogrify -path thumbs -resize 512x512 *.tif
```

### libvips

Much lower memory than ImageMagick on large images, which matters for scanned material.

```bash
vips copy input.tif output.tif[compression=lzw]
vipsheader -a image.tif
vips thumbnail input.tif thumb.jpg 512
```

### Tesseract

```bash
tesseract scan.tif out -l eng pdf          # searchable PDF
tesseract scan.tif out -l eng txt
tesseract --list-langs
```

### unpaper

Pre-OCR cleanup: deskew, despeckle, remove scan edges.

```bash
unpaper input.pnm output.pnm
```

## Audio and video

### FFmpeg

```bash
ffprobe -v error -show_format -show_streams video.mkv
ffmpeg -i input.mov -c:v ffv1 -level 3 -c:a flac preservation.mkv   # lossless master
ffmpeg -i input.mkv -c:v libx264 -crf 20 -c:a aac access.mp4        # access copy
ffmpeg -i input.wav -c:a flac output.flac
ffmpeg -i input.mkv -f framemd5 -                                    # per frame checksums
```

FFV1 in Matroska with FLAC audio is the common preservation target, and `framemd5` gives
you frame level fixity that survives rewrapping.

## Fixity, packaging and plumbing

### hashdeep and coreutils

```bash
hashdeep -r -c sha256 /path/to/collection > manifest.txt
hashdeep -r -a -k manifest.txt /path/to/collection      # audit against manifest
sha256sum -c checksums.txt
```

### Archives

```bash
7z a -mx=9 package.7z /path/to/collection
7z l package.7z
unar archive.rar
```

### OpenFixity

Fixity checking with a graphical interface, launched from the desktop or the menu.

### XML and JSON

For METS, PREMIS, MediaConch policies and tool reports.

```bash
xmllint --noout --schema mets.xsd package.xml
xmllint --format report.xml
xmlstarlet sel -t -v "//premis:eventType" -n premis.xml
jq '.[] | {name, status}' report.json
jq -r '.files[] | [.name, .checksum] | @csv' manifest.json
```

`jq` and `xmlstarlet` are the join between tool output and anything downstream, including
scripted pipelines and language model prompts that expect structured input.

### rclone

One client for OneDrive, Google Drive, S3, Dropbox, Box, SFTP, WebDAV and around
seventy other backends. Installed from upstream rather than Ubuntu's archive, because
Ubuntu ships a 2022 build and provider OAuth flows change.

Configure a remote once, interactively. The name you give it is what you refer to
afterwards:

```bash
rclone config                              # add a remote, e.g. "onedrive" or "gdrive"
rclone listremotes                         # what is configured
```

On a headless or browser-only session the OAuth step cannot open a browser. Use:

```bash
rclone config --no-auto-browser            # prints a URL to open yourself
rclone authorize "onedrive"                # or authorise on another machine and paste
```

Everyday transfers:

```bash
rclone ls        onedrive:Archive
rclone lsjson    gdrive:Deposits > listing.json
rclone copy      /local/batch onedrive:Archive/batch --progress
rclone sync      /local/batch onedrive:Archive/batch --progress    # makes destination match
rclone mount     gdrive: ~/gdrive --daemon                          # browse it in Caja
```

`copy` adds and updates. `sync` deletes anything at the destination that is not at the
source, so reach for `copy` unless you mean it, and try `--dry-run` first.

**The part that matters for preservation.** rclone can verify rather than assume:

```bash
rclone check /local/batch onedrive:Archive/batch --one-way
rclone hashsum sha256 onedrive:Archive/batch
rclone copy /local/batch onedrive:Archive/batch --checksum
rclone lsf --format "ps" --hash sha256 onedrive:Archive > remote-manifest.txt
```

`--checksum` compares hashes rather than size and timestamp. `rclone check` compares
both sides and reports differences. `hashsum` produces checksums computed by the
provider where it supports them, so a copy to cloud storage can be verified with the
same rigour as `hashdeep` locally.

### rsync

For local moves and anything reachable over SSH.

```bash
rsync -av --progress /source/ /destination/
rsync -av --checksum /source/ /destination/          # compare contents, not timestamps
rsync -av --dry-run /source/ user@host:/destination/
rsync -av --partial --append-verify /big/file user@host:/dest/
```

The trailing slash on the source matters: `/source/` copies the contents, `/source`
copies the directory itself.

### SQLite

```bash
sqlite3 catalogue.db "SELECT puid, count(*) FROM files GROUP BY puid;"
```

## Worked example: characterise, normalise, verify

```bash
# 1. What is it
fido -recurse /path/to/batch > identified.csv

# 2. Validate the PDFs
for f in /path/to/batch/*.pdf; do
  verapdf -f 2b --format mrr "$f" > "reports/$(basename "$f").xml"
done

# 3. Normalise anything non compliant
ocrmypdf --skip-text --output-type pdfa in.pdf pdfa.pdf

# 4. Prove the normalised file is compliant
verapdf -f 2b --format text pdfa.pdf

# 5. Record fixity over the result
hashdeep -r -c sha256 /path/to/output > manifest.txt
```
