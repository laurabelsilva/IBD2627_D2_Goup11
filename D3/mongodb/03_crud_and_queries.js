/*
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

// Q2. Unwind one patient document into a chronological clinical timeline.
// Do not hardcode _id: find a real patient that has at least one consultation.
const q2Patient = salus.patient_case_files.findOne(
    { "consultations.0": { $exists: true } },
    { _id: 1 }
);
const q2PatientId = q2Patient ? q2Patient._id : null;

if (q2PatientId === null) {
    print("Q2 - No patient_case_file with consultations found. Skipping Q2.");
} else {
    show(
        "Q2 - Clinical timeline for one patient with consultations",
        salus.patient_case_files.aggregate([
            { $match: { _id: q2PatientId } },
            { $unwind: "$consultations" },
            {
                $project: {
                    _id: 0,
                    patient: "$patient.name",
                    date: "$consultations.date",
                    type: "$consultations.type",
                    homeopath: "$consultations.homeopath.name",
                    decision: "$consultations.prescription.decision",
                    symptoms: "$consultations.symptoms.name"
                }
            },
            { $sort: { date: 1 } }
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

// Q5. Patients with more than one consultation. $size supports variable arrays.
show(
    "Q5 - Patients with more than one consultation",
    salus.patient_case_files.aggregate([
        {
            $project: {
                _id: 0,
                patientId: "$patient.patientId",
                patient: "$patient.name",
                totalConsultations: { $size: "$consultations" }
            }
        },
        { $match: { totalConsultations: { $gt: 1 } } },
        { $sort: { totalConsultations: -1, patient: 1 } },
        { $limit: 10 }
    ])
);

// Q6. Paid recordings that are available today. Dates are ISO YYYY-MM-DD
// strings, so the standard $gte and $lte comparisons are safe.
show(
    "Q6 - Paid recordings currently available to participants",
    salus.participant_training_profiles.aggregate([
        { $unwind: "$purchases" },
        // Only a completed payment gives access to a recording.
        { $match: { "purchases.paid": true } },
        { $unwind: "$purchases.accessibleSessions" },
        {
            $match: {
                "purchases.accessibleSessions.recording": { $ne: null },
                "purchases.accessibleSessions.recording.availableFrom": {
                    $lte: today
                },
                "purchases.accessibleSessions.recording.availableUntil": {
                    $gte: today
                }
            }
        },
        {
            $project: {
                _id: 0,
                participant: "$participant.name",
                session: "$purchases.accessibleSessions.topic",
                sessionDate: "$purchases.accessibleSessions.sessionDate",
                recordingUrl: "$purchases.accessibleSessions.recording.url",
                availableUntil: "$purchases.accessibleSessions.recording.availableUntil"
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

// Q8. Unpaid package purchases requiring follow-up.
show(
    "Q8 - Unpaid package purchases",
    salus.participant_training_profiles.aggregate([
        { $unwind: "$purchases" },
        {
            $match: {
                "purchases.paid": false,
                "purchases.type": "package"
            }
        },
        {
            $project: {
                _id: 0,
                participantId: "$participant.participantId",
                participant: "$participant.name",
                purchaseId: "$purchases.purchaseId",
                purchaseDate: "$purchases.purchaseDate",
                amount: "$purchases.amount",
                programme: "$purchases.program.name"
            }
        },
        { $sort: { purchaseDate: 1 } },
        { $limit: 10 }
    ])
);

// Q9. Certificate hours based on each embedded covered-session array.
show(
    "Q9 - Certificates and covered training hours",
    salus.participant_training_profiles.aggregate([
        { $unwind: "$certificates" },
        {
            $project: {
                _id: 0,
                participant: "$participant.name",
                certificateId: "$certificates.certificateId",
                programme: "$certificates.program.name",
                periodStart: "$certificates.periodStart",
                periodEnd: "$certificates.periodEnd",
                coveredSessions: { $size: "$certificates.coveredSessions" },
                // The Salus rule gives two training hours for each session.
                creditedHours: {
                    $multiply: [{ $size: "$certificates.coveredSessions" }, 2]
                }
            }
        },
        { $sort: { participant: 1, certificateId: 1 } }
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

// Q11. CREATE - insert a temporary document satisfying the collection validator.
const demoId = 999999;
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
    assignedHomeopaths: [],
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
                type: "Follow-up",
                notes: "Temporary CRUD demonstration consultation.",
                homeopath: null,
                symptoms: [{ name: "Demo symptom", description: "Temporary" }],
                prescription: { decision: "WAIT", medication: null }
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