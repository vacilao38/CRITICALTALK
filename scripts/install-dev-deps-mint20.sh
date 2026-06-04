#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash scripts/install-dev-deps-mint20.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
  ca-certificates \
  clang \
  cmake \
  curl \
  file \
  git \
  libglu1-mesa \
  libgtk-3-dev \
  ninja-build \
  openjdk-17-jdk \
  pkg-config \
  postgresql-client \
  unzip \
  xz-utils \
  zip

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

if ! command -v docker >/dev/null 2>&1; then
  apt-get install -y docker.io docker-compose
fi

if ! command -v snap >/dev/null 2>&1; then
  apt-get install -y snapd
fi

if command -v snap >/dev/null 2>&1 && ! command -v flutter >/dev/null 2>&1; then
  snap install flutter --classic
fi

echo
echo "Development dependencies installed."
echo "Recommended next checks:"
echo "  flutter doctor"
echo "  node --version"
echo "  npm --version"
echo "  docker --version"
echo "  psql --version"
echo
echo "If Docker was installed now, log out and back in after adding your user to the docker group:"
echo "  sudo usermod -aG docker \$USER"
