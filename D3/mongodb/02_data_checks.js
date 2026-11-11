/*
 * Basic checks after migration.
 * Run after migration/migrate_from_postgres.sh.
 */

const salus = db;

// Each collection should contain one document for each source patient or participant.
print("\n=== DOCUMENT COUNTS ===");
print("patient_case_files: " + salus.patient_case_files.countDocuments());
print(
    "participant_training_profiles: " +
    salus.participant_training_profiles.countDocuments()
);

print("\n=== EMBEDDED DATA COUNTS ===");
// Each pipeline expands an embedded array and then totals its elements.
// This lets us compare embedded MongoDB totals with relational PostgreSQL rows.
function pipelineCount(collection, pipeline) {
    const result = collection.aggregate([
        ...pipeline,
        { $group: { _id: null, total: { $sum: 1 } } }
    ]).toArray();
    return result.length === 0 ? 0 : result[0].total;
}
printjson({
    embeddedConsultations: pipelineCount(salus.patient_case_files, [
        { $unwind: "$consultations" }
    ]),
    embeddedSymptoms: pipelineCount(salus.patient_case_files, [
        { $unwind: "$consultations" },
        { $unwind: "$consultations.symptoms" }
    ]),
    embeddedPurchases: pipelineCount(salus.participant_training_profiles, [
        { $unwind: "$purchases" }
    ]),
    embeddedPaidPurchases: pipelineCount(salus.participant_training_profiles, [
        { $unwind: "$purchases" },
        { $match: { "purchases.paid": true } }
    ]),
    embeddedCertificates: pipelineCount(salus.participant_training_profiles, [
        { $unwind: "$certificates" }
    ]),
    embeddedCertificateSessions: pipelineCount(salus.participant_training_profiles, [
        { $unwind: "$certificates" },
        { $unwind: "$certificates.coveredSessions" }
    ])
});

print("\n=== SAMPLE PATIENT CASE FILE ===");
// Choose the first patient that has at least one consultation.
const samplePatient = salus.patient_case_files.findOne({
    "consultations.0": { $exists: true }
});

if (samplePatient) {
    printjson(samplePatient);
} else {
    // If no patient has consultations, show any patient.
    printjson(salus.patient_case_files.findOne());
}

print("\n=== SAMPLE PARTICIPANT TRAINING PROFILE ===");
printjson(salus.participant_training_profiles.findOne({ _id: 1 }));
