
# Salus - Database Project - D3

- Group 11
- NoSQL DBMS: MongoDB
- Relational source: PostgreSQL Salus D2 database

## Authors

- Ana Paula Tavares - 68081
- Laura Silva - 68469
- Xiaoji Wu - 59800

## Overview

This project extends the Salus D2 PostgreSQL database with a MongoDB component.

PostgreSQL remains the main database for transactions and integrity rules. MongoDB is used for two document-oriented components:

- patient case files, containing consultations, symptoms, prescriptions, and medication;
- participant training profiles, containing purchases, payment status, sessions, recordings, and certificates.

The detailed NoSQL analysis, embedding decisions, and PostgreSQL-to-MongoDB mapping are available in `ANALYSIS.md`.

## Project Files

- `ANALYSIS.md` - NoSQL analysis, justification, mapping, and alternative NoSQL databases.
- `mongodb/01_model_and_indexes.js` - creates MongoDB collections, validation rules, and indexes.
- `mongodb/02_data_checks.js` - shows document counts, embedded-data counts, and sample documents.
- `mongodb/03_crud_and_queries.js` - runs ten aggregation queries (Q1-Q10) and four CRUD operations (Q11-Q14).
- `mongodb/04_consistency_checks.js` - compares 12 MongoDB consistency metrics with PostgreSQL.
- `migration/export_patient_case_files.sql` - exports one JSON document per patient.
- `migration/export_participant_training_profiles.sql` - exports one JSON document per participant.
- `migration/export_sync_counts.sql` - exports PostgreSQL counts and monetary totals for consistency checks.
- `migration/migrate_from_postgres.sh` - runs the complete migration automatically.

## Requirements

Before running the project, make sure that you have:

- PostgreSQL 14+ with the completed Salus D2 database;
- MongoDB Community Server running locally;
- MongoDB Shell (`mongosh`);
- MongoDB Database Tools (`mongoimport`).

The migration script uses these defaults:

```text
PostgreSQL source database: salus_d2
MongoDB target database:    salus_d3
MongoDB URI:                mongodb://127.0.0.1:27017
```

The PostgreSQL database name, server, port, and user can be configured using environment variables.

## Running the Migration

Open Terminal inside the D3 folder. The location is different on each computer.

```bash
cd path/to/IBD2627_D2_Goup11/D3
```

Confirm that MongoDB is running:

```bash
mongosh --eval 'db.runCommand({ ping: 1 })'
```

The command should return:

```text
{ ok: 1 }
```

Give execution permission to the migration script once:

```bash
chmod +x migration/migrate_from_postgres.sh
```

If the D2 PostgreSQL database has a different name or connection settings, configure them before running the migration.

For example, the local demonstration database used in our tests is configured with:

```bash
export PGHOST=localhost
export PGPORT=8520
export PGUSER=postgres
export PGDATABASE=IBD2627_Demo
```

For another computer or PostgreSQL installation, use the corresponding connection settings.

Run the complete migration:

```bash
./migration/migrate_from_postgres.sh
```

The script performs the following five steps:

1. exports patient case files from PostgreSQL as JSON Lines files;
2. exports participant training profiles from PostgreSQL as JSON Lines files;
3. exports PostgreSQL consistency counts and monetary totals;
4. creates the MongoDB collections, validation rules, and indexes, and imports the JSON documents with `mongoimport`;
5. compares the 12 PostgreSQL and MongoDB consistency metrics.

The migration does not change the PostgreSQL D2 database. It recreates only the two D3 collections in MongoDB:

```text
patient_case_files
participant_training_profiles
```

Running the migration again refreshes these two collections from the PostgreSQL source.

## Testing

Run the basic MongoDB data checks:

```bash
mongosh "mongodb://127.0.0.1:27017/salus_d3" \
  --file mongodb/02_data_checks.js
```

Run the ten aggregation queries (Q1-Q10) and the CRUD demonstration (Q11-Q14):

```bash
mongosh "mongodb://127.0.0.1:27017/salus_d3" \
  --file mongodb/03_crud_and_queries.js
```

The aggregation queries analyse patient histories, symptoms, homeopaths, prescriptions, training purchases, recordings, payments, and certificates.

The CRUD demonstration creates, reads, updates, and deletes a temporary patient document. The final output should include:

```text
Temporary document remaining: 0
```

Run the consistency check separately if needed:

```bash
export SYNC_FILE=generated/postgres_sync_counts.json

mongosh "mongodb://127.0.0.1:27017/salus_d3" \
  --file mongodb/04_consistency_checks.js
```

The final report should show `PASS` for all 12 checks.

These checks include document and embedded-data counts, patient-homeopath relationships, WAIT prescriptions without medication, and monetary totals compared in cents.

All 12 checks passed during the previous local migration test. The updated D3 files must be tested again before delivery.

## Expected Data

With the provided Salus D2 population data, the migration creates:

```text
450 patient case files
500 participant training profiles
225 embedded consultations
225 embedded symptoms
1002 embedded purchases
968 paid purchases
4 certificates
30 certificate-session links
450 patient-homeopath links
25 WAIT prescriptions without medication
7,274,000 cents in total purchases
7,027,500 cents in paid amounts
```

The files in `generated/` are created automatically during migration and should not be edited manually.

The generated export files are local migration outputs and do not need to be committed to the GitHub repository.

## Demonstration Video

The five-minute demonstration video should present the D3 implementation and its relationship with the existing Salus D2 database.

The demonstration should include:

1. the PostgreSQL source database and the two selected MongoDB document models;
2. the execution of the PostgreSQL-to-MongoDB migration;
3. the imported collections and their embedded document structures;
4. the ten MongoDB aggregation queries and the four CRUD operations;
5. the 12 PostgreSQL-to-MongoDB consistency checks.

The video should demonstrate that MongoDB complements the existing PostgreSQL implementation without changing the original D1 and D2 database design.
