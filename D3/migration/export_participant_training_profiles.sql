/*
 * Export one MongoDB participant_training_profiles document per
 * participant. Purchases, their accessible sessions, and certificates are
 * embedded because they form one participant-facing dashboard.
 */

COPY (
    -- The outer query creates exactly one dashboard document for each participant.
    SELECT jsonb_build_object(
        '_id', part.participant_id,
        'participant', jsonb_build_object(
            'participantId', part.participant_id,
            'name', person.name,
            'email', person.email,
            'studentNumber', part.student_number,
            'trainingLevel', part.training_level,
            'invoicePreference', part.invoice_preference
        ),
        -- Purchases are embedded because the participant portal displays them together.
        'purchases', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'purchaseId', pur.purchase_id,
                    'purchaseDate', pur.purchase_date,
                    'type', CASE
                        WHEN ssp.purchase_id IS NOT NULL THEN 'single_session'
                        ELSE 'package'
                    END,
                    'amount', pur.total_amount,
                    'paid', pay.payment_id IS NOT NULL,
                    'payment', CASE
                        WHEN pay.payment_id IS NULL THEN NULL
                        ELSE jsonb_build_object(
                            'paymentId', pay.payment_id,
                            'method', pay.payment_method,
                            'amountPaid', pay.amount_paid,
                            'paymentDate', pay.payment_date
                        )
                    END,
                    'enrollment', jsonb_build_object(
                        'enrollmentId', e.enrollment_id,
                        'registrationDate', e.registration_date,
                        'scope', CASE
                            WHEN e.session_id IS NOT NULL THEN 'session'
                            ELSE 'cycle'
                        END,
                        'sessionId', e.session_id,
                        'cycleId', e.cycle_id
                    ),
                    'program', jsonb_build_object(
                        'programId', tp.training_program_id,
                        'name', tp.name
                    ),
                    -- A package expands to all sessions of its cycle; a single purchase
                    -- expands to just its enrolled session.
                    'accessibleSessions', COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'sessionId', session_detail.session_id,
                                'sessionDate', session_detail.session_date,
                                'topic', session_detail.topic,
                                'durationMinutes', session_detail.duration_minutes,
                                'cycleId', session_detail.cycle_id,
                                'lecturer', jsonb_build_object(
                                    'lecturerId', lecturer.lecturer_id,
                                    'name', lecturer_person.name
                                ),
                                'recording', CASE
                                    WHEN recording.recording_id IS NULL THEN NULL
                                    ELSE jsonb_build_object(
                                        'recordingId', recording.recording_id,
                                        'availableFrom', recording.available_from,
                                        'availableUntil', recording.available_until,
                                        'url', recording.recording_url
                                    )
                                END
                            )
                            ORDER BY session_detail.session_date,
                                     session_detail.session_id
                        )
                        FROM session session_detail
                        JOIN lecturer
                            ON lecturer.lecturer_id = session_detail.lecturer_id
                        JOIN person lecturer_person
                            ON lecturer_person.person_id = lecturer.lecturer_id
                        LEFT JOIN recording
                            ON recording.session_id = session_detail.session_id
                        WHERE session_detail.session_id = e.session_id
                           OR session_detail.cycle_id = e.cycle_id
                    ), '[]'::jsonb)
                )
                ORDER BY pur.purchase_date, pur.purchase_id
            )
            FROM purchase pur
            JOIN enrollment e
                ON e.purchase_id = pur.purchase_id
            LEFT JOIN single_session_purchase ssp
                ON ssp.purchase_id = pur.purchase_id
            LEFT JOIN payment pay
                ON pay.purchase_id = pur.purchase_id
            LEFT JOIN session enrolled_session
                ON enrolled_session.session_id = e.session_id
            LEFT JOIN cycle enrolled_cycle
                ON enrolled_cycle.cycle_id = COALESCE(
                    e.cycle_id,
                    enrolled_session.cycle_id
                )
            JOIN training_program tp
                ON tp.training_program_id = enrolled_cycle.training_program_id
            WHERE pur.participant_id = part.participant_id
        ), '[]'::jsonb),
        -- Certificate sessions are embedded to show how the certificate was earned.
        'certificates', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'certificateId', cert.certificate_id,
                    'periodStart', cert.period_start,
                    'periodEnd', cert.period_end,
                    'issueDate', cert.issue_date,
                    'program', jsonb_build_object(
                        'programId', cert_program.training_program_id,
                        'name', cert_program.name
                    ),
                    'coveredSessions', COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'sessionId', cert_session.session_id,
                                'sessionDate', cert_session.session_date,
                                'topic', cert_session.topic,
                                'cycleId', cert_session.cycle_id
                            )
                            ORDER BY cert_session.session_date,
                                     cert_session.session_id
                        )
                        FROM certificate_session cs
                        JOIN session cert_session
                            ON cert_session.session_id = cs.session_id
                        WHERE cs.certificate_id = cert.certificate_id
                    ), '[]'::jsonb)
                )
                ORDER BY cert.issue_date, cert.certificate_id
            )
            FROM certificate cert
            JOIN training_program cert_program
                ON cert_program.training_program_id = cert.training_program_id
            WHERE cert.participant_id = part.participant_id
        ), '[]'::jsonb),
        'migration', jsonb_build_object(
            'source', 'PostgreSQL Salus D2',
            'component', 'participant_training_profiles'
        )
    )::text
    FROM participant part
    JOIN person
        ON person.person_id = part.participant_id
    ORDER BY part.participant_id
) TO STDOUT;
