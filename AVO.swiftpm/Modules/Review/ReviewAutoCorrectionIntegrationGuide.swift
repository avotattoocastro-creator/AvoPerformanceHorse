import Foundation

// MARK: - REVIEW PHASE 113 INTEGRATION GUIDE
//
// Add to your REVIEW page:
//
// @StateObject private var correctionLearning = ReviewAutoCorrectionLearningEngine()
//
// Buttons:
// 1. AUTOPOSE:
//    - run existing AutoPose
//    - store predicted points temporarily
//
// 2. GUARDAR CORRECCIÓN:
//    correctionLearning.learn(
//        predicted: predictedPoints,
//        corrected: correctedManualPoints,
//        horseBoxWidth: horseBox.width,
//        horseBoxHeight: horseBox.height,
//        viewTag: "lateral",
//        modelName: currentModelName
//    )
//
// 3. AUTO CORREGIR:
//    let results = correctionLearning.autoCorrect(
//        points: currentPredictedPoints,
//        horseBoxWidth: horseBox.width,
//        horseBoxHeight: horseBox.height,
//        viewTag: "lateral"
//    )
//
//    Then apply result.correctedX / result.correctedY to current points.
//
// 4. EXPORT REENTRENO:
//    let json = try correctionLearning.exportLearningJSONData()
//    let csv = correctionLearning.exportTrainingCorrectionCSV()
//
// Important:
// - This is local adaptive correction.
// - It does not replace full CoreML retraining.
// - It makes the app improve immediately from your manual corrections.
// - Full re-training still uses Colab/Mac + imported .mlpackage.

public enum ReviewAutoCorrectionIntegrationGuide {
    public static let phase = "113"
    public static let feature = "AutoPose manual correction learning loop"
}
