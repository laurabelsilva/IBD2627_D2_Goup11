
/*
 * Database schema definition for the Salus project.
 *
 * @author Ana Paula Tavares 68081
 * @author Laura Silva 68469
 * @author Xiaoji Wu 59800
 */

 -- =========================================================
-- D1 TO D2 CHANGES WITH DIRECT IMPLEMENTATION IMPACT
-- =========================================================
--
-- 1. LECTURER and SESSION
-- A LECTURER specialization and SESSION.lecturer_id were added
-- to identify the person responsible for conducting each session.
--
-- 2. CERTIFICATE, TRAINING_PROGRAM and SESSION
-- CERTIFICATE.training_program_id and the CERTIFICATE_SESSION
-- associative table were added. This allows each certificate to
-- be linked to one training programme and to the paid sessions
-- that contribute to its credited training hours.
--
-- 3. PRESCRIPTION and MEDICATION
-- The prescription-medication rule was reinforced so that a WAIT
-- prescription has no medication, while a MEDICATE prescription
-- references exactly one medication.
--
-- 4. Integrity improvements
-- Additional PostgreSQL constraints and triggers enforce the
-- business rules defined in D1, including exactly six sessions
-- per cycle, valid patient-homeopath assignments, purchase
-- specialization, and certificate eligibility.
-- ========================================================= 

DROP TABLE IF EXISTS certificate_session, certificate, recording, session, cycle, training_program,
invoice, payment, enrollment, package_purchase, single_session_purchase,
purchase, medication, prescription, symptom, consultation, patient_homeopath,
lecturer, patient, homeopath, participant, person CASCADE;

-- 1. Person and Specialization

CREATE TABLE person (
    person_id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(50),
    country VARCHAR(50)
);

-- Subtypes of PERSON
-- Uma pessoa pode ser, ao mesmo tempo, paciente, homeopata e participante.
CREATE TABLE patient (
    patient_id INT PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE
);

CREATE TABLE homeopath (
    homeopath_id INT PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE
);

CREATE TABLE participant (
    participant_id INT PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE,
    student_number VARCHAR(20) UNIQUE NULL,
    training_level VARCHAR(20) CHECK (training_level IN ('Beginner', 'Advanced')),
    invoice_preference BOOLEAN DEFAULT TRUE
);

CREATE TABLE lecturer (
    lecturer_id INT PRIMARY KEY
        REFERENCES person(person_id)
        ON DELETE CASCADE
);

-- M:N Relationship between PATIENT and HOMEOPATH
CREATE TABLE patient_homeopath (
    patient_id INT REFERENCES patient(patient_id) ON DELETE CASCADE,
    homeopath_id INT REFERENCES homeopath(homeopath_id) ON DELETE CASCADE,
    PRIMARY KEY (patient_id, homeopath_id)
);

-- 2. Clinical Area

CREATE TABLE consultation (
    consultation_id SERIAL PRIMARY KEY,
    consultation_date DATE NOT NULL,
    type VARCHAR(20) CHECK (type IN ('Initial', 'Follow-up')),
    notes TEXT,
    patient_id INT REFERENCES patient(patient_id),
    homeopath_id INT REFERENCES homeopath(homeopath_id)
);

CREATE TABLE symptom (
    symptom_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    consultation_id INT REFERENCES consultation(consultation_id) ON DELETE CASCADE
);

CREATE TABLE medication (
    medication_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    potency VARCHAR(50),
    form VARCHAR(50)
);

CREATE TABLE prescription (
    prescription_id SERIAL PRIMARY KEY,
    decision VARCHAR(20) NOT NULL
        CHECK (decision IN ('WAIT', 'MEDICATE')),
    dosage VARCHAR(100),
    instructions TEXT,
    consultation_id INT UNIQUE NOT NULL
        REFERENCES consultation(consultation_id)
        ON DELETE CASCADE,
    medication_id INT
        REFERENCES medication(medication_id),

    CONSTRAINT chk_prescription_medication
        CHECK (
            (decision = 'WAIT' AND medication_id IS NULL)
            OR
            (decision = 'MEDICATE' AND medication_id IS NOT NULL)
        )
);

-- 3. Training Area

CREATE TABLE training_program (
    training_program_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE cycle (
    cycle_id SERIAL PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    training_program_id INT REFERENCES training_program(training_program_id)
);

CREATE TABLE session (
    session_id SERIAL PRIMARY KEY,
    session_date DATE NOT NULL,
    topic VARCHAR(200),
    case_description TEXT,
    duration_minutes INT DEFAULT 120 CHECK (duration_minutes = 120),
    agenda VARCHAR(100),
    zoom_link VARCHAR(255),
    cycle_id INT REFERENCES cycle(cycle_id) ON DELETE CASCADE,
    lecturer_id INT REFERENCES lecturer(lecturer_id)
);

CREATE TABLE recording (
    recording_id SERIAL PRIMARY KEY,
    available_from DATE NOT NULL,
    available_until DATE NOT NULL,
    recording_url VARCHAR(255) NOT NULL,
    -- 1:1 Relationship with Session
    session_id INT UNIQUE REFERENCES session(session_id) ON DELETE CASCADE
);

-- 4. Financial Area (Purchases, Payments, Invoices)

CREATE TABLE purchase (
    purchase_id SERIAL PRIMARY KEY,
    purchase_date DATE NOT NULL,
    total_amount DECIMAL(8,2) NOT NULL,
    participant_id INT REFERENCES participant(participant_id)
);

-- Purchase Subtypes
CREATE TABLE single_session_purchase (
    purchase_id INT PRIMARY KEY REFERENCES purchase(purchase_id) ON DELETE CASCADE,
    session_price DECIMAL(8,2) DEFAULT 25.00
);

CREATE TABLE package_purchase (
    purchase_id INT PRIMARY KEY REFERENCES purchase(purchase_id) ON DELETE CASCADE,
    package_price DECIMAL(8,2) DEFAULT 120.00
);

CREATE TABLE enrollment (
    enrollment_id SERIAL PRIMARY KEY,
    registration_date DATE NOT NULL,
    purchase_id INT REFERENCES purchase(purchase_id) ON DELETE CASCADE,
    session_id INT REFERENCES session(session_id), -- For single session
    cycle_id INT REFERENCES cycle(cycle_id),       -- For package
    -- XOR constraint: Enrollment must be either for a single session OR a cycle
    -- Se tiver um session_id, significa que a pessoa comprou uma aula individual.
    -- Se tiver um cycle_id, significa que a pessoa comprou um pacote completo do ciclo.
    CONSTRAINT chk_enrollment_scope CHECK (
        (session_id IS NOT NULL AND cycle_id IS NULL) OR
        (session_id IS NULL AND cycle_id IS NOT NULL)
    )
);

CREATE TABLE payment (
    payment_id SERIAL PRIMARY KEY,
    payment_method VARCHAR(50) NOT NULL,
    amount_paid DECIMAL(8,2) NOT NULL,
    payment_date DATE NOT NULL,
    purchase_id INT UNIQUE REFERENCES purchase(purchase_id) ON DELETE CASCADE
);

CREATE TABLE invoice (
    invoice_id SERIAL PRIMARY KEY,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    issue_date DATE NOT NULL,
    sent_date DATE NULL,
    status VARCHAR(20) CHECK (status IN ('NOT_SENT', 'SENT')),
    payment_id INT UNIQUE REFERENCES payment(payment_id) ON DELETE CASCADE
);

CREATE TABLE certificate (
    certificate_id SERIAL PRIMARY KEY,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    issue_date DATE NOT NULL,
    participant_id INT REFERENCES participant(participant_id),
    training_program_id INT REFERENCES training_program(training_program_id)
);

CREATE TABLE certificate_session (
    certificate_id INT
        REFERENCES certificate(certificate_id)
        ON DELETE CASCADE,
    session_id INT
        REFERENCES session(session_id)
        ON DELETE CASCADE,
    PRIMARY KEY (certificate_id, session_id)
);

-- Additional integrity constraints

-- Clinical area: these relationships and values are mandatory.
ALTER TABLE consultation
    ALTER COLUMN type SET NOT NULL,
    ALTER COLUMN patient_id SET NOT NULL,
    ALTER COLUMN homeopath_id SET NOT NULL;

ALTER TABLE symptom
    ALTER COLUMN consultation_id SET NOT NULL;

ALTER TABLE prescription
    ALTER COLUMN decision SET NOT NULL,
    ALTER COLUMN consultation_id SET NOT NULL;

-- Training area: every session must contain the required D1 information.
ALTER TABLE cycle
    ALTER COLUMN training_program_id SET NOT NULL;

ALTER TABLE session
    ALTER COLUMN topic SET NOT NULL,
    ALTER COLUMN case_description SET NOT NULL,
    ALTER COLUMN duration_minutes SET NOT NULL,
    ALTER COLUMN agenda SET NOT NULL,
    ALTER COLUMN zoom_link SET NOT NULL,
    ALTER COLUMN cycle_id SET NOT NULL,
    ALTER COLUMN lecturer_id SET NOT NULL;

ALTER TABLE recording
    ALTER COLUMN session_id SET NOT NULL;

-- Financial area: mandatory relationships and positive monetary values.
ALTER TABLE purchase
    ALTER COLUMN participant_id SET NOT NULL;

ALTER TABLE single_session_purchase
    ALTER COLUMN session_price SET NOT NULL;

ALTER TABLE package_purchase
    ALTER COLUMN package_price SET NOT NULL;

ALTER TABLE enrollment
    ALTER COLUMN purchase_id SET NOT NULL;

ALTER TABLE payment
    ALTER COLUMN purchase_id SET NOT NULL;

ALTER TABLE invoice
    ALTER COLUMN payment_id SET NOT NULL,
    ALTER COLUMN status SET NOT NULL,
    ALTER COLUMN status SET DEFAULT 'NOT_SENT';

ALTER TABLE certificate
    ALTER COLUMN participant_id SET NOT NULL,
    ALTER COLUMN training_program_id SET NOT NULL;

-- Date and amount validation.
ALTER TABLE cycle
    ADD CONSTRAINT chk_cycle_dates
    CHECK (start_date <= end_date);

ALTER TABLE recording
    ADD CONSTRAINT chk_recording_dates
    CHECK (available_from <= available_until);

ALTER TABLE purchase
    ADD CONSTRAINT chk_purchase_positive_amount
    CHECK (total_amount > 0);

ALTER TABLE payment
    ADD CONSTRAINT chk_payment_positive_amount
    CHECK (amount_paid > 0);

ALTER TABLE single_session_purchase
    ADD CONSTRAINT chk_single_session_price
    CHECK (session_price = 25.00);

ALTER TABLE package_purchase
    ADD CONSTRAINT chk_package_price
    CHECK (package_price = 120.00);

ALTER TABLE certificate
    ADD CONSTRAINT chk_certificate_dates
    CHECK (period_start <= period_end);

-- One purchase can cover only one enrollment, as shown in the ER diagram.
ALTER TABLE enrollment
    ADD CONSTRAINT uq_enrollment_purchase
    UNIQUE (purchase_id);

-- A participant receives at most one certificate for the same
-- training program and certification period.
ALTER TABLE certificate
    ADD CONSTRAINT uq_certificate_participant_program_period
    UNIQUE (
        participant_id,
        training_program_id,
        period_start,
        period_end
    );

-- An invoice is either unsent with no date, or sent with a sent date.
ALTER TABLE invoice
    ADD CONSTRAINT chk_invoice_status_sent_date
    CHECK (
        (status = 'NOT_SENT' AND sent_date IS NULL)
        OR
        (status = 'SENT' AND sent_date IS NOT NULL)
    );

-- Each session must take place within the dates of its cycle.
CREATE OR REPLACE FUNCTION fn_check_session_cycle_dates()
RETURNS TRIGGER AS $$
DECLARE
    v_start DATE;
    v_end DATE;
BEGIN
    SELECT start_date, end_date INTO v_start, v_end
    FROM cycle WHERE cycle_id = NEW.cycle_id;

    IF NEW.session_date NOT BETWEEN v_start AND v_end THEN
        RAISE EXCEPTION 'Session date must be within cycle dates.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_session_cycle_dates
BEFORE INSERT OR UPDATE OF session_date, cycle_id ON session
FOR EACH ROW EXECUTE FUNCTION fn_check_session_cycle_dates();

CREATE OR REPLACE FUNCTION fn_check_cycle_session_dates()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM session s
        WHERE s.cycle_id = NEW.cycle_id
          AND s.session_date NOT BETWEEN NEW.start_date AND NEW.end_date
    ) THEN
        RAISE EXCEPTION 'Cycle dates must include all its sessions.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cycle_session_dates
BEFORE UPDATE OF start_date, end_date ON cycle
FOR EACH ROW EXECUTE FUNCTION fn_check_cycle_session_dates();

-- 5. Triggers for business rules

-- Trigger 1:
-- A cycle cannot have more than six sessions.
CREATE OR REPLACE FUNCTION fn_check_max_sessions()
RETURNS TRIGGER AS $$
BEGIN
    -- Updating a session without moving it to another cycle is allowed.
    IF TG_OP = 'UPDATE' AND NEW.cycle_id = OLD.cycle_id THEN
        RETURN NEW;
    END IF;

    IF (
        SELECT COUNT(*)
        FROM session
        WHERE cycle_id = NEW.cycle_id
    ) >= 6 THEN
        RAISE EXCEPTION 'A cycle cannot have more than 6 sessions.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_max_sessions
BEFORE INSERT OR UPDATE OF cycle_id ON session
FOR EACH ROW
EXECUTE FUNCTION fn_check_max_sessions();

-- A cycle must contain exactly six sessions at the end of the transaction.

CREATE OR REPLACE FUNCTION fn_enforce_exactly_six_sessions()
RETURNS TRIGGER AS $$
DECLARE
    v_count INT;
    v_cycle_id INT;
BEGIN
    -- Check the old cycle when a session is deleted or moved.
    IF TG_OP IN ('DELETE', 'UPDATE') THEN
        v_cycle_id := OLD.cycle_id;

        IF EXISTS (
            SELECT 1
            FROM cycle
            WHERE cycle_id = v_cycle_id
        ) THEN
            SELECT COUNT(*)
            INTO v_count
            FROM session
            WHERE cycle_id = v_cycle_id;

            IF v_count <> 6 THEN
                RAISE EXCEPTION
                    'Cycle % must have exactly 6 sessions. Current number: %.',
                    v_cycle_id, v_count;
            END IF;
        END IF;
    END IF;

    -- Check the new cycle when a session is inserted or moved.
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_cycle_id := NEW.cycle_id;

        SELECT COUNT(*)
        INTO v_count
        FROM session
        WHERE cycle_id = v_cycle_id;

        IF v_count <> 6 THEN
            RAISE EXCEPTION
                'Cycle % must have exactly 6 sessions. Current number: %.',
                v_cycle_id, v_count;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_exactly_six_sessions
AFTER INSERT OR UPDATE OR DELETE ON session
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_enforce_exactly_six_sessions();

CREATE OR REPLACE FUNCTION fn_check_new_cycle_exactly_six()
RETURNS TRIGGER AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM session
    WHERE cycle_id = NEW.cycle_id;

    IF v_count <> 6 THEN
        RAISE EXCEPTION
            'Cycle % must have exactly 6 sessions. Current number: %.',
            NEW.cycle_id, v_count;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_new_cycle_exactly_six
AFTER INSERT ON cycle
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_new_cycle_exactly_six();

-- PERSON specialization must be total:
-- every person must belong to at least one subtype.

CREATE OR REPLACE FUNCTION fn_check_person_total()
RETURNS TRIGGER AS $$
DECLARE
    v_person_id INT;
BEGIN
    IF TG_TABLE_NAME = 'person' THEN
        v_person_id := NEW.person_id;
    ELSE
        v_person_id := OLD.person_id;
    END IF;

    -- Deleting PERSON cascades to its subtypes; do not block that deletion.
    IF NOT EXISTS (SELECT 1 FROM person WHERE person_id = v_person_id) THEN
        RETURN NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM patient
        WHERE patient_id = v_person_id
    )
    AND NOT EXISTS (
        SELECT 1
        FROM homeopath
        WHERE homeopath_id = v_person_id
    )
    AND NOT EXISTS (
        SELECT 1
        FROM participant
        WHERE participant_id = v_person_id
    )
    AND NOT EXISTS (
        SELECT 1
        FROM lecturer
        WHERE lecturer_id = v_person_id
    )
    THEN
        RAISE EXCEPTION
            'Person % must belong to at least one subtype.',
            v_person_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_person_total
AFTER INSERT OR UPDATE ON person
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_person_total();

CREATE CONSTRAINT TRIGGER trg_patient_total_delete
AFTER DELETE ON patient
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_person_total();

CREATE CONSTRAINT TRIGGER trg_homeopath_total_delete
AFTER DELETE ON homeopath
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_person_total();

CREATE CONSTRAINT TRIGGER trg_participant_total_delete
AFTER DELETE ON participant
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_person_total();

CREATE CONSTRAINT TRIGGER trg_lecturer_total_delete
AFTER DELETE ON lecturer
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_person_total();

-- Trigger 2:
-- The homeopath in a consultation must be assigned to that patient.
-- A patient can have only one Initial consultation.
CREATE OR REPLACE FUNCTION fn_check_consultation_rules()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM patient_homeopath
        WHERE patient_id = NEW.patient_id
          AND homeopath_id = NEW.homeopath_id
    ) THEN
        RAISE EXCEPTION 'The homeopath must be assigned to the patient.';
    END IF;

    IF NEW.type = 'Initial' AND EXISTS (
        SELECT 1
        FROM consultation
        WHERE patient_id = NEW.patient_id
          AND type = 'Initial'
          AND consultation_id <> COALESCE(NEW.consultation_id, -1)
    ) THEN
        RAISE EXCEPTION 'A patient can have only one Initial consultation.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_consultation_rules
BEFORE INSERT OR UPDATE ON consultation
FOR EACH ROW
EXECUTE FUNCTION fn_check_consultation_rules();

-- Trigger 3:
-- An Initial consultation must have a MEDICATE decision.
-- The prescription constraint ensures that MEDICATE has exactly one medication.
CREATE OR REPLACE FUNCTION fn_check_prescription_logic()
RETURNS TRIGGER AS $$
DECLARE
    v_consultation_type VARCHAR(20);
BEGIN
    SELECT type
    INTO v_consultation_type
    FROM consultation
    WHERE consultation_id = NEW.consultation_id;

    IF v_consultation_type = 'Initial'
       AND NEW.decision <> 'MEDICATE' THEN
        RAISE EXCEPTION 'An Initial consultation must result in MEDICATE.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prescription_logic
BEFORE INSERT OR UPDATE ON prescription
FOR EACH ROW
EXECUTE FUNCTION fn_check_prescription_logic();

-- Trigger 5:
-- Recording availability is always exactly 21 days from the session date.
CREATE OR REPLACE FUNCTION fn_set_recording_dates()
RETURNS TRIGGER AS $$
DECLARE
    v_session_date DATE;
BEGIN
    SELECT session_date
    INTO v_session_date
    FROM session
    WHERE session_id = NEW.session_id;

    IF v_session_date IS NULL THEN
        RAISE EXCEPTION 'The related session does not exist.';
    END IF;
-- ex:Começar a 8 de janeiro; Terminar a 29 de janeiro.
    NEW.available_from := v_session_date;
    NEW.available_until := v_session_date + 21;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_recording_dates
BEFORE INSERT OR UPDATE ON recording
FOR EACH ROW
EXECUTE FUNCTION fn_set_recording_dates();

-- If a session date changes, update its recording dates too.
CREATE OR REPLACE FUNCTION fn_update_recording_dates()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE recording
    SET available_from = NEW.session_date,
        available_until = NEW.session_date + 21
    WHERE session_id = NEW.session_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_recording_dates
AFTER UPDATE OF session_date ON session
FOR EACH ROW
EXECUTE FUNCTION fn_update_recording_dates();

-- PURCHASE specialization:
-- every purchase must belong to exactly one subtype.

CREATE OR REPLACE FUNCTION fn_check_purchase_total()
RETURNS TRIGGER AS $$
DECLARE
    v_count INT;
    v_purchase_id INT;
BEGIN
    IF TG_TABLE_NAME = 'purchase' THEN
        v_purchase_id := NEW.purchase_id;
    ELSIF TG_OP = 'DELETE' THEN
        v_purchase_id := OLD.purchase_id;
    ELSE
        v_purchase_id := NEW.purchase_id;
    END IF;

    -- Deleting PURCHASE cascades to its subtypes; do not block that deletion.
    IF NOT EXISTS (SELECT 1 FROM purchase WHERE purchase_id = v_purchase_id) THEN
        RETURN NULL;
    END IF;

    SELECT
        (CASE WHEN EXISTS (
            SELECT 1
            FROM single_session_purchase
            WHERE purchase_id = v_purchase_id
        ) THEN 1 ELSE 0 END)
        +
        (CASE WHEN EXISTS (
            SELECT 1
            FROM package_purchase
            WHERE purchase_id = v_purchase_id
        ) THEN 1 ELSE 0 END)
    INTO v_count;

    IF v_count <> 1 THEN
        RAISE EXCEPTION
            'Purchase % must belong to exactly one purchase subtype.',
            v_purchase_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE CONSTRAINT TRIGGER trg_purchase_total
AFTER INSERT OR UPDATE ON purchase
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_purchase_total();

CREATE CONSTRAINT TRIGGER trg_single_purchase_total_delete
AFTER DELETE ON single_session_purchase
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_purchase_total();

CREATE CONSTRAINT TRIGGER trg_package_purchase_total_delete
AFTER DELETE ON package_purchase
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_purchase_total();

-- Check subtype additions and changes as well as deletions.
-- Deferred checking permits a new purchase and its subtype in one transaction.
CREATE CONSTRAINT TRIGGER trg_single_purchase_total_change
AFTER INSERT OR UPDATE ON single_session_purchase
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_purchase_total();

CREATE CONSTRAINT TRIGGER trg_package_purchase_total_change
AFTER INSERT OR UPDATE ON package_purchase
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_check_purchase_total();

-- Trigger 6:
-- Single-session purchases must enroll in one session;
-- package purchases must enroll in one cycle.
CREATE OR REPLACE FUNCTION fn_check_enrollment_type()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.session_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM single_session_purchase
            WHERE purchase_id = NEW.purchase_id
        ) OR EXISTS (
            SELECT 1
            FROM package_purchase
            WHERE purchase_id = NEW.purchase_id
        ) THEN
            RAISE EXCEPTION
                'A session enrollment requires one single-session purchase.';
        END IF;
    END IF;

    IF NEW.cycle_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM package_purchase
            WHERE purchase_id = NEW.purchase_id
        ) OR EXISTS (
            SELECT 1
            FROM single_session_purchase
            WHERE purchase_id = NEW.purchase_id
        ) THEN
            RAISE EXCEPTION
                'A cycle enrollment requires one package purchase.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_enrollment_type
BEFORE INSERT OR UPDATE ON enrollment
FOR EACH ROW
EXECUTE FUNCTION fn_check_enrollment_type();

-- Trigger 7:
-- Payment must equal the purchase amount and cannot predate the purchase.
CREATE OR REPLACE FUNCTION fn_check_payment_amount()
RETURNS TRIGGER AS $$
DECLARE
    v_total_amount DECIMAL(8,2);
    v_purchase_date DATE;
BEGIN
    SELECT total_amount, purchase_date
    INTO v_total_amount, v_purchase_date
    FROM purchase
    WHERE purchase_id = NEW.purchase_id;

    IF NEW.amount_paid <> v_total_amount THEN
        RAISE EXCEPTION 'Payment amount must equal the purchase total.';
    END IF;

    IF NEW.payment_date < v_purchase_date THEN
        RAISE EXCEPTION 'Payment date cannot be before purchase date.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_payment_amount
BEFORE INSERT OR UPDATE ON payment
FOR EACH ROW
EXECUTE FUNCTION fn_check_payment_amount();

-- Trigger 8:
-- Every payment automatically generates one invoice.
CREATE OR REPLACE FUNCTION fn_generate_invoice()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO invoice (
        invoice_number,
        issue_date,
        status,
        payment_id
    )
    VALUES (
        'INV-' || NEW.payment_id || '-' || TO_CHAR(NEW.payment_date, 'YYYYMMDD'),
        NEW.payment_date,
        'NOT_SENT',
        NEW.payment_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
--Quando é inserido um registo de `payment`, a base de dados cria automaticamente a `invoice` correspondente.
CREATE TRIGGER trg_generate_invoice
AFTER INSERT ON payment
FOR EACH ROW
EXECUTE FUNCTION fn_generate_invoice();

-- Certificate associations must reflect paid sessions in the correct program
-- and certification period, even when inserted directly via SQL.
CREATE OR REPLACE FUNCTION fn_check_certificate_session()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM certificate cert
        JOIN session s ON s.session_id = NEW.session_id
        JOIN cycle c ON c.cycle_id = s.cycle_id
        WHERE cert.certificate_id = NEW.certificate_id
          AND cert.training_program_id = c.training_program_id
          AND s.session_date BETWEEN cert.period_start AND cert.period_end
          AND EXISTS (
              SELECT 1
              FROM purchase pur
              JOIN payment pay ON pay.purchase_id = pur.purchase_id
              JOIN enrollment e ON e.purchase_id = pur.purchase_id
              WHERE pur.participant_id = cert.participant_id
                AND (e.session_id = s.session_id OR e.cycle_id = s.cycle_id)
          )
    ) THEN
        RAISE EXCEPTION 'Certificate session must be paid and within the certificate program and period.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_certificate_session
BEFORE INSERT OR UPDATE ON certificate_session
FOR EACH ROW EXECUTE FUNCTION fn_check_certificate_session();

-- =========================================================
-- ADDITIONAL D1 INTEGRITY CONSTRAINTS
-- Group 11 - Final integrity improvements
-- =========================================================

BEGIN;

-- =========================================================
-- 1. Every patient must have at least one homeopath.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_require_patient_homeopath()
RETURNS TRIGGER AS $$
DECLARE
    v_patient_id INT;
BEGIN
    IF TG_TABLE_NAME = 'patient' THEN
        v_patient_id := NEW.patient_id;
    ELSE
        v_patient_id := OLD.patient_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM patient
        WHERE patient_id = v_patient_id
    )
    AND NOT EXISTS (
        SELECT 1
        FROM patient_homeopath
        WHERE patient_id = v_patient_id
    ) THEN
        RAISE EXCEPTION
            'Patient % must have at least one assigned homeopath.',
            v_patient_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE CONSTRAINT TRIGGER trg_patient_requires_homeopath
AFTER INSERT OR UPDATE OF patient_id ON patient
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_require_patient_homeopath();


CREATE CONSTRAINT TRIGGER trg_patient_assignment_removed
AFTER DELETE OR UPDATE OF patient_id ON patient_homeopath
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_require_patient_homeopath();


-- =========================================================
-- 2. Every Initial consultation must have a MEDICATE
-- prescription with medication.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_require_initial_prescription()
RETURNS TRIGGER AS $$
DECLARE
    v_consultation_id INT;
BEGIN
    IF TG_TABLE_NAME = 'consultation' THEN
        v_consultation_id := NEW.consultation_id;
    ELSE
        v_consultation_id := OLD.consultation_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM consultation c
        WHERE c.consultation_id = v_consultation_id
          AND c.type = 'Initial'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM prescription p
        WHERE p.consultation_id = v_consultation_id
          AND p.decision = 'MEDICATE'
          AND p.medication_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION
            'Initial consultation % must have a MEDICATE prescription with medication.',
            v_consultation_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE CONSTRAINT TRIGGER trg_initial_requires_prescription
AFTER INSERT OR UPDATE OF type ON consultation
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_require_initial_prescription();


CREATE CONSTRAINT TRIGGER trg_initial_prescription_removed
AFTER DELETE OR UPDATE OF consultation_id, decision, medication_id
ON prescription
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_require_initial_prescription();


-- =========================================================
-- 3. Every certificate must cover at least one session.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_require_certificate_sessions()
RETURNS TRIGGER AS $$
DECLARE
    v_certificate_id INT;
BEGIN
    IF TG_TABLE_NAME = 'certificate' THEN
        v_certificate_id := NEW.certificate_id;
    ELSE
        v_certificate_id := OLD.certificate_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM certificate
        WHERE certificate_id = v_certificate_id
    )
    AND NOT EXISTS (
        SELECT 1
        FROM certificate_session
        WHERE certificate_id = v_certificate_id
    ) THEN
        RAISE EXCEPTION
            'Certificate % must cover at least one session.',
            v_certificate_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE CONSTRAINT TRIGGER trg_certificate_requires_sessions
AFTER INSERT OR UPDATE OF
    participant_id, training_program_id, period_start, period_end
ON certificate
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_require_certificate_sessions();


CREATE CONSTRAINT TRIGGER trg_certificate_last_session_removed
AFTER DELETE OR UPDATE OF certificate_id ON certificate_session
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_require_certificate_sessions();


COMMIT;
