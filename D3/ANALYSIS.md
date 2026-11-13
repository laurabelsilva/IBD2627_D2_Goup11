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
For example, Patient A → 1 consultation, 1 symptom
    Patient B → 5 consultations, many symptoms
- Consultation notes and symptom descriptions are flexible text fields.
- A `WAIT` prescription has no medication, while a `MEDICATE` prescription
  includes medication details.
- When a new consultation happens, it can be added to that patient's
  `consultations` array.
For example, a new patient may have an empty consultations array, while
another patient may have one Initial consultation and several Follow-up
consultations. Both cases can be stored in the same document structure.

### Participant training profiles

- A single-session purchase contains one session, while a package purchase
  contains six sessions. MongoDB arrays represent both cases naturally.
- A participant may have no certificate, one certificate, or several
  certificates.
- A new purchase or certificate can be added to one participant profile.
- The participant portal can read one document instead of joining many
  relational tables for one screen.
In Salus, a package purchase gives access to the six sessions of one cycle.
This is a small and bounded array, so embedding the sessions in the
participant profile is practical for the dashboard.

MongoDB is useful here because the data is nested, variable, and usually read
together. This follows the document-model principle discussed in class: data
that is commonly accessed together can be stored together in one document.
PostgreSQL is still better for payment and invoice transactions.

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

We use embedding instead of MongoDB references because the participant dashboard
displays these fields together. The accessible session details are copied into
the participant profile. Although a session can appear in more than one
profile, a package contains only six sessions and the original `sessionId` and
`purchaseId` are retained. If session data changes in PostgreSQL, running the
migration again refreshes the related MongoDB profiles.

## 4. Other NoSQL Options

### Graph database

A graph database could be useful for the training network:

```text
Participant -> Purchase -> Enrollment -> Cycle -> Session
Cycle -> Training Programme
```

It would help with connection-based questions, for example: which participants
completed one training programme and later bought a package in another programme?

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
