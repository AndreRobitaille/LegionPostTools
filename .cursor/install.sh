#!/usr/bin/env bash
# Repository bootstrap. Runs after checkout, including on a warm snapshot.
# Idempotent: bundle install is a no-op when Gemfile.lock is already satisfied.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v ruby >/dev/null 2>&1 || ! command -v bundle >/dev/null 2>&1; then
  echo "Ruby or Bundler is missing. The image should run .cursor/setup-system.sh first." >&2
  exit 1
fi

expected="$(tr -d '[:space:]' < .ruby-version)"
expected="${expected#ruby-}"
actual="$(ruby -e 'print RUBY_VERSION')"
if [ "$actual" != "$expected" ]; then
  echo "Ruby ${actual} does not match .ruby-version (${expected})." >&2
  exit 1
fi

bundle _4.0.3_ config set --global path "${HOME}/.bundle/vendor"
bundle _4.0.3_ config set --global jobs "$(nproc)"
bundle _4.0.3_ check || bundle _4.0.3_ install

bash .cursor/setup-chromedriver.sh
