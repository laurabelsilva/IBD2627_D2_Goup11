
/*
 * Salus D3 - PostgreSQL to MongoDB Consistency Checks
 *
 * @author Ana Paula Tavares 68081
 * @author Laura Silva 68469
 * @author Xiaoji Wu 59800
 *
 * The migration exports PostgreSQL counts and monetary totals to SYNC_FILE.
 * The script fails if any equivalent MongoDB total differs.
 *
 * 1. PostgreSQL exports the original record counts.
 * 2. MongoDB uses $unwind to expand embedded arrays.
 * 3. Eight original counts and four additional metrics are checked.
 * 4. Matching values produce PASS; different values produce FAIL.
 */

const fs = require("fs");
const salus = db;
const syncFile = process.env.SYNC_FILE;

if (!syncFile) {
    throw new Error("SYNC_FILE is required. Run migration/migrate_from_postgres.sh.");
}

// Read the PostgreSQL reference values.
const expected = JSON.parse(fs.readFileSync(syncFile, "utf8").trim());

// Sum values from MongoDB aggregation pipelines.
function aggregateSum(collection, pipeline, expression) {
    const result = collection.aggregate([
        ...pipeline,
        { $group: { _id: null, total: { $sum: expression } } }
    ]).toArray();

    return result.length === 0 ? 0 : result[0].total;
}

// Convert monetary values to integer cents before comparison.
function cents(fieldPath) {
    return {
        $toLong: {
            $round: [{ $multiply: [fieldPath, 100] }, 0]
        }
    };
}

// Count embedded elements using aggregation pipelines.
function aggregateCount(collection, pipeline) {
    const result = collection.aggregate([
        ...pipeline,
        { $group: { _id: null, total: { $sum: 1 } } }
    ]).toArray();

    return result.length === 0 ? 0 : result[0].total;
}

// MongoDB equivalent metrics.
const actual = {

    // 1. Patient documents.
    patient_documents:
        salus.patient_case_files.countDocuments(),

    // 2. Embedded consultations.
    consultations: aggregateCount(salus.patient_case_files, [
        { $unwind: "$consultations" }
    ]),

    // 3. Embedded symptoms.
    symptoms: aggregateCount(salus.patient_case_files, [
        { $unwind: "$consultations" },
        { $unwind: "$consultations.symptoms" }
    ]),

    // 4. Participant documents.
    participant_documents:
        salus.participant_training_profiles.countDocuments(),

    // 5. Embedded purchases.
    purchases: aggregateCount(salus.participant_training_profiles, [
        { $unwind: "$purchases" }
    ]),

    // 6. Paid purchases.
    paid_purchases: aggregateCount(salus.participant_training_profiles, [
        { $unwind: "$purchases" },
        { $match: { "purchases.paid": true } }
    ]),

    // 7. Certificates.
    certificates: aggregateCount(salus.participant_training_profiles, [
        { $unwind: "$certificates" }
    ]),

    // 8. Certificate-session relationships.
    certificate_sessions: aggregateCount(
        salus.participant_training_profiles,
        [
            { $unwind: "$certificates" },
            { $unwind: "$certificates.coveredSessions" }
        ]
    ),

    // 9. Patient-homeopath relationships.
    patient_homeopath_links: aggregateCount(salus.patient_case_files, [
        { $unwind: "$assignedHomeopaths" }
    ]),

    // 10. WAIT prescriptions without medication.
    wait_no_medication: aggregateCount(salus.patient_case_files, [
        { $unwind: "$consultations" },
        {
            $match: {
                "consultations.prescription.decision": "WAIT",
                "consultations.prescription.medication": null
            }
        }
    ]),

    // 11. Total purchase value in cents.
    purchase_total_cents: aggregateSum(
        salus.participant_training_profiles,
        [{ $unwind: "$purchases" }],
        cents("$purchases.amount")
    ),

    // 12. Total paid value in cents.
    paid_total_cents: aggregateSum(
        salus.participant_training_profiles,
        [
            { $unwind: "$purchases" },
            { $match: { "purchases.paid": true } }
        ],
        cents("$purchases.payment.amountPaid")
    )
};

// Compare PostgreSQL with MongoDB.
print("\n=== POSTGRESQL TO MONGODB CONSISTENCY CHECK ===");

let failures = 0;

Object.keys(expected).forEach((metric) => {

    const passed =
        Number(expected[metric]) === Number(actual[metric]);

    if (!passed) {
        failures += 1;
    }

    print([
        metric.padEnd(24),
        "PostgreSQL=" + expected[metric],
        "MongoDB=" + actual[metric],
        passed ? "PASS" : "FAIL"
    ].join(" | "));
});

// Fail the migration if any metric differs.
if (failures > 0) {
    throw new Error(failures + " consistency checks failed.");
}

print("All PostgreSQL to MongoDB consistency checks passed.");
