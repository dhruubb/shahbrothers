#!/usr/bin/env bash
# Loads the schema + demo seed into a throwaway local PostgreSQL database
# (with a minimal Supabase auth stub) and runs the RLS / billing tests.
#   PGURL="postgresql://postgres@localhost:5432/postgres" bash supabase/tests/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
PGURL="${PGURL:-postgresql://postgres@localhost:5432/postgres}"
DB=shah_brothers_test
psql "$PGURL" -q -c "drop database if exists $DB" -c "create database $DB"
TEST_URL="${PGURL%/*}/$DB"
psql "$TEST_URL" -q -v ON_ERROR_STOP=1 -f supabase/tests/supabase_stub.sql
psql "$TEST_URL" -q -v ON_ERROR_STOP=1 -f supabase/migrations/0001_init.sql
psql "$TEST_URL" -q -v ON_ERROR_STOP=1 -f supabase/seed.sql > /dev/null
PSQL="psql $TEST_URL" python3 supabase/tests/rls_test.py
