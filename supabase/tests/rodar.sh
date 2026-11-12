#!/usr/bin/env bash
# Roda as migrations e os testes num Postgres local descartável.
# Uso: supabase/tests/rodar.sh   (precisa de psql e de um Postgres em localhost)
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${DB:-teste_painel}"
PSQL="psql -X -v ON_ERROR_STOP=1 ${PGARGS:-}"
$PSQL -d postgres -qc "drop database if exists $DB" -c "create database $DB"
$PSQL -d postgres -qc "do \$\$ begin
  if not exists (select from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end \$\$"
sed '/^create role/d' tests/00_stub_supabase.sql | $PSQL -d "$DB" -q
for f in migrations/*.sql; do $PSQL -d "$DB" -q -f "$f"; done
$PSQL -d "$DB" -qAt -o /dev/null -f tests/10_regras_de_acesso.sql 2>&1 | sed -E "s/^psql:[^ ]+ NOTICE: +//"
