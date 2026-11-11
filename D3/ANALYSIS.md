# Salus D3 - NoSQL Analysis and Justification

## 1. What We Store in MongoDB

PostgreSQL remains the main database for Salus. It is still used for payments,
invoices, purchases, and rules that need strong relational integrity.

For MongoDB, we selected two parts of the system that are normally read as
complete documents:

- `patient_case_files`
- `participant_training_profiles`

### Patient case files

One `patient_case_files` document represents one patient and contains:

```text
patient
assignedHomeopaths[]
consultations[]
  symptoms[]
  prescription
    medication
```

In PostgreSQL, opening one patient history requires several tables: `patient`,
`person`, `consultation`, `symptom`, `prescription`, `medication`, and
`patient_homeopath`. In MongoDB, the homeopath can read the relevant patient
history from one document.

### Participant training profiles

One `participant_training_profiles` document represents one participant and
contains:

```text
participant
purchases[]
  payment
  enrollment
  accessibleSessions[]
    lecturer
    recording
certificates[]
  coveredSessions[]
```

This matches a participant dashboard: the participant usually wants to see
purchases, paid status, sessions, recordings, and certificates together.

## 2. Why MongoDB Is Suitable

### Patient case files

- Different patients have different numbers of consultations and symptoms.
- Consultation notes and symptom descriptions are flexible text fields.
- A `WAIT` prescription has no medication, while a `MEDICATE` prescription
  includes medication details.
- When a new consultation happens, it can be added to that patient's
  `consultations` array.

### Participant training profiles

- A single-session purchase contains one session, while a package purchase
  contains six sessions. MongoDB arrays represent both cases naturally.
- A participant may have no certificate, one certificate, or several
  certificates.
- A new purchase or certificate can be added to one participant profile.
- The participant portal can read one document instead of joining many
  relational tables for one screen.

MongoDB is useful here because the data is nested, variable, and usually read
together. PostgreSQL is still better for the original payment and invoice
transactions.

## 3. Mapping from PostgreSQL to MongoDB

### `patient_case_files`

- The document `_id` is the original `patient.patient_id`.
- `patient` comes from `person`.
- `assignedHomeopaths[]` comes from `patient_homeopath`, `homeopath`, and
  `person`.
- `consultations[]` comes from `consultation`.
- `consultations.symptoms[]` comes from `symptom`.
- `consultations.prescription` and its optional `medication` come from
  `prescription` and `medication`.

The consultations are embedded because they belong to one patient and are
normally read as a history. Symptoms and prescriptions are embedded because
they belong to one consultation.

### `participant_training_profiles`

- The document `_id` is the original `participant.participant_id`.
- `participant` combines `participant` and `person`.
- `purchases[]` combines `purchase`, its subtype, `payment`, and
  `enrollment`.
- `accessibleSessions[]` comes from `session`, `cycle`, `lecturer`, and
  `recording`.
- `certificates[]` comes from `certificate`.
- `coveredSessions[]` comes from `certificate_session` and `session`.

We use embedding, not MongoDB references, because these fields are shown
together in one participant dashboard. The original PostgreSQL IDs such as
`sessionId` and `purchaseId` are kept so that the migration can be checked
and refreshed later.

## 4. Other NoSQL Options

### Graph database

A graph database could be useful for the training network:

```text
Participant -> Purchase -> Cycle -> Session -> Training Programme
```

It would help with multi-step questions, for example: which participants
completed one programme and later enrolled in another programme?

### Key-Value database

A key-value database such as Redis could cache temporary recording access:

```text
recording-access:<participantId>:<sessionId>
```

The value could contain the recording URL and expiry date. This is useful
because recording access ends after the allowed period.

## 5. Migration and Consistency

The migration exports one JSON document per patient and per participant from
PostgreSQL. The JSON Lines files are imported with `mongoimport`.

The original PostgreSQL IDs are preserved in MongoDB. After import, the project
compares equivalent counts in both systems:

- patients and participant profiles;
- consultations and symptoms;
- purchases and paid purchases;
- certificates and certificate-session links.

All eight checks passed in the final test.
