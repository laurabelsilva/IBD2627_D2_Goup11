/*
 *
 * JSON Lines is used because mongoimport reads one JSON document per line.
 * The document embeds information owned by one patient: assigned homeopaths,
 * consultations, symptoms, and the optional prescription decision.
 */

COPY (
    -- The outer query creates exactly one JSON document for each patient.
    SELECT jsonb_build_object(
        '_id', pat.patient_id,
        'patient', jsonb_build_object(
            'patientId', pat.patient_id,
            'name', person.name,
            'email', person.email,
            'phone', person.phone,
            'country', person.country
        ),
        -- A patient may have several assigned homeopaths, so they become an array.
        'assignedHomeopaths', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'homeopathId', h.homeopath_id,
                    'name', hp.name,
                    'email', hp.email
                )
                ORDER BY h.homeopath_id
            )
            FROM patient_homeopath ph
            JOIN homeopath h
                ON h.homeopath_id = ph.homeopath_id
            JOIN person hp
                ON hp.person_id = h.homeopath_id
            WHERE ph.patient_id = pat.patient_id
        ), '[]'::jsonb),
        -- A consultation and its symptoms are read as part of one patient history.
        'consultations', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'consultationId', c.consultation_id,
                    'date', c.consultation_date,
                    'type', c.type,
                    'notes', c.notes,
                    'homeopath', jsonb_build_object(
                        'homeopathId', c.homeopath_id,
                        'name', consultation_hp.name
                    ),
                    'symptoms', COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'symptomId', s.symptom_id,
                                'name', s.name,
                                'description', s.description
                            )
                            ORDER BY s.symptom_id
                        )
                        FROM symptom s
                        WHERE s.consultation_id = c.consultation_id
                    ), '[]'::jsonb),
                    -- WAIT has no medication; the left join keeps medication optional.
                    'prescription', (
                        SELECT jsonb_build_object(
                            'prescriptionId', pr.prescription_id,
                            'decision', pr.decision,
                            'dosage', pr.dosage,
                            'instructions', pr.instructions,
                            'medication', CASE
                                WHEN m.medication_id IS NULL THEN NULL
                                ELSE jsonb_build_object(
                                    'medicationId', m.medication_id,
                                    'name', m.name,
                                    'potency', m.potency,
                                    'form', m.form
                                )
                            END
                        )
                        FROM prescription pr
                        LEFT JOIN medication m
                            ON m.medication_id = pr.medication_id
                        WHERE pr.consultation_id = c.consultation_id
                    )
                )
                ORDER BY c.consultation_date, c.consultation_id
            )
            FROM consultation c
            JOIN person consultation_hp
                ON consultation_hp.person_id = c.homeopath_id
            WHERE c.patient_id = pat.patient_id
        ), '[]'::jsonb),
        -- This small block makes the origin of every imported document explicit.
        'migration', jsonb_build_object(
            'source', 'PostgreSQL Salus D2',
            'component', 'patient_case_files'
        )
    )::text
    FROM patient pat
    JOIN person
        ON person.person_id = pat.patient_id
    ORDER BY pat.patient_id
) TO STDOUT;
