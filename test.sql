
/*
 * Salus Database - Positive Test Script
 *
 * Run after:
 * 1. schema.sql
 * 2. data.sql
 * 3. procedures.sql
 * 4. queries.sql
 *
 * Expected:
 * - All values in the integrity validation report are 0.
 * - Views return rows.
 * - Function returns 24 for participant 1, program 1, in 2024.
 * - Procedure creates a temporary certificate with associated sessions.
 * - ROLLBACK removes the temporary certificate and its associations.
 *
 * @author Ana Paula Tavares 68081
 * @author Laura Silva 68469
 * @author Xiaoji Wu 59800
 */


-- =========================================================
-- 1. DATA VOLUME
-- =========================================================

SELECT
    (SELECT COUNT(*) FROM person) AS persons,
    (SELECT COUNT(*) FROM participant) AS participants,
    (SELECT COUNT(*) FROM patient) AS patients,
    (SELECT COUNT(*) FROM homeopath) AS homeopaths,
    (SELECT COUNT(*) FROM lecturer) AS lecturers,
    (SELECT COUNT(*) FROM consultation) AS consultations,
    (SELECT COUNT(*) FROM session) AS sessions,
    (SELECT COUNT(*) FROM recording) AS recordings,
    (SELECT COUNT(*) FROM purchase) AS purchases,
    (SELECT COUNT(*) FROM enrollment) AS enrollments,
    (SELECT COUNT(*) FROM payment) AS payments,
    (SELECT COUNT(*) FROM invoice) AS invoices,
    (SELECT COUNT(*) FROM certificate) AS certificates,
    (SELECT COUNT(*) FROM certificate_session) AS certificate_sessions;

-- Expected:
-- 1000 persons, 500 participants, 450 patients, 50 homeopaths,
-- 50 lecturers, 60 sessions, 60 recordings,
-- 1002 purchases/enrollments, 968 payments/invoices,
-- 4 certificates.
-- Certificate-session associations depend on paid sessions
-- within the selected certification periods.


-- =========================================================
-- 2. INTEGRITY VALIDATION
-- Every violations value must be 0.
-- =========================================================

SELECT 'cycles_not_six_sessions' AS test, COUNT(*) AS violations
FROM (
    SELECT c.cycle_id
    FROM cycle c
    LEFT JOIN session s ON s.cycle_id = c.cycle_id
    GROUP BY c.cycle_id
    HAVING COUNT(s.session_id) <> 6
) AS q

UNION ALL

SELECT 'sessions_without_lecturer', COUNT(*)
FROM session
WHERE lecturer_id IS NULL

UNION ALL

SELECT 'sessions_with_invalid_lecturer', COUNT(*)
FROM session s
LEFT JOIN lecturer l ON l.lecturer_id = s.lecturer_id
WHERE l.lecturer_id IS NULL

UNION ALL

SELECT 'sessions_not_120_minutes', COUNT(*)
FROM session
WHERE duration_minutes <> 120

UNION ALL

SELECT 'sessions_outside_cycle_dates', COUNT(*)
FROM session s
JOIN cycle c ON c.cycle_id = s.cycle_id
WHERE s.session_date NOT BETWEEN c.start_date AND c.end_date

UNION ALL

SELECT 'recording_dates_not_21_days', COUNT(*)
FROM recording r
JOIN session s ON s.session_id = r.session_id
WHERE r.available_from <> s.session_date
   OR r.available_until <> s.session_date + 21

UNION ALL

SELECT 'persons_without_subtype', COUNT(*)
FROM person p
LEFT JOIN patient pa ON pa.patient_id = p.person_id
LEFT JOIN homeopath h ON h.homeopath_id = p.person_id
LEFT JOIN participant pt ON pt.participant_id = p.person_id
LEFT JOIN lecturer l ON l.lecturer_id = p.person_id
WHERE pa.patient_id IS NULL
  AND h.homeopath_id IS NULL
  AND pt.participant_id IS NULL
  AND l.lecturer_id IS NULL

UNION ALL

SELECT 'consultations_without_assignment', COUNT(*)
FROM consultation c
LEFT JOIN patient_homeopath ph
    ON ph.patient_id = c.patient_id
   AND ph.homeopath_id = c.homeopath_id
WHERE ph.patient_id IS NULL

UNION ALL

SELECT 'patients_with_multiple_initials', COUNT(*)
FROM (
    SELECT patient_id
    FROM consultation
    WHERE type = 'Initial'
    GROUP BY patient_id
    HAVING COUNT(*) > 1
) AS q

UNION ALL

SELECT 'initial_consultations_missing_medication', COUNT(*)
FROM consultation c
LEFT JOIN prescription p
    ON p.consultation_id = c.consultation_id
LEFT JOIN medication m
    ON m.medication_id = p.medication_id
WHERE c.type = 'Initial'
  AND (
      p.prescription_id IS NULL
      OR p.decision <> 'MEDICATE'
      OR m.medication_id IS NULL
  )

UNION ALL

SELECT 'wait_prescriptions_with_medication', COUNT(*)
FROM prescription
WHERE decision = 'WAIT'
  AND medication_id IS NOT NULL

UNION ALL

SELECT 'medicate_prescriptions_without_medication', COUNT(*)
FROM prescription
WHERE decision = 'MEDICATE'
  AND medication_id IS NULL

UNION ALL

SELECT 'purchases_with_wrong_subtype', COUNT(*)
FROM purchase p
LEFT JOIN single_session_purchase sp
    ON sp.purchase_id = p.purchase_id
LEFT JOIN package_purchase pp
    ON pp.purchase_id = p.purchase_id
WHERE (sp.purchase_id IS NULL AND pp.purchase_id IS NULL)
   OR (sp.purchase_id IS NOT NULL AND pp.purchase_id IS NOT NULL)

UNION ALL

SELECT 'wrong_enrollment_type', COUNT(*)
FROM enrollment e
LEFT JOIN single_session_purchase sp
    ON sp.purchase_id = e.purchase_id
LEFT JOIN package_purchase pp
    ON pp.purchase_id = e.purchase_id
WHERE (e.session_id IS NULL AND e.cycle_id IS NULL)
   OR (e.session_id IS NOT NULL AND e.cycle_id IS NOT NULL)
   OR (e.session_id IS NOT NULL AND sp.purchase_id IS NULL)
   OR (e.cycle_id IS NOT NULL AND pp.purchase_id IS NULL)

UNION ALL

SELECT 'invalid_payments', COUNT(*)
FROM purchase p
JOIN payment py ON py.purchase_id = p.purchase_id
WHERE py.amount_paid <> p.total_amount
   OR py.payment_date < p.purchase_date

UNION ALL

SELECT 'payments_without_invoice', COUNT(*)
FROM payment py
LEFT JOIN invoice i ON i.payment_id = py.payment_id
WHERE i.invoice_id IS NULL

UNION ALL

SELECT 'invalid_invoice_status_dates', COUNT(*)
FROM invoice
WHERE (status = 'NOT_SENT' AND sent_date IS NOT NULL)
   OR (status = 'SENT' AND sent_date IS NULL)

UNION ALL

SELECT 'certificates_without_training_program', COUNT(*)
FROM certificate
WHERE training_program_id IS NULL

UNION ALL

SELECT 'certificates_without_participant', COUNT(*)
FROM certificate
WHERE participant_id IS NULL

UNION ALL

SELECT 'certificate_sessions_outside_program_or_period', COUNT(*)
FROM certificate_session cs
JOIN certificate cert
    ON cert.certificate_id = cs.certificate_id
JOIN session s
    ON s.session_id = cs.session_id
JOIN cycle c
    ON c.cycle_id = s.cycle_id
WHERE c.training_program_id <> cert.training_program_id
   OR s.session_date NOT BETWEEN cert.period_start
                             AND cert.period_end

UNION ALL

SELECT 'certificate_sessions_without_payment', COUNT(*)
FROM certificate_session cs
JOIN certificate cert
    ON cert.certificate_id = cs.certificate_id
WHERE NOT EXISTS (
    SELECT 1
    FROM purchase pur
    JOIN payment pay
        ON pay.purchase_id = pur.purchase_id
    JOIN enrollment e
        ON e.purchase_id = pur.purchase_id
    WHERE pur.participant_id = cert.participant_id
      AND (
          e.session_id = cs.session_id
          OR e.cycle_id = (
              SELECT s.cycle_id
              FROM session s
              WHERE s.session_id = cs.session_id
          )
      )
);


-- =========================================================
-- 3. VIEWS
-- Every view must return more than 0 rows.
-- =========================================================

SELECT 'v_paid_training_sessions' AS object_name,
       COUNT(*) AS rows_returned
FROM v_paid_training_sessions

UNION ALL

SELECT 'v_revenue_per_cycle', COUNT(*)
FROM v_revenue_per_cycle

UNION ALL

SELECT 'v_unsent_invoices', COUNT(*)
FROM v_unsent_invoices

UNION ALL

SELECT 'v_participants_per_session', COUNT(*)
FROM v_participants_per_session

UNION ALL

SELECT 'v_patient_load', COUNT(*)
FROM v_patient_load;


-- =========================================================
-- 4. FUNCTION
-- Expected result: 24 paid training hours.
-- =========================================================

SELECT fn_paid_training_hours(
    1,
    1,
    DATE '2024-01-01',
    DATE '2024-12-31'
) AS participant_1_program_1_paid_hours_2024;


-- =========================================================
-- 5. PROCEDURE
-- Creates a certificate temporarily, verifies its sessions,
-- then removes all changes with ROLLBACK.
-- =========================================================

BEGIN;

CALL sp_issue_certificate(
    4,
    1,
    DATE '2024-01-01',
    DATE '2024-12-31',
    CURRENT_DATE
);

-- Check the certificate created by the procedure.

SELECT
    certificate_id,
    participant_id,
    training_program_id,
    period_start,
    period_end,
    issue_date
FROM certificate
WHERE participant_id = 4
  AND training_program_id = 1
  AND period_start = DATE '2024-01-01'
  AND period_end = DATE '2024-12-31';


-- Check the sessions covered by the temporary certificate.

SELECT
    cert.certificate_id,
    cs.session_id,
    s.session_date,
    s.topic,
    s.duration_minutes
FROM certificate cert
JOIN certificate_session cs
    ON cs.certificate_id = cert.certificate_id
JOIN session s
    ON s.session_id = cs.session_id
WHERE cert.participant_id = 4
  AND cert.training_program_id = 1
  AND cert.period_start = DATE '2024-01-01'
  AND cert.period_end = DATE '2024-12-31'
ORDER BY s.session_date, s.session_id;


-- The certificate and its associations are temporary.

ROLLBACK;


-- =========================================================
-- 6. FINAL REGRESSION CHECK
-- Confirms that the procedure test left no extra data.
-- =========================================================

SELECT
    (SELECT COUNT(*) FROM person) AS persons,
    (SELECT COUNT(*) FROM purchase) AS purchases,
    (SELECT COUNT(*) FROM enrollment) AS enrollments,
    (SELECT COUNT(*) FROM payment) AS payments,
    (SELECT COUNT(*) FROM invoice) AS invoices,
    (SELECT COUNT(*) FROM certificate) AS certificates,
    (SELECT COUNT(*) FROM certificate_session) AS certificate_sessions,
    (SELECT COUNT(*)
     FROM person
     WHERE email = 'demo.student@salus.pt') AS demo_persons,
    (SELECT COUNT(*)
     FROM certificate
     WHERE participant_id = 4
       AND training_program_id = 1
       AND period_start = DATE '2024-01-01'
       AND period_end = DATE '2024-12-31') AS rolled_back_test_certificates,
    (SELECT COUNT(*)
     FROM certificate_session cs
     JOIN certificate cert
         ON cert.certificate_id = cs.certificate_id
     WHERE cert.participant_id = 4
       AND cert.training_program_id = 1
       AND cert.period_start = DATE '2024-01-01'
       AND cert.period_end = DATE '2024-12-31')
       AS rolled_back_test_sessions;

-- Expected final values:
-- persons = 1000
-- purchases = 1002
-- enrollments = 1002
-- payments = 968
-- invoices = 968
-- certificates = 4
-- certificate_sessions = unchanged from the original data population
-- demo_persons = 0
-- rolled_back_test_certificates = 0
-- rolled_back_test_sessions = 0
