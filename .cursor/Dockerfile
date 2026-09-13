FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=/opt/flutter/bin:/usr/local/bin:${PATH}

# System packages required by the Flutter SDK and its web toolchain.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 24.04 ships a default "ubuntu" user (uid 1000); create it if missing.
RUN id ubuntu >/dev/null 2>&1 || useradd -m -u 1000 -s /bin/bash ubuntu

# Install a pinned Flutter SDK (matches .github/workflows/ci.yml).
ARG FLUTTER_VERSION=3.35.5
RUN curl -fsSL -o /tmp/flutter.tar.xz \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter \
    && ln -sf /opt/flutter/bin/dart /usr/local/bin/dart \
    && chown -R ubuntu:ubuntu /opt/flutter \
    && git config --system --add safe.directory /opt/flutter

USER ubuntu

# Warm the SDK: enable web, disable analytics, and pre-download web artifacts
# so the first agent boot does not pay that cost.
RUN flutter config --no-analytics --enable-web \
    && flutter precache --universal --web \
    && flutter --version
