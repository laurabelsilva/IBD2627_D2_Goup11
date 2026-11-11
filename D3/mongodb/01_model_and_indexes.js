/*
 *
 * PostgreSQL remains the main transactional source. These collections are
 * document-oriented read models for clinical case files and participant
 * training dashboards.
 */

// `db` is the database selected in the mongosh connection URI. This keeps the
// script compatible with the optional MONGO_DB setting in the migration script.
const salus = db;

// The migration is repeatable: remove only the D3 collections before import.
salus.patient_case_files.drop();
salus.participant_training_profiles.drop();
/*
one patient
  ├── personal details
  ├── assigned homeopaths[]
  └── consultations[]
        ├── symptoms[]
        └── prescription + medication
*/
// One document represents the complete clinical history of one patient.
salus.createCollection("patient_case_files", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["patient", "assignedHomeopaths", "consultations"],
            properties: {
                patient: {
                    // Patient details are stored as a nested document.
                    bsonType: "object",
                    required: ["patientId", "name", "email"]
                },
                assignedHomeopaths: { bsonType: "array" },
                consultations: { bsonType: "array" }
            }
        }
    },
    // Reject documents that do not satisfy the required document shape.
    validationLevel: "strict",
    validationAction: "error"
});

// One document represents the training dashboard of one participant.
salus.createCollection("participant_training_profiles", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["participant", "purchases", "certificates"],
            properties: {
                participant: {
                    bsonType: "object",
                    required: ["participantId", "name", "studentNumber"]
                },
                purchases: { bsonType: "array" },
                certificates: { bsonType: "array" }
            }
        }
    },
    validationLevel: "strict",
    validationAction: "error"
});

// These indexes support the fields used for common patient searches.
salus.patient_case_files.createIndex({ "patient.email": 1 }, { unique: true });
salus.patient_case_files.createIndex({ "consultations.date": -1 });
salus.patient_case_files.createIndex({ "consultations.symptoms.name": 1 });
salus.patient_case_files.createIndex({ "assignedHomeopaths.homeopathId": 1 });

salus.participant_training_profiles.createIndex(
    { "participant.email": 1 },
    { unique: true }
);
// These indexes support payment, programme, and certificate dashboard filters.
salus.participant_training_profiles.createIndex({ "purchases.paid": 1 });
salus.participant_training_profiles.createIndex({ "purchases.program.programId": 1 });
salus.participant_training_profiles.createIndex({ "certificates.program.programId": 1 });

print("Created salus_d3 collections, validators, and indexes.");
