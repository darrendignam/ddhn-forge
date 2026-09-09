# Builds libqt5webkit5 for Ubuntu 26.04, which dropped the package.
#
# MediaConch's GUI links libQt5WebKit.so.5 and libQt5WebKitWidgets.so.5. Ubuntu carried
# qtwebkit-opensource-src until noble and dropped it from questing onward; Debian dropped
# it after bookworm. Qt 5.15 itself is still in 26.04, so the target has not moved, only
# the packaging is gone. Arch still maintains the patch stack in the AUR, which is where
# the toolchain fixes newer than Ubuntu's come from.
FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --no-install-recommends -y \
      build-essential devscripts equivs quilt ca-certificates curl xz-utils \
      bison cmake flex gperf ninja-build pkg-kde-tools pkgconf python3 ruby \
      libfontconfig-dev libgl-dev libglib2.0-dev libglu1-mesa-dev \
      libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev libhyphen-dev \
      libicu-dev libjpeg-dev libpng-dev libsqlite3-dev libwebp-dev libwoff-dev \
      libxcomposite-dev libxml2-dev libxrender-dev libxslt1-dev \
      libqt5opengl5-dev libqt5sensors5-dev libqt5webchannel5-dev \
      qtbase5-private-dev qtdeclarative5-private-dev qtpositioning5-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY build.sh /usr/local/bin/build-qtwebkit
COPY patches/ /build/extra-patches/
RUN chmod +x /usr/local/bin/build-qtwebkit

ENTRYPOINT ["/usr/local/bin/build-qtwebkit"]
