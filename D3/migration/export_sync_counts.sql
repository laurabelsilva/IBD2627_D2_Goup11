/*
 * Counts exported from PostgreSQL after migration. The MongoDB consistency
 * script compares these values with equivalent document and embedded-array
 * counts. The output is one JSON object.
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
    'certificate_sessions', (SELECT COUNT(*) FROM certificate_session)
);
