
/*
 * Stored Function and Procedure for the Salus project.
 *
 * @author Ana Paula Tavares 68081
 * @author Laura Silva 68469
 * @author Xiaoji Wu 59800
 */


-- Function 1:
-- Calculates certificate hours from PAID sessions for one participant,
-- one training program and one selected period.

CREATE OR REPLACE FUNCTION fn_paid_training_hours(
    p_participant_id INT,
    p_training_program_id INT,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_hours INT;
BEGIN
    IF p_period_start > p_period_end THEN
        RAISE EXCEPTION 'Period start date cannot be after period end date.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM training_program
        WHERE training_program_id = p_training_program_id
    ) THEN
        RAISE EXCEPTION 'Training program % does not exist.',
            p_training_program_id;
    END IF;

    SELECT COUNT(DISTINCT session_id) * 2
    INTO v_hours
    FROM (
        -- Paid individual-session purchases for this training program
        SELECT s.session_id
        FROM purchase pur
        JOIN payment pay
            ON pay.purchase_id = pur.purchase_id
        JOIN enrollment e
            ON e.purchase_id = pur.purchase_id
        JOIN session s
            ON s.session_id = e.session_id
        JOIN cycle c
            ON c.cycle_id = s.cycle_id
        WHERE pur.participant_id = p_participant_id
          AND c.training_program_id = p_training_program_id
          AND s.session_date BETWEEN p_period_start AND p_period_end

        UNION

        -- Paid package purchases: all sessions in the enrolled cycle
        -- that belong to this training program
        SELECT s.session_id
        FROM purchase pur
        JOIN payment pay
            ON pay.purchase_id = pur.purchase_id
        JOIN enrollment e
            ON e.purchase_id = pur.purchase_id
        JOIN session s
            ON s.cycle_id = e.cycle_id
        JOIN cycle c
            ON c.cycle_id = s.cycle_id
        WHERE pur.participant_id = p_participant_id
          AND c.training_program_id = p_training_program_id
          AND s.session_date BETWEEN p_period_start AND p_period_end
    ) AS paid_sessions;

    RETURN COALESCE(v_hours, 0);
END;
$$;


-- Procedure 2:
-- Issues one certificate for a participant, training program and period.
-- Associates the certificate with its corresponding paid sessions.

CREATE OR REPLACE PROCEDURE sp_issue_certificate(
    IN p_participant_id INT,
    IN p_training_program_id INT,
    IN p_period_start DATE,
    IN p_period_end DATE,
    IN p_issue_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_hours INT;
    v_certificate_id INT;
BEGIN
    IF p_period_start > p_period_end THEN
        RAISE EXCEPTION 'Period start date cannot be after period end date.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM participant
        WHERE participant_id = p_participant_id
    ) THEN
        RAISE EXCEPTION 'Participant % does not exist.', p_participant_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM training_program
        WHERE training_program_id = p_training_program_id
    ) THEN
        RAISE EXCEPTION 'Training program % does not exist.',
            p_training_program_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM certificate
        WHERE participant_id = p_participant_id
          AND training_program_id = p_training_program_id
          AND period_start = p_period_start
          AND period_end = p_period_end
    ) THEN
        RAISE EXCEPTION
            'This participant already has a certificate for this training program and period.';
    END IF;

    v_hours := fn_paid_training_hours(
        p_participant_id,
        p_training_program_id,
        p_period_start,
        p_period_end
    );

    IF v_hours = 0 THEN
        RAISE EXCEPTION
            'A certificate cannot be issued because the participant has no paid training hours for this training program and period.';
    END IF;

    INSERT INTO certificate (
        period_start,
        period_end,
        issue_date,
        participant_id,
        training_program_id
    )
    VALUES (
        p_period_start,
        p_period_end,
        p_issue_date,
        p_participant_id,
        p_training_program_id
    )
    RETURNING certificate_id INTO v_certificate_id;

    -- Associate paid sessions with the newly issued certificate.
    -- UNION avoids duplicate sessions purchased through different options.

    INSERT INTO certificate_session (
        certificate_id,
        session_id
    )
    SELECT v_certificate_id,
           paid_sessions.session_id
    FROM (
        -- Paid individual-session purchases
        SELECT s.session_id
        FROM purchase pur
        JOIN payment pay
            ON pay.purchase_id = pur.purchase_id
        JOIN enrollment e
            ON e.purchase_id = pur.purchase_id
        JOIN session s
            ON s.session_id = e.session_id
        JOIN cycle c
            ON c.cycle_id = s.cycle_id
        WHERE pur.participant_id = p_participant_id
          AND c.training_program_id = p_training_program_id
          AND s.session_date BETWEEN p_period_start AND p_period_end

        UNION

        -- Paid package purchases
        SELECT s.session_id
        FROM purchase pur
        JOIN payment pay
            ON pay.purchase_id = pur.purchase_id
        JOIN enrollment e
            ON e.purchase_id = pur.purchase_id
        JOIN session s
            ON s.cycle_id = e.cycle_id
        JOIN cycle c
            ON c.cycle_id = s.cycle_id
        WHERE pur.participant_id = p_participant_id
          AND c.training_program_id = p_training_program_id
          AND s.session_date BETWEEN p_period_start AND p_period_end
    ) AS paid_sessions;

    RAISE NOTICE
        'Certificate issued for participant %, training program %, with % paid training hours.',
        p_participant_id,
        p_training_program_id,
        v_hours;
END;
$$;
