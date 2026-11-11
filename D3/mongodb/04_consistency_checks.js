/*
 * Consistency checks.
 *
 * The migration exports PostgreSQL counts to the file named by SYNC_FILE.
 * The script fails if any equivalent MongoDB total differs.
 * 
 * 1. PostgreSQL first exports the original record counts.  
 * 2. MongoDB uses `$unwind` to expand embedded arrays before counting them.  
 * 3. The script compares eight equivalent counts between the two systems.  
 * 4. Different values produce `FAIL`; matching values produce `PASS`.
 */

const fs = require("fs");
const salus = db;
const syncFile = process.env.SYNC_FILE;

if (!syncFile) {
    throw new Error("SYNC_FILE is required. Run migration/migrate_from_postgres.sh.");
}

// PostgreSQL exports the source counts as one JSON object.
const expected = JSON.parse(fs.readFileSync(syncFile, "utf8").trim());

function aggregateCount(collection, pipeline) {
    const result = collection.aggregate([
        ...pipeline,
        { $group: { _id: null, total: { $sum: 1 } } }
    ]).toArray();
    return result.length === 0 ? 0 : result[0].total;
}

// The same concepts are counted after arrays have been embedded in MongoDB.
const actual = {
    patient_documents: salus.patient_case_files.countDocuments(),
    consultations: aggregateCount(salus.patient_case_files, [
        { $unwind: "$consultations" }
    ]),
    symptoms: aggregateCount(salus.patient_case_files, [
        { $unwind: "$consultations" },
        { $unwind: "$consultations.symptoms" }
    ]),
    participant_documents: salus.participant_training_profiles.countDocuments(),
    purchases: aggregateCount(salus.participant_training_profiles, [
        { $unwind: "$purchases" }
    ]),
    paid_purchases: aggregateCount(salus.participant_training_profiles, [
        { $unwind: "$purchases" },
        { $match: { "purchases.paid": true } }
    ]),
    certificates: aggregateCount(salus.participant_training_profiles, [
        { $unwind: "$certificates" }
    ]),
    certificate_sessions: aggregateCount(salus.participant_training_profiles, [
        { $unwind: "$certificates" },
        { $unwind: "$certificates.coveredSessions" }
    ])
};

print("\n=== POSTGRESQL TO MONGODB CONSISTENCY CHECK ===");
let failures = 0;

Object.keys(expected).forEach((metric) => {
    // A mismatch stops the migration instead of silently accepting inconsistent data.
    const passed = Number(expected[metric]) === Number(actual[metric]);
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

if (failures > 0) {
    throw new Error(failures + " consistency checks failed.");
}

print("All PostgreSQL to MongoDB consistency checks passed.");
