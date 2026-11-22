
/*
 * Salus D3 - PostgreSQL Consistency Counts Export
 *
 * @author Ana Paula Tavares 68081
 * @author Laura Silva 68469
 * @author Xiaoji Wu 59800
 *
 * PostgreSQL exports relational counts and monetary totals in cents.
 * MongoDB checks the same figures after embedding. Monetary totals are
 * compared in cents to avoid floating-point rounding differences.
 */

-- Keep this list aligned with mongodb/04_consistency_checks.js.
SELECT json_build_object(
    'patient_documents', (SELECT COUNT(*) FROM patient),
    'consultations', (SELECT COUNT(*) FROM consultation),
    'symptoms', (SELECT COUNT(*) FROM symptom),
    'participant_documents', (SELECT COUNT(*) FROM participant),
    'purchases', (SELECT COUNT(*) FROM purchase),
    'paid_purchases', (SELECT COUNT(*) FROM payment),
    'certificates', (SELECT COUNT(*) FROM certificate),
    'certificate_sessions', (SELECT COUNT(*) FROM certificate_session),

    -- Count patient/homeopath relationships.
    'patient_homeopath_links',
        (SELECT COUNT(*) FROM patient_homeopath),

    -- Count WAIT prescriptions without medication.
    'wait_no_medication',
        (SELECT COUNT(*) FROM prescription
         WHERE decision = 'WAIT' AND medication_id IS NULL),

    -- Compare total purchase amounts in integer cents.
    'purchase_total_cents',
        (SELECT ROUND(COALESCE(SUM(total_amount), 0) * 100)::bigint
         FROM purchase),

    -- Compare total paid amounts in integer cents.
    'paid_total_cents',
        (SELECT ROUND(COALESCE(SUM(amount_paid), 0) * 100)::bigint
         FROM payment)
);
