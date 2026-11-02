
/*
 * Salus Database - Negative Test Script
 *
 * Each test attempts to violate an integrity constraint
 * or a business rule.
 *
 * Expected errors are recorded as PASS.
 * Unexpected outcomes are recorded as FAIL.
 *
 * Each test is isolated and its changes are rolled back.
 *
 * Run after:
 * 1. schema.sql
 * 2. data.sql
 * 3. procedures.sql
 * 4. queries.sql
 *
 * @author Ana Paula Tavares 68081
 * @author Laura Silva 68469
 * @author Xiaoji Wu 59800
 */


-- =========================================================
-- NEGATIVE TEST RESULTS
-- =========================================================

CREATE TEMP TABLE IF NOT EXISTS negative_test_results (
    test_number INT PRIMARY KEY,
    test_name TEXT NOT NULL,
    result VARCHAR(10) NOT NULL,
    error_message TEXT
);

TRUNCATE TABLE negative_test_results;


-- =========================================================
-- NEGATIVE TEST EXECUTION
-- Each statement runs inside a protected subtransaction.
-- =========================================================

DO $$
DECLARE
    v_test RECORD;
    v_error TEXT;
    v_state TEXT;
    v_result VARCHAR(10);

BEGIN
    FOR v_test IN
        SELECT *
        FROM (
            VALUES

            -- 1. A cycle cannot have more than six sessions.
            (
                1,
                'Maximum six sessions per cycle',
                $test$
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
                    VALUES (
                        DATE '2024-03-01',
                        'Invalid seventh session',
                        'Trigger test',
                        120,
                        'Trigger test',
                        'https://zoom.us/j/test',
                        1,
                        501
                    )
                $test$,
                'cannot have more than 6 sessions'
            ),

            -- 2. A session must be conducted by an existing lecturer.
            (
                2,
                'Session with nonexistent lecturer',
                $test$
                    UPDATE session
                    SET lecturer_id = 999999
                    WHERE session_id = 1
                $test$,
                'foreign key constraint'
            ),

            -- 3. A homeopath must be assigned to the patient.
            (
                3,
                'Consultation without patient-homeopath assignment',
                $test$
                    INSERT INTO consultation (
                        consultation_date,
                        type,
                        notes,
                        patient_id,
                        homeopath_id
                    )
                    VALUES (
                        CURRENT_DATE,
                        'Follow-up',
                        'Invalid assignment test',
                        551,
                        502
                    )
                $test$,
                'homeopath must be assigned to the patient'
            ),

            -- 4. A patient can have only one Initial consultation.
            (
                4,
                'Duplicate Initial consultation',
                $test$
                    INSERT INTO consultation (
                        consultation_date,
                        type,
                        notes,
                        patient_id,
                        homeopath_id
                    )
                    VALUES (
                        CURRENT_DATE,
                        'Initial',
                        'Duplicate Initial consultation test',
                        551,
                        501
                    )
                $test$,
                'only one Initial consultation'
            ),

            -- 5. An Initial consultation must result in MEDICATE.
            (
                5,
                'Initial consultation with WAIT decision',
                $test$
                    UPDATE prescription
                    SET decision = 'WAIT',
                        medication_id = NULL
                    WHERE consultation_id = (
                        SELECT consultation_id
                        FROM consultation
                        WHERE type = 'Initial'
                        ORDER BY consultation_id
                        LIMIT 1
                    )
                $test$,
                'Initial consultation must result in MEDICATE'
            ),

            -- 6. A WAIT prescription cannot contain medication.
            (
                6,
                'WAIT prescription with medication',
                $test$
                    UPDATE prescription
                    SET medication_id = (
                        SELECT medication_id
                        FROM medication
                        ORDER BY medication_id
                        LIMIT 1
                    )
                    WHERE prescription_id = (
                        SELECT prescription_id
                        FROM prescription
                        WHERE decision = 'WAIT'
                        ORDER BY prescription_id
                        LIMIT 1
                    )
                $test$,
                'chk_prescription_medication'
            ),

            -- 7. A package purchase cannot enroll in one session.
            (
                7,
                'Package purchase enrolled in one session',
                $test$
                    UPDATE enrollment
                    SET session_id = 1,
                        cycle_id = NULL
                    WHERE enrollment_id = (
                        SELECT e.enrollment_id
                        FROM enrollment e
                        JOIN package_purchase pp
                            ON pp.purchase_id = e.purchase_id
                        ORDER BY e.enrollment_id
                        LIMIT 1
                    )
                $test$,
                'session enrollment requires one single-session purchase'
            ),

            -- 8. Payment amount must equal the purchase total.
            (
                8,
                'Incorrect payment amount',
                $test$
                    UPDATE payment
                    SET amount_paid = 1.00
                    WHERE payment_id = (
                        SELECT payment_id
                        FROM payment
                        ORDER BY payment_id
                        LIMIT 1
                    )
                $test$,
                'Payment amount must equal the purchase total'
            ),

            -- 9. Payment cannot predate the purchase.
            (
                9,
                'Payment before purchase date',
                $test$
                    UPDATE payment
                    SET payment_date = (
                        SELECT p.purchase_date - 1
                        FROM purchase p
                        WHERE p.purchase_id = payment.purchase_id
                    )
                    WHERE payment_id = (
                        SELECT payment_id
                        FROM payment
                        ORDER BY payment_id
                        LIMIT 1
                    )
                $test$,
                'Payment date cannot be before purchase date'
            ),

            -- 10. A SENT invoice must have a sent_date.
            (
                10,
                'SENT invoice without sent date',
                $test$
                    UPDATE invoice
                    SET status = 'SENT',
                        sent_date = NULL
                    WHERE invoice_id = 1
                $test$,
                'chk_invoice_status_sent_date'
            ),

            -- 11. A single session price must be 25.00.
            (
                11,
                'Invalid single-session price',
                $test$
                    UPDATE single_session_purchase
                    SET session_price = 20.00
                    WHERE purchase_id = (
                        SELECT purchase_id
                        FROM single_session_purchase
                        ORDER BY purchase_id
                        LIMIT 1
                    )
                $test$,
                'chk_single_session_price'
            ),

            -- 12. One purchase can have only one enrollment.
            (
                12,
                'Duplicate enrollment for one purchase',
                $test$
                    INSERT INTO enrollment (
                        registration_date,
                        purchase_id,
                        session_id
                    )
                    SELECT registration_date,
                           purchase_id,
                           session_id
                    FROM enrollment
                    WHERE session_id IS NOT NULL
                    ORDER BY enrollment_id
                    LIMIT 1
                $test$,
                'uq_enrollment_purchase'
            ),

            -- 13. A participant must first exist as a person.
            (
                13,
                'Participant without corresponding person',
                $test$
                    INSERT INTO participant (
                        participant_id,
                        student_number,
                        training_level
                    )
                    VALUES (
                        999999,
                        'INVALID999',
                        'Beginner'
                    )
                $test$,
                'foreign key constraint'
            ),

            -- 14. A certificate must reference an existing program.
            (
                14,
                'Certificate with nonexistent training program',
                $test$
                    INSERT INTO certificate (
                        period_start,
                        period_end,
                        issue_date,
                        participant_id,
                        training_program_id
                    )
                    VALUES (
                        DATE '2099-01-01',
                        DATE '2099-12-31',
                        CURRENT_DATE,
                        4,
                        999999
                    )
                $test$,
                'foreign key constraint'
            ),

            -- 15. A certificate cannot be issued with zero paid hours.
            (
                15,
                'Certificate without paid training hours',
                $test$
                    CALL sp_issue_certificate(
                        4,
                        1,
                        DATE '2030-01-01',
                        DATE '2030-12-31',
                        CURRENT_DATE
                    )
                $test$,
                'no paid training hours'
            )

        ) AS tests (
            test_number,
            test_name,
            sql_statement,
            expected_error
        )
        ORDER BY test_number

    LOOP
        v_error := NULL;
        v_state := NULL;
        v_result := 'FAIL';

        BEGIN
            EXECUTE v_test.sql_statement;

            -- If the statement succeeds unexpectedly, raise an error
            -- to reverse any changes made inside this test.
            RAISE EXCEPTION USING
                ERRCODE = 'ZX001',
                MESSAGE = 'Statement unexpectedly succeeded';

        EXCEPTION
            WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS
                    v_error = MESSAGE_TEXT,
                    v_state = RETURNED_SQLSTATE;

                IF v_state <> 'ZX001'
                   AND POSITION(
                       LOWER(v_test.expected_error)
                       IN LOWER(v_error)
                   ) > 0
                THEN
                    v_result := 'PASS';
                ELSE
                    v_result := 'FAIL';
                END IF;
        END;

        INSERT INTO negative_test_results (
            test_number,
            test_name,
            result,
            error_message
        )
        VALUES (
            v_test.test_number,
            v_test.test_name,
            v_result,
            v_error
        );

    END LOOP;
END;
$$;


-- =========================================================
-- FINAL NEGATIVE TEST REPORT
-- All tests should return PASS.
-- =========================================================

SELECT
    test_number,
    test_name,
    result,
    error_message
FROM negative_test_results
ORDER BY test_number;


-- =========================================================
-- SUMMARY
-- Expected: 15 PASS, 0 FAIL.
-- =========================================================

SELECT
    COUNT(*) AS total_tests,
    COUNT(*) FILTER (WHERE result = 'PASS') AS passed_tests,
    COUNT(*) FILTER (WHERE result = 'FAIL') AS failed_tests
FROM negative_test_results;
