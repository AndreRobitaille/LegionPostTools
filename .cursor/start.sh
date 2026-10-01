#!/usr/bin/env bash
# Per-boot services. PostgreSQL does not survive a snapshot, so start it here,
# then prepare development and test databases from the checked-out schema.
set -euo pipefail

cd "$(dirname "$0")/.."

pg_data="/var/lib/postgresql/17/main"
pidfile="${pg_data}/postmaster.pid"

clear_stale_pid() {
  if [ ! -f "$pidfile" ]; then
    return 0
  fi
  pid="$(head -n 1 "$pidfile" || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  echo "Removing stale PostgreSQL pid ${pid:-unknown}."
  sudo rm -f "$pidfile" /var/run/postgresql/17-main.pid
}

if ! pg_isready -q; then
  clear_stale_pid
  sudo pg_ctlcluster 17 main start
fi

ready=0
for _ in $(seq 1 30); do
  if pg_isready -q; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "PostgreSQL 17 did not become ready." >&2
  sudo pg_lsclusters || true
  exit 1
fi

db_user="$(id -un)"
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_user}'" | grep -q 1; then
  sudo -u postgres createuser --superuser "$db_user"
fi

psql -d postgres -c 'SELECT current_user, version();' >/dev/null

bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
echo "PostgreSQL is ready and legion_post_tools_test is prepared."
