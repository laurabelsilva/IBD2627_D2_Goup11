#!/usr/bin/env bash
# Salus D3 - PostgreSQL to MongoDB Migration
#
# @author Ana Paula Tavares 68081
# @author Laura Silva 68469
# @author Xiaoji Wu 59800
#
# This script automates the migration in five steps:
# 1. Export patient case files.
# 2. Export participant training profiles.
# 3. Export PostgreSQL consistency counts.
# 4. Create MongoDB collections and import documents.
# 5. Compare PostgreSQL and MongoDB consistency metrics.
#
# Optional environment variables:
# PGDATABASE - PostgreSQL source database (default: salus_d2)
# MONGO_URI  - MongoDB server URI (default: mongodb://127.0.0.1:27017)
# MONGO_DB   - MongoDB target database (default: salus_d3)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/generated"

PGDATABASE="${PGDATABASE:-salus_d2}"
MONGO_URI="${MONGO_URI:-mongodb://127.0.0.1:27017}"
MONGO_DB="${MONGO_DB:-salus_d3}"
MONGO_TARGET="${MONGO_URI}/${MONGO_DB}"

# Locate PostgreSQL tools automatically on Windows Git Bash.
if ! command -v psql >/dev/null 2>&1; then
    for pg_bin in /c/Program\ Files/PostgreSQL/*/bin; do
        if [[ -x "$pg_bin/psql.exe" ]]; then
            export PATH="$pg_bin:$PATH"
            break
        fi
    done
fi

# Locate MongoDB Database Tools on Windows Git Bash.
if ! command -v mongoimport >/dev/null 2>&1; then
    for tools_bin in /c/Program\ Files/MongoDB/Tools/*/bin; do
        if [[ -x "$tools_bin/mongoimport.exe" ]]; then
            export PATH="$tools_bin:$PATH"
            break
        fi
    done
fi

# Check required tools.
for required_tool in psql mongoimport mongosh; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        echo "Missing command: $required_tool. See D3/README.md." >&2
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR"

# Step 1: Export patient case files.
echo "1/5 Exporting patient case files from PostgreSQL database: $PGDATABASE"

psql -X -qAt -v ON_ERROR_STOP=1 -d "$PGDATABASE" \
    -f "$PROJECT_ROOT/migration/export_patient_case_files.sql" \
    > "$OUTPUT_DIR/patient_case_files.jsonl"

# Step 2: Export participant training profiles.
echo "2/5 Exporting participant training profiles"

psql -X -qAt -v ON_ERROR_STOP=1 -d "$PGDATABASE" \
    -f "$PROJECT_ROOT/migration/export_participant_training_profiles.sql" \
    > "$OUTPUT_DIR/participant_training_profiles.jsonl"

# Step 3: Export PostgreSQL consistency counts.
echo "3/5 Exporting PostgreSQL consistency counts"

psql -X -qAt -v ON_ERROR_STOP=1 -d "$PGDATABASE" \
    -f "$PROJECT_ROOT/migration/export_sync_counts.sql" \
    > "$OUTPUT_DIR/postgres_sync_counts.json"

# Step 4: Create MongoDB model and import documents.
echo "4/5 Creating MongoDB model and importing documents into: $MONGO_DB"

# Recreate only the two D3 collections before importing.
mongosh "$MONGO_TARGET" --quiet \
    --file "$PROJECT_ROOT/mongodb/01_model_and_indexes.js"

mongoimport --uri "$MONGO_TARGET" \
    --collection patient_case_files \
    --file "$OUTPUT_DIR/patient_case_files.jsonl" \
    --type json --mode insert

mongoimport --uri "$MONGO_TARGET" \
    --collection participant_training_profiles \
    --file "$OUTPUT_DIR/participant_training_profiles.jsonl" \
    --type json --mode insert

# Step 5: Verify consistency between PostgreSQL and MongoDB.
echo "5/5 Checking MongoDB counts against PostgreSQL"

export SYNC_FILE="$OUTPUT_DIR/postgres_sync_counts.json"

mongosh "$MONGO_TARGET" --quiet \
    --file "$PROJECT_ROOT/mongodb/04_consistency_checks.js"

echo "Migration completed successfully."
