#!/usr/bin/env bash
# PackDrop — database backup.
#
# Why this exists: the repo holds a MAP of the schema (supabase/SCHEMA.md) and two
# migrations. It does not hold the 35 function bodies, the table DDL, or anyone's
# inventory. If the Supabase project is deleted, none of that can be rebuilt from git.
#
# Supabase plan reality (docs, Nov 2026):
#   Free       — NO automatic backups at all. This script is the only safety net.
#   Pro        — daily backups, 7 days retention (Team 14, Enterprise 30).
#   Pro+ add-on— Point-in-Time Recovery, ~2 min RPO, replaces daily backups.
#   Any plan   — deleting the project deletes its backups permanently.
#
# Usage:
#   ./scripts/backup.sh                 # schema only, safe to commit
#   ./scripts/backup.sh --with-data     # schema + rows — PII, keep OUT of git
#
# Needs the Supabase CLI and a login:  npm i -g supabase && supabase login
set -euo pipefail

PROJECT_REF="${PROJECT_REF:-mpriuxbhdfgdtsfhvpxt}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_DIR:-$HOME/packdrop-backups}"

mkdir -p "$OUT_DIR"

echo "== schema -> $OUT_DIR/schema-$STAMP.sql"
supabase db dump --project-ref "$PROJECT_REF" -f "$OUT_DIR/schema-$STAMP.sql"

if [[ "${1:-}" == "--with-data" ]]; then
  echo "== data -> $OUT_DIR/data-$STAMP.sql  (contains emails: do not commit)"
  supabase db dump --project-ref "$PROJECT_REF" --data-only -f "$OUT_DIR/data-$STAMP.sql"
  chmod 600 "$OUT_DIR/data-$STAMP.sql"
fi

# Keep the newest 14 of each so a bad backup does not quietly fill the disk.
ls -1t "$OUT_DIR"/schema-*.sql 2>/dev/null | tail -n +15 | xargs -r rm --
ls -1t "$OUT_DIR"/data-*.sql   2>/dev/null | tail -n +15 | xargs -r rm --

echo "== done. To verify the CLI can see server-side backups too:"
echo "   curl -H \"Authorization: Bearer \$SUPABASE_ACCESS_TOKEN\" \\"
echo "     https://api.supabase.com/v1/projects/$PROJECT_REF/database/backups"
