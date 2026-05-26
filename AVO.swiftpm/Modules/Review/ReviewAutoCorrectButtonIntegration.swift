
import Foundation

// MARK: - REVIEW PHASE 114
// QUICK INTEGRATION EXAMPLE

/*
 ADD TO REVIEW VIEW:

 @StateObject private var learningEngine = ReviewAutoCorrectionLearningEngine()

 // Store last autopose prediction
 @State private var predictedPoints: [ReviewCorrectionPointInput] = []

 // Current editable points
 @State private var editablePoints: [ReviewCorrectionPointInput] = []

 // Horse box normalized size
 @State private var horseBoxWidth: Double = 1.0
 @State private var horseBoxHeight: Double = 1.0

 -----------------------------------------------------

 BUTTON: GUARDAR CORRECCIÓN

 Button("GUARDAR CORRECCIÓN") {

     learningEngine.learn(
         predicted: predictedPoints,
         corrected: editablePoints,
         horseBoxWidth: horseBoxWidth,
         horseBoxHeight: horseBoxHeight,
         viewTag: "lateral",
         modelName: "current_model"
     )
 }

 -----------------------------------------------------

 BUTTON: AUTO CORREGIR

 ReviewAutoCorrectButton(
     learningEngine: learningEngine,
     currentPoints: editablePoints,
     horseBoxWidth: horseBoxWidth,
     horseBoxHeight: horseBoxHeight,
     viewTag: "lateral"
 ) { results in

     editablePoints = results.map {
         ReviewCorrectionPointInput(
             jointName: $0.jointName,
             x: $0.correctedX,
             y: $0.correctedY,
             confidence: $0.confidence
         )
     }
 }

 -----------------------------------------------------

 WORKFLOW:

 1. AUTOPOSE
 2. Corregir manualmente
 3. GUARDAR CORRECCIÓN
 4. Siguiente imagen
 5. AUTO CORREGIR
 6. La app aplica offsets aprendidos automáticamente

*/
