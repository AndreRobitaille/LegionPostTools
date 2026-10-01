#!/usr/bin/env bash
# System packages for the Cloud Agent image: prebuilt Ruby matching .ruby-version,
# Bundler 4.0.3, and a local PostgreSQL 17 cluster. Idempotent. Safe to re-run
# on Ubuntu 24.04 as root or as the ubuntu user with passwordless sudo.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  as_root() { "$@"; }
else
  as_root() { sudo "$@"; }
fi

export DEBIAN_FRONTEND=noninteractive

RUBY_VERSION_FILE="${RUBY_VERSION_FILE:-}"
if [ -z "$RUBY_VERSION_FILE" ]; then
  if [ -f .ruby-version ]; then
    RUBY_VERSION_FILE=.ruby-version
  elif [ -f /workspace/.ruby-version ]; then
    RUBY_VERSION_FILE=/workspace/.ruby-version
  fi
fi

if [ -n "${RUBY_VERSION:-}" ]; then
  ruby_version="${RUBY_VERSION#ruby-}"
elif [ -n "$RUBY_VERSION_FILE" ]; then
  ruby_version="$(tr -d '[:space:]' < "$RUBY_VERSION_FILE")"
  ruby_version="${ruby_version#ruby-}"
else
  ruby_version="4.0.0"
fi

# ruby-builder bakes this GitHub Actions toolcache path into RUNPATH and shebangs.
ruby_prefix="/opt/hostedtoolcache/Ruby/${ruby_version}/x64"

echo "==> apt packages"
as_root apt-get update
as_root apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  libffi-dev \
  libgmp10 \
  libpq-dev \
  libssl-dev \
  libvips42t64 \
  libyaml-0-2 \
  libyaml-dev \
  pkg-config \
  postgresql-common \
  unzip \
  zlib1g-dev

if ! command -v google-chrome >/dev/null 2>&1 && ! [ -x /usr/bin/google-chrome ]; then
  echo "==> Google Chrome (system tests and computer use)"
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | as_root gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    | as_root tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
  as_root apt-get update
  as_root apt-get install -y --no-install-recommends google-chrome-stable
fi

if ! dpkg -s postgresql-17 >/dev/null 2>&1; then
  echo "==> PostgreSQL 17"
  as_root /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
  as_root apt-get install -y postgresql-17 postgresql-client-17
fi

if ! as_root pg_lsclusters --no-header 2>/dev/null | awk '{print $1,$2}' | grep -qx "17 main"; then
  echo "==> creating PostgreSQL 17 main cluster"
  as_root pg_createcluster 17 main
fi

echo "==> Ruby ${ruby_version} (prebuilt ubuntu-24.04-x64)"
if ! [ -x "${ruby_prefix}/bin/ruby" ] || ! "${ruby_prefix}/bin/ruby" -v | grep -q "ruby ${ruby_version}"; then
  tmp="$(mktemp -d)"
  url="https://github.com/ruby/ruby-builder/releases/download/ruby-${ruby_version}/ruby-${ruby_version}-ubuntu-24.04-x64.tar.gz"
  curl -fsSL -o "${tmp}/ruby.tar.gz" "$url"
  as_root rm -rf "$ruby_prefix"
  as_root mkdir -p "$ruby_prefix"
  as_root tar -xzf "${tmp}/ruby.tar.gz" -C "$ruby_prefix" --strip-components=1
  rm -rf "$tmp"
fi

for cmd in ruby gem bundle bundler irb rake; do
  if [ -e "${ruby_prefix}/bin/${cmd}" ]; then
    as_root ln -sfn "${ruby_prefix}/bin/${cmd}" "/usr/local/bin/${cmd}"
  fi
done

if ! "${ruby_prefix}/bin/gem" list -i bundler -v 4.0.3 >/dev/null 2>&1; then
  echo "==> Bundler 4.0.3"
  as_root "${ruby_prefix}/bin/gem" install bundler -v 4.0.3 --no-document
fi
as_root ln -sfn "${ruby_prefix}/bin/bundle" /usr/local/bin/bundle
as_root ln -sfn "${ruby_prefix}/bin/bundler" /usr/local/bin/bundler

# Stop a cluster this script started so the image has no live postmaster and
# no stale pid. start.sh brings it back on each boot.
if as_root pg_lsclusters --no-header | awk '$1==17 && $2=="main" && $4=="online" { found=1 } END { exit !found }'; then
  echo "==> stopping PostgreSQL so the image does not keep a live postmaster"
  as_root pg_ctlcluster 17 main stop
fi

echo "==> system setup complete: $(ruby -v); $(bundle -v); postgres $(psql --version)"
