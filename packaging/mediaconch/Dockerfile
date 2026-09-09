# Builds MediaConch for Ubuntu 26.04, against the libqt5webkit5 built by ../qtwebkit.
#
# MediaArea publish an apt suite for resolute but it carries MediaInfo only, with no
# MediaConch at all: not the GUI, not the CLI, not the library. Their newest build of any
# kind is 25.04 and targets Debian 12 or Ubuntu 24.04, both of which link libxml2.so.2.
# 26.04 ships libxml2 2.15 as libxml2.so.16, so the published debs would not run here even
# if QtWebKit were solved. Building from source fixes both at once.
FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive

# tofrodos is not in MediaConch's Build-Depends but debian/rules calls fromdos in
# override_dh_installchangelogs. It builds on MediaArea's own machines because it
# happens to be installed there; on a clean image the build dies at the packaging
# stage with 127 after compiling everything successfully.
RUN apt-get update && apt-get install --no-install-recommends -y \
      build-essential debhelper devscripts dh-autoreconf dh-python \
      ca-certificates curl gnupg xz-utils \
      qt5-qmake qtbase5-dev libxml2-dev libxslt1-dev libsqlite3-dev \
      libjansson-dev zlib1g-dev pkg-config libcurl4-gnutls-dev libevent-dev \
      python3-all \
      tofrodos \
    && rm -rf /var/lib/apt/lists/*

# libmediainfo-dev and libzen-dev come from MediaArea's own resolute suite. Their repo
# package pulls in the signing key and sources.list entry in one step.
RUN curl -fsSL -o /tmp/repo-mediaarea.deb \
      https://mediaarea.net/repo/deb/repo-mediaarea_1.0-25_all.deb \
    && apt-get install -y /tmp/repo-mediaarea.deb \
    && apt-get update \
    && apt-get install --no-install-recommends -y libmediainfo-dev libzen-dev \
    && rm -f /tmp/repo-mediaarea.deb && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY build.sh /usr/local/bin/build-mediaconch
RUN chmod +x /usr/local/bin/build-mediaconch

ENTRYPOINT ["/usr/local/bin/build-mediaconch"]
