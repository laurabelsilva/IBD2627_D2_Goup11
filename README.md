# Salus Group Database Project - D2

Introduction to Databases - Group 11
DBMS: PostgreSQL 14+  
Development environment: PostgreSQL and DBeaver

## Authors

- Ana Paula Tavares - 68081
- Laura Silva - 68469
- Xiaoji Wu - 59800

## Project Files

- `schema.sql` - tables, primary keys, foreign keys, constraints, and triggers.
- `data.sql` - automatic population of consistent test data.
- `procedures.sql` - stored function and procedure.
- `queries.sql` - five views and twenty SQL operations.
- `test.sql` - positive and integrity-validation tests.
- `negative_tests.sql` - fifteen invalid-operation tests.
- `README.md` - execution instructions.

## Requirements

- PostgreSQL 14 or later.
- DBeaver, pgAdmin, or the PostgreSQL terminal (`psql`).

## Execution Order

Create a new, empty database and run these files in order:

1. `schema.sql`
2. `data.sql`
3. `procedures.sql`
4. `queries.sql`

The test files are optional but recommended:

5. `test.sql`
6. `negative_tests.sql`

> Important: `schema.sql` contains `DROP TABLE IF EXISTS` statements. Run it only in a new or disposable database.

## Running with DBeaver

1. Connect to your PostgreSQL server.
2. Create a new empty database, for example `salus_d2`.
3. Open the six files in DBeaver.
4. Execute them in the order shown above.
5. Check that `test.sql` reports zero integrity violations.
6. Check that `negative_tests.sql` reports 15 PASS and 0 FAIL.

## Running with Terminal

Open Terminal and go to the folder containing the SQL files:

```bash
cd /path/to/IBD2627_D2_Group11
```

Create a new database:

```bash
createdb salus_d2
```

Run the four core scripts:

```bash
psql -d salus_d2 -v ON_ERROR_STOP=1 -f schema.sql
psql -d salus_d2 -v ON_ERROR_STOP=1 -f data.sql
psql -d salus_d2 -v ON_ERROR_STOP=1 -f procedures.sql
psql -d salus_d2 -v ON_ERROR_STOP=1 -f queries.sql
```

Run the optional validation scripts:

```bash
psql -d salus_d2 -v ON_ERROR_STOP=1 -f test.sql
psql -d salus_d2 -v ON_ERROR_STOP=1 -f negative_tests.sql
```

To inspect the database manually, open `psql`:

```bash
psql -d salus_d2
```

For example:

```sql
SELECT COUNT(*) AS total_persons
FROM person;

SELECT *
FROM v_revenue_per_cycle
ORDER BY cycle_id;
```

Exit `psql` with:

```text
\q
```

## Main Features

- 22 relational tables with primary keys, foreign keys, and integrity constraints.
- More than 1,000 automatically generated records.
- Complex business rules implemented with PostgreSQL triggers.
- Five views for common reports.
- Twenty SQL operations: sixteen reads, one create, two updates, and one delete.
- Two stored routines:
  - `fn_paid_training_hours(...)` calculates paid training hours.
  - `sp_issue_certificate(...)` issues a certificate and associates its paid sessions.

## Expected Test Results

`test.sql` should show:

- zero integrity violations;
- rows returned by all five views;
- 24 paid hours for participant 1, programme 1, during 2024;
- a temporary certificate created by the procedure and removed by `ROLLBACK`.

`negative_tests.sql` should show:

```text
total_tests  = 15
passed_tests = 15
failed_tests = 0
```

## Final Submission

Include the SQL files, this README, the editable D2 ER diagram (`.drawio`), an exported diagram image or PDF, and the demonstration video.

Submit the final archive as:

```text
IBD2627_D2_Group11.zip
```

