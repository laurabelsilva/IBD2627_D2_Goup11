# Salus Group — Database Project (D2)

**Introduction to Databases | Group 11**

## Project Description

This repository contains the PostgreSQL implementation developed for the second deliverable (D2) of the Introduction to Databases course.

The project is based on the Salus Group case study and covers two main areas: homeopathic healthcare services and training management.

The database stores information about patients, homeopaths, consultations, prescriptions, training programs, sessions, participants, payments, invoices and certificates.

## Repository Contents

| File | Description |
|---|---|
| `schema.sql` | Table definitions, keys, constraints and triggers. |
| `data.sql` | Data used to populate the database. |
| `procedures.sql` | Stored functions and procedures. |
| `queries.sql` | Views and SQL queries. |
| `test.sql` | Functional and integrity tests. |
| `negative_tests.sql` | Tests for invalid operations and constraint violations. |

## Implementation

The database was implemented using PostgreSQL and PL/pgSQL, with DBeaver as the SQL development environment.

The implementation includes 22 tables, primary and foreign keys, integrity constraints, triggers, five views, stored routines and SQL queries covering data retrieval and manipulation.

## Execution Instructions

Create an empty PostgreSQL database and execute the scripts in the following order:

1. `schema.sql`
2. `data.sql`
3. `procedures.sql`
4. `queries.sql`
5. `test.sql`
6. `negative_tests.sql`

The schema script should only be executed on a new or disposable database, as it contains statements that drop existing tables.

## Testing

The project includes tests to verify the database structure, relationships, business rules and stored routines.

The negative tests check whether invalid operations are correctly rejected by the database. During development, all 15 negative tests passed.

## Authors

Group 11 — Introduction to Databases
