#!/usr/bin/env bash
# Best-effort ChromeDriver matching the installed Google Chrome. System tests
# look for /usr/bin/chromium and /usr/bin/chromedriver. Failure here does not
# fail install; bin/rails test does not run system tests.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  as_root() { "$@"; }
else
  as_root() { sudo "$@"; }
fi

chrome_bin=""
for candidate in /usr/bin/google-chrome /usr/bin/google-chrome-stable /usr/local/bin/google-chrome; do
  if [ -x "$candidate" ]; then
    chrome_bin="$candidate"
    break
  fi
done

if [ -z "$chrome_bin" ]; then
  echo "Chrome is not installed; skipping ChromeDriver. System tests will not run."
  exit 0
fi

version="$("$chrome_bin" --version | awk '{print $NF}')"
marker="/opt/chromedriver/.version"
if [ -x /usr/bin/chromedriver ] && [ "$(cat "$marker" 2>/dev/null || true)" = "$version" ]; then
  as_root ln -sfn "$chrome_bin" /usr/bin/chromium
  echo "ChromeDriver ${version} already installed."
  exit 0
fi

tmp="$(mktemp -d)"
url="https://storage.googleapis.com/chrome-for-testing-public/${version}/linux64/chromedriver-linux64.zip"
if ! curl -fsSL -o "${tmp}/chromedriver.zip" "$url"; then
  echo "ChromeDriver ${version} is not published; system tests will not run until it is installed."
  rm -rf "$tmp"
  exit 0
fi

unzip -q "${tmp}/chromedriver.zip" -d "$tmp"
as_root mkdir -p /opt/chromedriver
as_root install -m 0755 "${tmp}/chromedriver-linux64/chromedriver" /opt/chromedriver/chromedriver
echo "$version" | as_root tee "$marker" >/dev/null
as_root ln -sfn /opt/chromedriver/chromedriver /usr/local/bin/chromedriver
as_root ln -sfn /opt/chromedriver/chromedriver /usr/bin/chromedriver
as_root ln -sfn "$chrome_bin" /usr/bin/chromium
rm -rf "$tmp"
echo "Installed ChromeDriver ${version}."
