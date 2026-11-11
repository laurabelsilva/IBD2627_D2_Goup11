#
# The shell script automates the migration in five steps: 
# it exports two JSON Lines files and the PostgreSQL counts, 
# recreates the MongoDB collections and indexes, 
# imports the documents with mongoimport, 
# and finally compares equivalent counts in PostgreSQL and MongoDB.
#
#
# Optional environment variables:
#   PGDATABASE  PostgreSQL source database (default: salus_d2)
#   MONGO_URI   MongoDB server URI (default: mongodb://127.0.0.1:27017)
#   MONGO_DB    MongoDB target database (default: salus_d3)

# Stop immediately if a command fails, an unset variable is used, or a pipeline fails.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/generated"
PGDATABASE="${PGDATABASE:-salus_d2}"
MONGO_URI="${MONGO_URI:-mongodb://127.0.0.1:27017}"
MONGO_DB="${MONGO_DB:-salus_d3}"
MONGO_TARGET="${MONGO_URI}/${MONGO_DB}"

mkdir -p "$OUTPUT_DIR"

echo "1/5 Exporting patient case files from PostgreSQL database: $PGDATABASE"
psql -X -qAt -v ON_ERROR_STOP=1 -d "$PGDATABASE" \
    -f "$PROJECT_ROOT/migration/export_patient_case_files.sql" \
    > "$OUTPUT_DIR/patient_case_files.jsonl"

echo "2/5 Exporting participant training profiles"
psql -X -qAt -v ON_ERROR_STOP=1 -d "$PGDATABASE" \
    -f "$PROJECT_ROOT/migration/export_participant_training_profiles.sql" \
    > "$OUTPUT_DIR/participant_training_profiles.jsonl"

echo "3/5 Exporting PostgreSQL consistency counts"
psql -X -qAt -v ON_ERROR_STOP=1 -d "$PGDATABASE" \
    -f "$PROJECT_ROOT/migration/export_sync_counts.sql" \
    > "$OUTPUT_DIR/postgres_sync_counts.json"

echo "4/5 Creating MongoDB model and importing documents into: $MONGO_DB"
# Recreate only the two D3 collections before loading a fresh migration.
mongosh "$MONGO_TARGET" --quiet --file "$PROJECT_ROOT/mongodb/01_model_and_indexes.js"
mongoimport --uri "$MONGO_TARGET" --collection patient_case_files \
    --file "$OUTPUT_DIR/patient_case_files.jsonl" --type json --mode insert
mongoimport --uri "$MONGO_TARGET" --collection participant_training_profiles \
    --file "$OUTPUT_DIR/participant_training_profiles.jsonl" --type json --mode insert

echo "5/5 Checking MongoDB counts against PostgreSQL"
# Pass the exported PostgreSQL counts to the MongoDB verification script.
export SYNC_FILE="$OUTPUT_DIR/postgres_sync_counts.json"
mongosh "$MONGO_TARGET" --quiet --file "$PROJECT_ROOT/mongodb/04_consistency_checks.js"

echo "Migration completed successfully."
