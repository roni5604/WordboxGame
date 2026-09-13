#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the WordBox Hebrew Flutter project.
# Installs a pinned Flutter SDK (matching .github/workflows/ci.yml) and fetches
# project dependencies. Safe to run repeatedly.
set -euo pipefail

FLUTTER_VERSION="3.35.5"
FLUTTER_HOME="/opt/flutter"
FLUTTER_TARBALL="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TARBALL}"

if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  echo "Installing Flutter ${FLUTTER_VERSION} to ${FLUTTER_HOME}..."
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/${FLUTTER_TARBALL}" "${FLUTTER_URL}"
  sudo tar -xf "${tmp}/${FLUTTER_TARBALL}" -C /opt
  sudo chown -R "$(id -u):$(id -g)" "${FLUTTER_HOME}"
  rm -rf "${tmp}"
else
  echo "Flutter already present at ${FLUTTER_HOME}, skipping download."
fi

# Expose flutter/dart on the default PATH so login shells and terminals find them.
sudo ln -sf "${FLUTTER_HOME}/bin/flutter" /usr/local/bin/flutter
sudo ln -sf "${FLUTTER_HOME}/bin/dart" /usr/local/bin/dart

# Flutter refuses to operate on a git checkout owned by another user.
git config --global --add safe.directory "${FLUTTER_HOME}" 2>/dev/null || true

export PATH="${FLUTTER_HOME}/bin:${PATH}"
flutter config --no-analytics --enable-web >/dev/null
flutter precache --web

flutter pub get
