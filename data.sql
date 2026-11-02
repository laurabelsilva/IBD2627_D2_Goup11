
/*
 * Salus data population script.
 * More than 1,000 records distributed across the database.
 * Includes normal cases and edge cases for the required queries.
 *
 * @author Ana Paula Tavares 68081
 * @author Laura Silva 68469
 * @author Xiaoji Wu 59800
 */

-- The transaction allows deferred constraints to be checked
-- after all related records have been inserted.

BEGIN;


-- 1. Persons and roles

DO $$
DECLARE
    first_names TEXT[] := ARRAY[
        'Ana', 'Beatriz', 'Catarina', 'Diogo', 'Ines',
        'Joao', 'Laura', 'Maria', 'Miguel', 'Pedro',
        'Rita', 'Rui', 'Sofia', 'Tiago', 'Vasco'
    ];

    last_names TEXT[] := ARRAY[
        'Silva', 'Santos', 'Ferreira', 'Pereira',
        'Oliveira', 'Costa', 'Rodrigues', 'Martins',
        'Sousa', 'Fernandes', 'Gomes', 'Almeida'
    ];

    i INT;
    first_name TEXT;
    last_name TEXT;
BEGIN
    FOR i IN 1..1000 LOOP
        first_name := first_names[((i - 1) % 15) + 1];
        last_name := last_names[((i - 1) % 12) + 1];

        INSERT INTO person (name, email, phone, country)
        VALUES (
            first_name || ' ' || last_name,
            lower(first_name || '.' || last_name || i || '@salus.pt'),
            '+351 9' || lpad(i::TEXT, 8, '0'),
            CASE i % 4
                WHEN 0 THEN 'Portugal'
                WHEN 1 THEN 'Spain'
                WHEN 2 THEN 'Brazil'
                ELSE 'France'
            END
        );
    END LOOP;
END $$;


-- 500 participants

INSERT INTO participant (
    participant_id,
    student_number,
    training_level
)
SELECT person_id,
       'STU' || lpad(person_id::TEXT, 5, '0'),
       CASE
           WHEN person_id % 2 = 0 THEN 'Beginner'
           ELSE 'Advanced'
       END
FROM person
WHERE person_id BETWEEN 1 AND 500;


-- 50 homeopaths

INSERT INTO homeopath (homeopath_id)
SELECT person_id
FROM person
WHERE person_id BETWEEN 501 AND 550;


-- 450 patients

INSERT INTO patient (patient_id)
SELECT person_id
FROM person
WHERE person_id BETWEEN 551 AND 1000;


-- Homeopaths can also be lecturers.
-- The PERSON specialization allows overlapping roles.

INSERT INTO lecturer (lecturer_id)
SELECT homeopath_id
FROM homeopath;


-- Every patient is assigned to one homeopath.

INSERT INTO patient_homeopath (
    patient_id,
    homeopath_id
)
SELECT patient_id,
       501 + ((patient_id - 551) % 50)
FROM patient;


-- 2. Training programmes, cycles, sessions, and recordings

INSERT INTO training_program (
    name,
    description
)
VALUES
    ('Erik van Woensel International Studygroup',
     'International classical homeopathy training.'),
    ('Classical Homeopathy - Level 1',
     'Foundation programme for beginner participants.');


-- Nine historical cycles.

INSERT INTO cycle (
    start_date,
    end_date,
    training_program_id
)
SELECT DATE '2024-01-08' + ((i - 1) * 56),
       DATE '2024-01-08' + ((i - 1) * 56) + 35,
       CASE
           WHEN i <= 6 THEN 1
           ELSE 2
       END
FROM generate_series(1, 9) AS g(i);


-- Current cycle: provides active recordings for Q10.

INSERT INTO cycle (
    start_date,
    end_date,
    training_program_id
)
VALUES (
    CURRENT_DATE - 7,
    CURRENT_DATE + 28,
    1
);


-- Exactly six weekly two-hour sessions for every cycle.
-- One lecturer conducts every session in the same cycle.

INSERT INTO session (
    session_date,
    topic,
    case_description,
    duration_minutes,
    agenda,
    zoom_link,
    cycle_id,
    lecturer_id
)
SELECT c.start_date + ((n.session_number - 1) * 7),
       'Clinical Case Study ' || c.cycle_id || '.' || n.session_number,
       'Guided analysis of a classical homeopathy patient case.',
       120,
       'Case discussion and repertorisation',
       'https://zoom.us/j/salus-' || c.cycle_id || '-' || n.session_number,
       c.cycle_id,
       501 + ((c.cycle_id - 1) % 50)
FROM cycle c
CROSS JOIN generate_series(1, 6) AS n(session_number);


-- The recording trigger guarantees the 21-day availability period.

INSERT INTO recording (
    available_from,
    available_until,
    recording_url,
    session_id
)
SELECT s.session_date,
       s.session_date + 21,
       'https://recordings.salus.pt/session/' || s.session_id,
       s.session_id
FROM session s;


-- 3. Purchases, enrollments, payments, and invoices

-- 500 package purchases distributed through cycles 1 to 9.

INSERT INTO purchase (
    purchase_date,
    total_amount,
    participant_id
)
SELECT c.start_date - 7,
       120.00,
       i
FROM generate_series(1, 500) AS g(i)
JOIN cycle c
    ON c.cycle_id = ((i - 1) % 9) + 1;


INSERT INTO package_purchase (
    purchase_id,
    package_price
)
SELECT purchase_id,
       120.00
FROM purchase
WHERE total_amount = 120.00;


INSERT INTO enrollment (
    registration_date,
    purchase_id,
    cycle_id
)
SELECT purchase_date + 1,
       purchase_id,
       ((participant_id - 1) % 9) + 1
FROM purchase
WHERE total_amount = 120.00;


-- Edge case: participant 1 purchases extra cycles.

INSERT INTO purchase (
    purchase_date,
    total_amount,
    participant_id
)
VALUES (
    DATE '2024-02-26',
    120.00,
    1
);


INSERT INTO package_purchase (
    purchase_id,
    package_price
)
VALUES (
    currval('purchase_purchase_id_seq'),
    120.00
);


INSERT INTO enrollment (
    registration_date,
    purchase_id,
    cycle_id
)
VALUES (
    DATE '2024-02-27',
    currval('purchase_purchase_id_seq'),
    2
);


-- Participant 1 also purchases the current cycle.

INSERT INTO purchase (
    purchase_date,
    total_amount,
    participant_id
)
VALUES (
    CURRENT_DATE - 14,
    120.00,
    1
);


INSERT INTO package_purchase (
    purchase_id,
    package_price
)
VALUES (
    currval('purchase_purchase_id_seq'),
    120.00
);


INSERT INTO enrollment (
    registration_date,
    purchase_id,
    cycle_id
)
VALUES (
    CURRENT_DATE - 13,
    currval('purchase_purchase_id_seq'),
    10
);


-- 500 single-session purchases distributed through all sessions.

INSERT INTO purchase (
    purchase_date,
    total_amount,
    participant_id
)
SELECT s.session_date - 7,
       25.00,
       i
FROM generate_series(1, 500) AS g(i)
JOIN session s
    ON s.session_id = ((i - 1) % 60) + 1;


INSERT INTO single_session_purchase (
    purchase_id,
    session_price
)
SELECT purchase_id,
       25.00
FROM purchase
WHERE total_amount = 25.00;


INSERT INTO enrollment (
    registration_date,
    purchase_id,
    session_id
)
SELECT purchase_date + 1,
       purchase_id,
       ((participant_id - 1) % 60) + 1
FROM purchase
WHERE total_amount = 25.00;


-- Some purchases remain unpaid: useful for certificate and invoice tests.
-- Every payment automatically creates one invoice.

INSERT INTO payment (
    payment_method,
    amount_paid,
    payment_date,
    purchase_id
)
SELECT CASE purchase_id % 3
           WHEN 0 THEN 'Credit Card'
           WHEN 1 THEN 'MB Way'
           ELSE 'Bank Transfer'
       END,
       total_amount,
       purchase_date + 1,
       purchase_id
FROM purchase
WHERE purchase_id % 29 <> 0;


-- Create both SENT and NOT_SENT invoice cases.

UPDATE invoice
SET status = 'SENT',
    sent_date = issue_date + 1
WHERE invoice_id <= 50;


-- 4. Clinical consultations, prescriptions, medication, and symptoms

-- Medication is stored independently from prescriptions.
-- The same medication can be referenced by multiple prescriptions.

INSERT INTO medication (
    name,
    potency,
    form
)
VALUES
    ('Belladonna', '30C', 'Globules'),
    ('Nux Vomica', '200C', 'Globules');


-- 150 Initial consultations.

INSERT INTO consultation (
    consultation_date,
    type,
    notes,
    patient_id,
    homeopath_id
)
SELECT DATE '2024-02-01' + ((patient_id - 551) % 28),
       'Initial',
       'Initial assessment and symptom history recorded.',
       patient_id,
       homeopath_id
FROM patient_homeopath
WHERE patient_id BETWEEN 551 AND 700;


-- Every Initial consultation receives a MEDICATE prescription.

INSERT INTO prescription (
    decision,
    dosage,
    instructions,
    consultation_id,
    medication_id
)
SELECT 'MEDICATE',
       'Two globules twice daily',
       'Take away from food and strong flavours.',
       consultation_id,
       (
           SELECT medication_id
           FROM medication
           WHERE name = 'Belladonna'
             AND potency = '30C'
       )
FROM consultation
WHERE type = 'Initial';


-- 75 Follow-up consultations.

INSERT INTO consultation (
    consultation_date,
    type,
    notes,
    patient_id,
    homeopath_id
)
SELECT DATE '2024-03-15' + ((patient_id - 551) % 21),
       'Follow-up',
       'Follow-up review of progress and treatment response.',
       patient_id,
       homeopath_id
FROM patient_homeopath
WHERE patient_id BETWEEN 551 AND 625;


-- Follow-ups include MEDICATE and WAIT cases.
-- WAIT prescriptions have no medication.
-- MEDICATE prescriptions reference an existing medication.

INSERT INTO prescription (
    decision,
    dosage,
    instructions,
    consultation_id,
    medication_id
)
SELECT CASE
           WHEN patient_id % 3 = 0 THEN 'WAIT'
           ELSE 'MEDICATE'
       END,
       CASE
           WHEN patient_id % 3 = 0 THEN NULL
           ELSE 'One dose every evening'
       END,
       CASE
           WHEN patient_id % 3 = 0
               THEN 'Observe symptoms for two weeks before reassessment.'
           ELSE 'Review response at the next consultation.'
       END,
       consultation_id,
       CASE
           WHEN patient_id % 3 = 0 THEN NULL
           ELSE (
               SELECT medication_id
               FROM medication
               WHERE name = 'Nux Vomica'
                 AND potency = '200C'
           )
       END
FROM consultation
WHERE type = 'Follow-up';


-- Symptoms for consultation-history reports.

INSERT INTO symptom (
    name,
    description,
    consultation_id
)
SELECT CASE consultation_id % 3
           WHEN 0 THEN 'Headache'
           WHEN 1 THEN 'Insomnia'
           ELSE 'Digestive discomfort'
       END,
       'Recorded during the consultation for clinical follow-up.',
       consultation_id
FROM consultation;


-- 5. Certificates

-- total_hours is derived by fn_paid_training_hours.
-- Every certificate is issued for one training programme and one period.

INSERT INTO certificate (
    period_start,
    period_end,
    issue_date,
    participant_id,
    training_program_id
)
VALUES
    (DATE '2024-01-01', DATE '2024-12-31',
     DATE '2025-01-10', 1, 1),

    (DATE '2024-01-01', DATE '2024-12-31',
     DATE '2025-01-10', 2, 1),

    (DATE '2024-01-01', DATE '2024-12-31',
     DATE '2025-01-10', 3, 1),

    (DATE '2024-01-01', DATE '2025-12-31',
     DATE '2026-01-10', 7, 2);


-- A certificate covers paid sessions within its training programme
-- and certification period.

INSERT INTO certificate_session (
    certificate_id,
    session_id
)
SELECT DISTINCT
       cert.certificate_id,
       s.session_id
FROM certificate cert
JOIN purchase p
    ON p.participant_id = cert.participant_id
JOIN payment pay
    ON pay.purchase_id = p.purchase_id
JOIN enrollment e
    ON e.purchase_id = p.purchase_id
JOIN session s
    ON (
        e.session_id = s.session_id
        OR e.cycle_id = s.cycle_id
    )
JOIN cycle c
    ON c.cycle_id = s.cycle_id
WHERE c.training_program_id = cert.training_program_id
  AND s.session_date BETWEEN cert.period_start AND cert.period_end;


COMMIT;


-- 6. Data population checks

-- These queries verify the populated database.

SELECT 'person' AS table_name, COUNT(*) AS total FROM person
UNION ALL
SELECT 'participant', COUNT(*) FROM participant
UNION ALL
SELECT 'homeopath', COUNT(*) FROM homeopath
UNION ALL
SELECT 'patient', COUNT(*) FROM patient
UNION ALL
SELECT 'lecturer', COUNT(*) FROM lecturer
UNION ALL
SELECT 'patient_homeopath', COUNT(*) FROM patient_homeopath
UNION ALL
SELECT 'training_program', COUNT(*) FROM training_program
UNION ALL
SELECT 'cycle', COUNT(*) FROM cycle
UNION ALL
SELECT 'session', COUNT(*) FROM session
UNION ALL
SELECT 'recording', COUNT(*) FROM recording
UNION ALL
SELECT 'purchase', COUNT(*) FROM purchase
UNION ALL
SELECT 'package_purchase', COUNT(*) FROM package_purchase
UNION ALL
SELECT 'single_session_purchase', COUNT(*) FROM single_session_purchase
UNION ALL
SELECT 'enrollment', COUNT(*) FROM enrollment
UNION ALL
SELECT 'payment', COUNT(*) FROM payment
UNION ALL
SELECT 'invoice', COUNT(*) FROM invoice
UNION ALL
SELECT 'consultation', COUNT(*) FROM consultation
UNION ALL
SELECT 'prescription', COUNT(*) FROM prescription
UNION ALL
SELECT 'medication', COUNT(*) FROM medication
UNION ALL
SELECT 'symptom', COUNT(*) FROM symptom
UNION ALL
SELECT 'certificate', COUNT(*) FROM certificate
UNION ALL
SELECT 'certificate_session', COUNT(*) FROM certificate_session
ORDER BY table_name;
