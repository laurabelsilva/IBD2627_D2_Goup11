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
- `mongodb/03_crud_and_queries.js` - runs ten aggregation queries and CRUD operations.
- `mongodb/04_consistency_checks.js` - compares MongoDB totals with PostgreSQL totals.
- `migration/export_patient_case_files.sql` - exports one JSON document per patient.
- `migration/export_participant_training_profiles.sql` - exports one JSON document per participant.
- `migration/export_sync_counts.sql` - exports PostgreSQL counts for consistency checks.
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

If the D2 PostgreSQL database has a name other than `salus_d2`, set it before running the migration. For example:

```bash
export PGDATABASE=salus_d2_fulltest
```

Run the complete migration:

```bash
./migration/migrate_from_postgres.sh
```

The script performs the following steps:

1. exports patient case files and participant training profiles from PostgreSQL as JSON Lines files;
2. creates the MongoDB collections, validation rules, and indexes;
3. imports the JSON documents with `mongoimport`;
4. compares equivalent PostgreSQL and MongoDB counts.

The migration does not change the PostgreSQL D2 database. It recreates only the two D3 collections in MongoDB:

```text
patient_case_files
participant_training_profiles
```

## Testing

Run the basic MongoDB data checks:

```bash
mongosh "mongodb://127.0.0.1:27017/salus_d3" \
  --file mongodb/02_data_checks.js
```

Run the ten aggregation queries and the CRUD demonstration:

```bash
mongosh "mongodb://127.0.0.1:27017/salus_d3" \
  --file mongodb/03_crud_and_queries.js
```

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

The final report should show `PASS` for all eight checks.

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
```

The files in `generated/` are created automatically during migration and should not be edited manually.

## Demonstration Video

The demonstration video should be no longer than five minutes and should show:

1. the D3 project files and `ANALYSIS.md`;
2. the PostgreSQL-to-MongoDB migration;
3. the successful consistency check;
4. selected aggregation queries;
5. the CRUD demonstration, including the final delete.

## Final Submission

Submit the D3 scripts, `ANALYSIS.md`, this README, and the demonstration video
in an archive named:

```text
IBD2627_D3_Group11.zip
```
