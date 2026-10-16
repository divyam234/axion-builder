# AxionOS ARM64 builder — Ubuntu 24.04 aarch64.
# ika has NO ready Docker builder (only native ./ika-build for Fedora/Debian/Arch),
# so this reuses ika's ARM64-host patch set + prebuilt logic inside a container.
FROM docker.io/library/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    UBUNTU_ENABLE_KISAK_MESA=true \
    USE_CCACHE=1 CCACHE_DIR=/srv/axion/.ccache CCACHE_MAXSIZE=50G

# Lineage/Axion ROM deps + ika ARM64 provisioning deps (curl/git-lfs/jdk/cmake/ninja)
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  bc bison build-essential ccache curl flex git git-lfs \
  gnupg gperf imagemagick \
  libelf-dev liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop \
  pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev \
  python3 python3-pip openjdk-21-jdk cmake ninja-build file unzip tar dwarves \
  7zip adb android-sdk-libsparse-utils e2fsprogs erofs-utils gawk kmod lz4 \
  ca-certificates sudo locales \
 && git lfs install --system \
 && locale-gen en_US.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

# repo tool (same URL ika uses)
RUN curl -L --fail https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo \
 && chmod 0755 /usr/local/bin/repo

RUN useradd -m -s /bin/bash -G sudo builder && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER builder
WORKDIR /srv/axion
