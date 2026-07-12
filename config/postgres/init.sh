#!/usr/bin/env bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v cache_db="$POSTGRES_CACHE_DB" \
  -v queue_db="$POSTGRES_QUEUE_DB" <<'SQL'
CREATE DATABASE :"cache_db";
CREATE DATABASE :"queue_db";
SQL
