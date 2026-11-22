
/*
 * Salus D3 - MongoDB Queries and CRUD Operations
 *
 * @author Ana Paula Tavares 68081
 * @author Laura Silva 68469
 * @author Xiaoji Wu 59800
 *
 * Q1-Q10 are aggregation queries.
 * Q11-Q14 are CRUD operations using a temporary patient document.
 */

const salus = db;
const today = new Date().toISOString().slice(0, 10);

function show(title, cursor) {
    print("\n============================================================");
    print(title);
    print("============================================================");
    cursor.forEach((document) => printjson(document));
}

// Q1. Find patients with an embedded Headache symptom.
show(
    "Q1 - Patients with embedded Headache symptoms",
    salus.patient_case_files.aggregate([
        // One patient document can contain several consultations and symptoms.
        { $unwind: "$consultations" },
        { $unwind: "$consultations.symptoms" },
        { $match: { "consultations.symptoms.name": "Headache" } },
        {
            $group: {
                _id: "$patient.patientId",
                patient: { $first: "$patient.name" },
                headacheConsultations: { $sum: 1 },
                latestConsultation: { $max: "$consultations.date" }
            }
        },
        { $sort: { headacheConsultations: -1, patient: 1 } },
        { $limit: 10 }
    ])
);

// Q2. Chronological clinical timeline for one patient, with nested details and
// a cross-check that the consultation homeopath is assigned to that patient.
// Select a real patient dynamically so the query works after a fresh migration.
const q2Patient = salus.patient_case_files.findOne(
    { "consultations.0": { $exists: true } },
    { _id: 1 }
);
const q2PatientId = q2Patient ? q2Patient._id : null;

if (q2PatientId === null) {
    print("Q2 - No patient_case_file with consultations found. Skipping Q2.");
} else {
    show(
        "Q2 - Clinical timeline, symptom counts and assigned homeopath checks",
        salus.patient_case_files.aggregate([
            { $match: { _id: q2PatientId } },
            { $unwind: "$consultations" },
            {
                $addFields: {
                    symptomCount: { $size: { $ifNull: ["$consultations.symptoms", []] } },
                    homeopathIsAssigned: {
                        $in: [
                            "$consultations.homeopath.homeopathId",
                            "$assignedHomeopaths.homeopathId"
                        ]
                    }
                }
            },
            {
                $project: {
                    _id: 0,
                    patientId: "$patient.patientId",
                    patient: "$patient.name",
                    date: "$consultations.date",
                    type: "$consultations.type",
                    homeopath: "$consultations.homeopath.name",
                    homeopathIsAssigned: 1,
                    decision: "$consultations.prescription.decision",
                    medication: "$consultations.prescription.medication.name",
                    symptomCount: 1,
                    symptoms: "$consultations.symptoms.name"
                }
            },
            { $sort: { date: 1, type: 1 } }
        ])
    );
}

// Q3. Patient load per assigned homeopath, calculated from embedded arrays.
show(
    "Q3 - Patient load per homeopath",
    salus.patient_case_files.aggregate([
        { $unwind: "$assignedHomeopaths" },
        {
            $group: {
                _id: "$assignedHomeopaths.homeopathId",
                homeopath: { $first: "$assignedHomeopaths.name" },
                totalPatients: { $sum: 1 }
            }
        },
        { $sort: { totalPatients: -1, homeopath: 1 } },
        { $limit: 10 }
    ])
);

// Q4. Medication frequency for MEDICATE consultations.
show(
    "Q4 - Medication use in MEDICATE consultations",
    salus.patient_case_files.aggregate([
        { $unwind: "$consultations" },
        { $match: { "consultations.prescription.decision": "MEDICATE" } },
        {
            $group: {
                _id: "$consultations.prescription.medication.name",
                prescriptions: { $sum: 1 },
                // $addToSet avoids counting the same patient twice.
                patients: { $addToSet: "$patient.patientId" }
            }
        },
        {
            $project: {
                _id: 0,
                medication: "$_id",
                prescriptions: 1,
                distinctPatients: { $size: "$patients" }
            }
        },
        { $sort: { prescriptions: -1, medication: 1 } }
    ])
);

// Q5. Clinical follow-up analysis: compare Initial and Follow-up visits per patient.
// Grouping the embedded consultations also shows the earliest/latest dates and
// distinct prescription decisions, rather than only counting array elements.
show(
    "Q5 - Patient follow-up histories and prescription decisions",
    salus.patient_case_files.aggregate([
        { $unwind: "$consultations" },
        {
            $group: {
                _id: "$patient.patientId",
                patient: { $first: "$patient.name" },
                totalConsultations: { $sum: 1 },
                initialVisits: {
                    $sum: { $cond: [{ $eq: ["$consultations.type", "Initial"] }, 1, 0] }
                },
                followUpVisits: {
                    $sum: { $cond: [{ $eq: ["$consultations.type", "Follow-up"] }, 1, 0] }
                },
                firstConsultation: { $min: "$consultations.date" },
                latestConsultation: { $max: "$consultations.date" },
                decisions: { $addToSet: "$consultations.prescription.decision" }
            }
        },
        { $match: { totalConsultations: { $gt: 1 } } },
        {
            $project: {
                _id: 0,
                patientId: "$_id",
                patient: 1,
                totalConsultations: 1,
                initialVisits: 1,
                followUpVisits: 1,
                firstConsultation: 1,
                latestConsultation: 1,
                decisions: 1
            }
        },
        { $sort: { followUpVisits: -1, latestConsultation: -1, patient: 1 } },
        { $limit: 10 }
    ])
);

// Q6. Paid recordings that are available today. Dates use ISO YYYY-MM-DD.
// Multiple paid purchases may grant the same participant access to one session.
// Group by participant ID and session ID to avoid duplicate recording entries.
show(
    "Q6 - Paid recordings currently available to participants",
    salus.participant_training_profiles.aggregate([
        { $unwind: "$purchases" },
        { $match: { "purchases.paid": true } },
        { $unwind: "$purchases.accessibleSessions" },
        {
            $match: {
                "purchases.accessibleSessions.recording": { $ne: null },
                "purchases.accessibleSessions.recording.availableFrom": { $lte: today },
                "purchases.accessibleSessions.recording.availableUntil": { $gte: today }
            }
        },
        {
            $group: {
                _id: {
                    participantId: "$participant.participantId",
                    sessionId: "$purchases.accessibleSessions.sessionId"
                },
                participant: { $first: "$participant.name" },
                session: { $first: "$purchases.accessibleSessions.topic" },
                sessionDate: { $first: "$purchases.accessibleSessions.sessionDate" },
                recordingUrl: { $first: "$purchases.accessibleSessions.recording.url" },
                availableUntil: { $max: "$purchases.accessibleSessions.recording.availableUntil" }
            }
        },
        {
            $project: {
                _id: 0,
                participant: 1,
                session: 1,
                sessionDate: 1,
                recordingUrl: 1,
                availableUntil: 1
            }
        },
        { $sort: { participant: 1, sessionDate: 1 } },
        { $limit: 10 }
    ])
);

// Q7. Paid revenue by training programme.
show(
    "Q7 - Paid revenue by training programme",
    salus.participant_training_profiles.aggregate([
        { $unwind: "$purchases" },
        // Unpaid purchases must not contribute to revenue.
        { $match: { "purchases.paid": true } },
        {
            $group: {
                _id: "$purchases.program.programId",
                trainingProgram: { $first: "$purchases.program.name" },
                totalRevenue: { $sum: "$purchases.amount" },
                paidPurchases: { $sum: 1 }
            }
        },
        { $sort: { totalRevenue: -1 } }
    ])
);

// Q8. Unpaid package purchases grouped by programme for follow-up planning.
// Calculate the outstanding balance, the number of affected participants,
// and the oldest pending purchase; include a few example purchases in the results.
show(
    "Q8 - Unpaid package balances by training programme",
    salus.participant_training_profiles.aggregate([
        { $unwind: "$purchases" },
        {
            $match: {
                "purchases.paid": false,
                "purchases.type": "package"
            }
        },
        {
            $group: {
                _id: "$purchases.program.programId",
                programme: { $first: "$purchases.program.name" },
                pendingPurchases: { $sum: 1 },
                outstandingAmount: { $sum: "$purchases.amount" },
                oldestPurchaseDate: { $min: "$purchases.purchaseDate" },
                participantIds: { $addToSet: "$participant.participantId" },
                examples: {
                    $push: {
                        purchaseId: "$purchases.purchaseId",
                        participant: "$participant.name",
                        amount: "$purchases.amount"
                    }
                }
            }
        },
        {
            $project: {
                _id: 0,
                programId: "$_id",
                programme: 1,
                pendingPurchases: 1,
                outstandingAmount: 1,
                oldestPurchaseDate: 1,
                distinctParticipants: { $size: "$participantIds" },
                examplePurchases: { $slice: ["$examples", 5] }
            }
        },
        { $sort: { outstandingAmount: -1, programme: 1 } }
    ])
);

// Q9. Training hours and certificates grouped by programme.
// Summarize participant-level certificate arrays without double-counting people.
show(
    "Q9 - Certificates, distinct participants and training hours by programme",
    salus.participant_training_profiles.aggregate([
        { $unwind: "$certificates" },
        {
            $project: {
                _id: 0,
                participantId: "$participant.participantId",
                participant: "$participant.name",
                certificateId: "$certificates.certificateId",
                programmeId: "$certificates.program.programId",
                programme: "$certificates.program.name",
                coveredSessions: { $size: "$certificates.coveredSessions" },
                // Salus awards two training hours per covered session.
                creditedHours: { $multiply: [{ $size: "$certificates.coveredSessions" }, 2] }
            }
        },
        {
            $group: {
                _id: { programmeId: "$programmeId", programme: "$programme" },
                certificatesIssued: { $sum: 1 },
                participantIds: { $addToSet: "$participantId" },
                totalCoveredSessions: { $sum: "$coveredSessions" },
                totalCreditedHours: { $sum: "$creditedHours" },
                examples: {
                    $push: {
                        participant: "$participant",
                        certificateId: "$certificateId",
                        creditedHours: "$creditedHours"
                    }
                }
            }
        },
        {
            $project: {
                _id: 0,
                programmeId: "$_id.programmeId",
                programme: "$_id.programme",
                certificatesIssued: 1,
                distinctParticipants: { $size: "$participantIds" },
                totalCoveredSessions: 1,
                totalCreditedHours: 1,
                examples: { $slice: ["$examples", 5] }
            }
        },
        { $sort: { totalCreditedHours: -1, programme: 1 } }
    ])
);

// Q10. Participants with paid learning activity in more than one programme.
show(
    "Q10 - Participants with paid activity in multiple programmes",
    salus.participant_training_profiles.aggregate([
        { $unwind: "$purchases" },
        { $match: { "purchases.paid": true } },
        {
            $group: {
                _id: "$participant.participantId",
                participant: { $first: "$participant.name" },
                // Store programme names once even if there are many purchases.
                programmes: { $addToSet: "$purchases.program.name" },
                totalPaidPurchases: { $sum: 1 }
            }
        },
        {
            $project: {
                _id: 0,
                participantId: "$_id",
                participant: 1,
                programmes: 1,
                programmeCount: { $size: "$programmes" },
                totalPaidPurchases: 1
            }
        },
        { $match: { programmeCount: { $gt: 1 } } },
        { $sort: { programmeCount: -1, participant: 1 } },
        { $limit: 10 }
    ])
);

// Q11. CREATE - insert a realistic temporary patient document.
// Reuse a real homeopath from the migrated data so the assignment and
// the Initial consultation refer to the same homeopath.
const demoId = 999999;
const homeopathExample = salus.patient_case_files.findOne(
    { "assignedHomeopaths.0": { $exists: true } },
    { assignedHomeopaths: 1 }
);
if (!homeopathExample || !homeopathExample.assignedHomeopaths.length) {
    throw new Error("CRUD demo requires an existing assigned homeopath.");
}
const demoHomeopath = homeopathExample.assignedHomeopaths[0];

salus.patient_case_files.deleteOne({ _id: demoId });

print("\nQ11 - CREATE temporary patient case file");
printjson(salus.patient_case_files.insertOne({
    _id: demoId,
    patient: {
        patientId: demoId,
        name: "Mongo Demo Patient",
        email: "mongo.demo.patient@salus.pt",
        phone: null,
        country: "Portugal"
    },
    assignedHomeopaths: [demoHomeopath],
    consultations: [],
    migration: { source: "CRUD demonstration", component: "patient_case_files" }
}));

// Q12. READ - retrieve only the temporary document.
print("\nQ12 - READ temporary patient case file");
printjson(salus.patient_case_files.findOne(
    { _id: demoId },
    { _id: 1, patient: 1, consultations: 1 }
));


// Q13. UPDATE - $push appends one item to the consultations array.
print("\nQ13 - UPDATE temporary case file with an embedded consultation");
printjson(salus.patient_case_files.updateOne(
    { _id: demoId },
    {
        $push: {
            consultations: {
                consultationId: "demo-consultation-1",
                date: today,
                type: "Initial",
                notes: "Initial assessment for temporary CRUD demonstration.",
                homeopath: {
                    homeopathId: demoHomeopath.homeopathId,
                    name: demoHomeopath.name
                },
                symptoms: [{ name: "Demo symptom", description: "Temporary" }],
                prescription: {
                    decision: "MEDICATE",
                    medication: {
                        medicationId: "demo-medication-1",
                        name: "Demo medication",
                        potency: "30C",
                        form: "Granules"
                    }
                }
            }
        }
    }
));

printjson(salus.patient_case_files.findOne(
    { _id: demoId },
    { _id: 0, "patient.name": 1, consultations: 1 }
));

// Q14. DELETE - remove the temporary document so migrated data remains unchanged.
print("\nQ14 - DELETE temporary patient case file");
printjson(salus.patient_case_files.deleteOne({ _id: demoId }));

print("Temporary document remaining: " +
    salus.patient_case_files.countDocuments({ _id: demoId }));

/**
$match    = filter / WHERE
$unwind   = expand array
$group    = GROUP BY
$project  = choose / calculate output fields
$sort     = ORDER BY
$limit    = LIMIT
 */
