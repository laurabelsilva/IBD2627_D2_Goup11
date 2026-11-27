/*
 * Salus D4 - data adjustments after data_d4.sql
 * Run in database salus_d4 as a SCRIPT (Alt + X in DBeaver), only once.
 * Everything is inside one transaction: either all changes are saved or none.
 */

BEGIN;

-- 1) 8 more medications (Belladonna and Nux Vomica already exist)
INSERT INTO medication (name, potency, form)
SELECT v.name, v.potency, v.form
FROM (VALUES
    ('Arnica montana',     '30C',  'Globules'),
    ('Arsenicum album',    '30C',  'Globules'),
    ('Rhus toxicodendron', '30C',  'Globules'),
    ('Allium cepa',        '9C',   'Globules'),
    ('Chamomilla',         '9C',   'Globules'),
    ('Ignatia amara',      '200C', 'Globules'),
    ('Pulsatilla',         '30C',  'Globules'),
    ('Aconitum napellus',  '200C', 'Globules')
) AS v(name, potency, form)
WHERE NOT EXISTS (SELECT 1 FROM medication m WHERE lower(m.name) = lower(v.name));

-- 2) Spread the MEDICATE prescriptions over the 10 medications
WITH numbered AS (
    SELECT medication_id,
           ROW_NUMBER() OVER (ORDER BY medication_id) - 1 AS n
    FROM medication
)
UPDATE prescription p
SET medication_id = m.medication_id
FROM numbered m
WHERE p.decision = 'MEDICATE'
  AND m.n = p.consultation_id % (SELECT COUNT(*) FROM medication);

-- 3) Symptoms: delete the 3 old values and create 25 with the requested prevalence
DELETE FROM symptom;

INSERT INTO symptom (name, description, consultation_id)
SELECT s.name,
       'Recorded during the consultation for clinical follow-up.',
       c.consultation_id
FROM consultation c
CROSS JOIN (VALUES
    ('Fatigue', 45), ('Backache', 42), ('Headache', 39), ('Insomnia', 35),
    ('Myalgia', 30), ('Arthralgia', 28), ('Cough', 25), ('Anxiety', 23),
    ('Depression', 20), ('Dizziness', 18), ('Dyspnea', 15), ('Heartburn', 14),
    ('Rhinorrhea', 13), ('Pruritus', 12), ('Rash', 11), ('Fever', 10),
    ('Nausea', 9), ('Diarrhea', 8), ('Constipation', 8), ('Edema', 7),
    ('Palpitations', 6), ('Dysuria', 5), ('Tinnitus', 5), ('Paresthesia', 4),
    ('Syncope', 3)
) AS s(name, pct)
WHERE (hashtext(c.consultation_id::text || s.name) & 2147483647) % 100 < s.pct;

-- 4) Invoices: about half become SENT (status and sent_date change together)
UPDATE invoice
SET status = 'SENT',
    sent_date = issue_date + 1
WHERE status = 'NOT_SENT'
  AND invoice_id % 2 = 0;

COMMIT;
