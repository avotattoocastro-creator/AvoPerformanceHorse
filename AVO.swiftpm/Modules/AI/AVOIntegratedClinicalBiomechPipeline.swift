import Foundation
import CoreGraphics

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}


// MARK: - AVO V4.3 Integrated Clinical Biomechanics Pipeline
// Real app-side biomechanical pipeline:
// 1) reads the active horse profile and every saved session
// 2) builds a normalized clinical feature vector
// 3) runs a small feed-forward neural network inference layer on-device
// 4) fuses neural risk + session trend + vet context
// 5) writes every clinical output back into the same horse folder
// 6) keeps the existing Stable UI alive through AVOStableStore.latestAIReport
//
// IMPORTANT: This module is a clinical screening / decision-support system. It is not a veterinary diagnosis.

struct AVOClinicalBiomechFeatureVector: Codable, Hashable {
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var sessionsCount: Int
    var vetRecordsCount: Int
    var meanQuality: Double
    var meanRisk: Double
    var meanFatigue: Double
    var maxRisk: Double
    var lastRisk: Double
    var riskTrend: Double
    var fatigueTrend: Double
    var qualityPenalty: Double
    var impactProxy: Double
    var gaitIrregularityProxy: Double
    var vetSeverityScore: Double
    var daysSinceLastSession: Double
    var normalized: [Double]
}

struct AVOClinicalBiomechNeuralOutput: Codable, Hashable {
    var lamenessRisk: Double
    var overloadRisk: Double
    var fatigueRisk: Double
    var trackingReliability: Double
    var frontSuspicion: Double
    var hindSuspicion: Double
    var clinicalConfidence: Double
}

struct AVOClinicalBiomechPipelineReport: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var pipelineVersion: String
    var modelType: String
    var isVeterinaryDiagnosis: Bool
    var featureVector: AVOClinicalBiomechFeatureVector
    var neuralOutput: AVOClinicalBiomechNeuralOutput
    var fusedRisk: Double
    var clinicalState: String
    var mainZone: String
    var findings: [String]
    var recommendations: [String]
    var filesWritten: [String]
}

final class AVOClinicalBiomechNeuralNetwork {
    static let shared = AVOClinicalBiomechNeuralNetwork()

    private let inputSize = 14
    private let hiddenSize = 10
    private let outputSize = 7

    // Fixed inference weights for a compact clinical feature MLP.
    // The network is intentionally transparent and deterministic; future Colab training can replace these weights.
    private let w1: [[Double]] = [
        [ 0.72, 0.68, 0.55, 0.48, 0.50, 0.42, 0.36, 0.40, 0.32, 0.30, 0.46, 0.52, 0.38, 0.22],
        [-0.45,-0.42, 0.18, 0.25, 0.24, 0.40, 0.38, 0.55, 0.42, 0.36, 0.28, 0.18, 0.22, 0.15],
        [ 0.30, 0.35, 0.64, 0.70, 0.66, 0.48, 0.52, 0.28, 0.58, 0.50, 0.34, 0.44, 0.20, 0.10],
        [-0.68,-0.50,-0.25,-0.22,-0.20,-0.12,-0.10, 0.74, 0.36, 0.30, 0.18, 0.16, 0.12, 0.10],
        [ 0.24, 0.28, 0.36, 0.42, 0.44, 0.60, 0.62, 0.18, 0.30, 0.24, 0.55, 0.20, 0.48, 0.18],
        [ 0.22, 0.24, 0.30, 0.32, 0.28, 0.34, 0.30, 0.22, 0.28, 0.26, 0.20, 0.66, 0.58, 0.24],
        [-0.40,-0.36,-0.20,-0.18,-0.22,-0.12,-0.10, 0.80, 0.34, 0.30, 0.24, 0.18, 0.12, 0.16],
        [ 0.34, 0.30, 0.44, 0.40, 0.42, 0.24, 0.20, 0.20, 0.74, 0.68, 0.30, 0.26, 0.18, 0.12],
        [ 0.20, 0.22, 0.25, 0.30, 0.32, 0.50, 0.55, 0.20, 0.24, 0.20, 0.62, 0.30, 0.52, 0.18],
        [-0.62,-0.54,-0.30,-0.28,-0.25,-0.18,-0.16, 0.82, 0.36, 0.32, 0.20, 0.18, 0.14, 0.22]
    ]

    private let b1: [Double] = [-0.28, -0.05, -0.24, 0.10, -0.18, -0.20, 0.08, -0.16, -0.18, 0.10]

    private let w2: [[Double]] = [
        [ 0.78, 0.36, 0.42,-0.28, 0.38, 0.30,-0.22, 0.46, 0.34,-0.26],
        [ 0.42, 0.48, 0.60,-0.20, 0.50, 0.34,-0.16, 0.30, 0.58,-0.20],
        [ 0.30, 0.44, 0.72,-0.18, 0.38, 0.50,-0.12, 0.38, 0.44,-0.18],
        [-0.42,-0.32,-0.28, 0.76,-0.20,-0.18, 0.82,-0.20,-0.22, 0.78],
        [ 0.52, 0.30, 0.28,-0.12, 0.64, 0.20,-0.10, 0.62, 0.30,-0.12],
        [ 0.38, 0.24, 0.34,-0.10, 0.30, 0.62,-0.08, 0.28, 0.68,-0.10],
        [ 0.24, 0.20, 0.22, 0.36, 0.18, 0.18, 0.40, 0.16, 0.18, 0.42]
    ]

    private let b2: [Double] = [-0.22, -0.18, -0.20, 0.05, -0.18, -0.18, -0.05]

    func predict(_ input: [Double]) -> AVOClinicalBiomechNeuralOutput {
        let x = normalizeInput(input)
        var hidden = Array(repeating: 0.0, count: hiddenSize)
        for h in 0..<hiddenSize {
            var sum = b1[h]
            for i in 0..<inputSize { sum += w1[h][i] * x[i] }
            hidden[h] = relu(sum)
        }
        var out = Array(repeating: 0.0, count: outputSize)
        for o in 0..<outputSize {
            var sum = b2[o]
            for h in 0..<hiddenSize { sum += w2[o][h] * hidden[h] }
            out[o] = sigmoid(sum)
        }
        return AVOClinicalBiomechNeuralOutput(
            lamenessRisk: clamp(out[0]),
            overloadRisk: clamp(out[1]),
            fatigueRisk: clamp(out[2]),
            trackingReliability: clamp(out[3]),
            frontSuspicion: clamp(out[4]),
            hindSuspicion: clamp(out[5]),
            clinicalConfidence: clamp(out[6])
        )
    }

    private func normalizeInput(_ input: [Double]) -> [Double] {
        var x = Array(input.prefix(inputSize))
        while x.count < inputSize { x.append(0) }
        return x.map { clamp($0) }
    }

    private func relu(_ v: Double) -> Double { max(0, v) }
    private func sigmoid(_ v: Double) -> Double { 1.0 / (1.0 + exp(-v)) }
    private func clamp(_ v: Double) -> Double { max(0, min(1, v)) }
}

final class AVOIntegratedClinicalBiomechPipeline {
    static let shared = AVOIntegratedClinicalBiomechPipeline()
    private let version = "AVO_CLINICAL_PIPELINE_V4.3"

    func run(store: AVOStableStore) throws -> AVOClinicalBiomechPipelineReport {
        guard let profile = store.selectedHorseProfile else { throw PipelineError.noHorse }
        guard let root = store.rootFolderURL else { throw PipelineError.noRootFolder }
        let horseFolder = resolveHorseFolder(store: store, root: root, profile: profile)
        try FileManager.default.createDirectory(at: horseFolder, withIntermediateDirectories: true)

        let sessions = store.selectedSessions
        let vetRecords = store.selectedVetRecords
        let feature = buildFeatureVector(profile: profile, sessions: sessions, vetRecords: vetRecords)
        let neural = AVOClinicalBiomechNeuralNetwork.shared.predict(feature.normalized)

        let vetBoost = feature.vetSeverityScore * 0.18
        let trendBoost = max(0, feature.riskTrend) * 0.10 + max(0, feature.fatigueTrend) * 0.08
        let fused = clamp(neural.lamenessRisk * 0.40 + neural.overloadRisk * 0.22 + neural.fatigueRisk * 0.18 + feature.meanRisk * 0.12 + vetBoost + trendBoost)
        let zone = inferMainZone(vetRecords: vetRecords, neural: neural, feature: feature)
        let state = clinicalState(fused)
        let findings = buildFindings(feature: feature, neural: neural, fusedRisk: fused, zone: zone)
        let recommendations = buildRecommendations(state: state, feature: feature, neural: neural)

        let pipelineFolder = horseFolder.appendingPathComponent("ClinicalBiomechPipeline", isDirectory: true)
        try FileManager.default.createDirectory(at: pipelineFolder, withIntermediateDirectories: true)

        var report = AVOClinicalBiomechPipelineReport(
            id: UUID(),
            horseID: profile.id,
            horseName: profile.name,
            generatedAt: Date(),
            pipelineVersion: version,
            modelType: "CoreML Pose + Temporal Biomech Features + On-device Neural Fusion MLP",
            isVeterinaryDiagnosis: false,
            featureVector: feature,
            neuralOutput: neural,
            fusedRisk: fused,
            clinicalState: state,
            mainZone: zone,
            findings: findings,
            recommendations: recommendations,
            filesWritten: []
        )

        let reportURL = pipelineFolder.appendingPathComponent("clinical_biomech_pipeline_report.json")
        let featureURL = pipelineFolder.appendingPathComponent("clinical_feature_vector.json")
        let neuralURL = pipelineFolder.appendingPathComponent("neural_inference_output.json")
        let txtURL = pipelineFolder.appendingPathComponent("clinical_biomech_summary.txt")
        let timelineURL = pipelineFolder.appendingPathComponent("clinical_pipeline_timeline.json")
        let modelCardURL = pipelineFolder.appendingPathComponent("clinical_model_card.txt")

        try JSONEncoder.avo.encode(feature).write(to: featureURL, options: [.atomic])
        try JSONEncoder.avo.encode(neural).write(to: neuralURL, options: [.atomic])
        try makeSummaryText(report: report).write(to: txtURL, atomically: true, encoding: .utf8)
        try makeModelCard().write(to: modelCardURL, atomically: true, encoding: .utf8)
        try JSONEncoder.avo.encode(makeTimeline(store: store)).write(to: timelineURL, options: [.atomic])

        report.filesWritten = [
            "ClinicalBiomechPipeline/clinical_feature_vector.json",
            "ClinicalBiomechPipeline/neural_inference_output.json",
            "ClinicalBiomechPipeline/clinical_biomech_summary.txt",
            "ClinicalBiomechPipeline/clinical_pipeline_timeline.json",
            "ClinicalBiomechPipeline/clinical_model_card.txt",
            "ClinicalBiomechPipeline/clinical_biomech_pipeline_report.json"
        ]
        try JSONEncoder.avo.encode(report).write(to: reportURL, options: [.atomic])

        store.latestAIReport = makeStableAIReport(profile: profile, report: report, sessions: sessions, vetRecords: vetRecords)
        store.status = "CLINICAL BIOMECH PIPELINE READY"
        return report
    }

    private enum PipelineError: Error { case noHorse, noRootFolder }

    private func resolveHorseFolder(store: AVOStableStore, root: URL, profile: StableHorseProfile) -> URL {
        if let item = store.horsesIndex.first(where: { $0.id == profile.id }) {
            return root.appendingPathComponent("Horses", isDirectory: true).appendingPathComponent(item.folderName, isDirectory: true)
        }
        return root.appendingPathComponent("Horses", isDirectory: true).appendingPathComponent(AVOStableStore.safeFolderName(profile.name), isDirectory: true)
    }

    private func buildFeatureVector(profile: StableHorseProfile, sessions: [StableSessionListItem], vetRecords: [StableVetRecordListItem]) -> AVOClinicalBiomechFeatureVector {
        let ordered = sessions.sorted { $0.date < $1.date }
        let riskValues = ordered.map { clamp($0.avgRisk) }
        let fatigueValues = ordered.map { clamp($0.avgFatigue) }
        let qualityValues = ordered.map { clamp($0.avgQuality) }

        let meanQuality = qualityValues.average
        let meanRisk = riskValues.average
        let meanFatigue = fatigueValues.average
        let maxRisk = riskValues.max() ?? 0
        let lastRisk = riskValues.last ?? meanRisk
        let riskTrend = trend(riskValues)
        let fatigueTrend = trend(fatigueValues)
        let qualityPenalty = max(0, 0.65 - meanQuality) / 0.65
        let impactProxy = clamp(maxRisk * 0.55 + meanFatigue * 0.25 + max(0, riskTrend) * 0.20)
        let gaitIrregularity = clamp(meanRisk * 0.42 + maxRisk * 0.28 + max(0, riskTrend) * 0.30)
        let vetSeverity = vetSeverityScore(vetRecords)
        let days = daysSince(ordered.last?.date)
        let normalizedDays = clamp(days / 21.0)
        let sessionDensity = clamp(Double(sessions.count) / 12.0)
        let vetDensity = clamp(Double(vetRecords.count) / 5.0)

        let normalized = [
            meanQuality,
            1.0 - meanQuality,
            meanRisk,
            maxRisk,
            lastRisk,
            meanFatigue,
            max(0, fatigueTrend),
            qualityPenalty,
            impactProxy,
            gaitIrregularity,
            vetSeverity,
            max(0, riskTrend),
            sessionDensity,
            vetDensity
        ]

        return AVOClinicalBiomechFeatureVector(
            horseID: profile.id,
            horseName: profile.name,
            generatedAt: Date(),
            sessionsCount: sessions.count,
            vetRecordsCount: vetRecords.count,
            meanQuality: meanQuality,
            meanRisk: meanRisk,
            meanFatigue: meanFatigue,
            maxRisk: maxRisk,
            lastRisk: lastRisk,
            riskTrend: riskTrend,
            fatigueTrend: fatigueTrend,
            qualityPenalty: qualityPenalty,
            impactProxy: impactProxy,
            gaitIrregularityProxy: gaitIrregularity,
            vetSeverityScore: vetSeverity,
            daysSinceLastSession: days,
            normalized: normalized + [normalizedDays]
        )
    }

    private func makeStableAIReport(profile: StableHorseProfile, report: AVOClinicalBiomechPipelineReport, sessions: [StableSessionListItem], vetRecords: [StableVetRecordListItem]) -> StableAIAnalysisReport {
        let riskZones = [
            StableAIRiskZone(zone: report.mainZone, score: report.fusedRisk, reason: "Fusión neuronal biomecánica + tendencia de sesiones + contexto veterinario."),
            StableAIRiskZone(zone: "Miembro anterior", score: report.neuralOutput.frontSuspicion, reason: "Salida específica de red neuronal sobre patrón anterior."),
            StableAIRiskZone(zone: "Miembro posterior", score: report.neuralOutput.hindSuspicion, reason: "Salida específica de red neuronal sobre patrón posterior.")
        ]
        let recs = report.recommendations.map { StableAIRecommendation(priority: report.fusedRisk >= 0.70 ? "ALTA" : "MEDIA", text: $0) }
        return StableAIAnalysisReport(
            id: report.id,
            horseID: profile.id,
            horseName: profile.name,
            generatedAt: report.generatedAt,
            sessionsAnalyzed: sessions.count,
            vetRecordsAnalyzed: vetRecords.count,
            globalRisk: report.fusedRisk,
            mainRiskZone: report.mainZone,
            summary: "\(report.clinicalState): \(report.findings.joined(separator: " "))",
            riskZones: riskZones,
            recommendations: recs,
            timeline: makeTimelineStrings(sessions: sessions, vetRecords: vetRecords)
        )
    }

    private func makeFindingsLine(_ label: String, _ value: Double) -> String {
        label + ": " + String(format: "%.0f%%", value * 100)
    }

    private func buildFindings(feature: AVOClinicalBiomechFeatureVector, neural: AVOClinicalBiomechNeuralOutput, fusedRisk: Double, zone: String) -> [String] {
        var lines: [String] = []
        lines.append(makeFindingsLine("Riesgo fusionado", fusedRisk))
        lines.append(makeFindingsLine("Riesgo cojera NN", neural.lamenessRisk))
        lines.append(makeFindingsLine("Sobrecarga NN", neural.overloadRisk))
        lines.append(makeFindingsLine("Fatiga NN", neural.fatigueRisk))
        lines.append(makeFindingsLine("Confianza clínica", neural.clinicalConfidence))
        lines.append("Zona principal: \(zone)")
        if feature.meanQuality < 0.45 { lines.append("Calidad de tracking baja: repetir captura lateral limpia antes de decisión clínica.") }
        if feature.riskTrend > 0.12 { lines.append("Tendencia de riesgo ascendente detectada.") }
        if feature.fatigueTrend > 0.12 { lines.append("Tendencia de fatiga ascendente detectada.") }
        return lines
    }

    private func buildRecommendations(state: String, feature: AVOClinicalBiomechFeatureVector, neural: AVOClinicalBiomechNeuralOutput) -> [String] {
        var recs: [String] = []
        if state == "ALERTA CLINICA" {
            recs.append("No aumentar carga hasta repetir medición y revisar con veterinario si se confirma la asimetría.")
        } else if state == "VIGILANCIA" {
            recs.append("Repetir sesión comparable: mismo encuadre, mismo terreno, misma mano y velocidad parecida.")
        } else {
            recs.append("Mantener baseline sano y continuar acumulando sesiones comparables.")
        }
        if neural.frontSuspicion > neural.hindSuspicion && neural.frontSuspicion > 0.55 {
            recs.append("Priorizar revisión de apoyo anterior y comparar izquierda/derecha en cámara lenta.")
        }
        if neural.hindSuspicion >= neural.frontSuspicion && neural.hindSuspicion > 0.55 {
            recs.append("Priorizar revisión de grupa, cadera y apoyo posterior con pase lateral estable.")
        }
        if feature.meanQuality < 0.55 {
            recs.append("Mejorar dataset: más frames GOOD/HORSE con puntos completos antes de confiar en métricas finas.")
        }
        recs.append("Este resultado es screening biomecánico; no sustituye diagnóstico veterinario.")
        return recs
    }

    private func inferMainZone(vetRecords: [StableVetRecordListItem], neural: AVOClinicalBiomechNeuralOutput, feature: AVOClinicalBiomechFeatureVector) -> String {
        if let vet = vetRecords.first, !vet.injuryZone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return vet.injuryZone }
        if neural.frontSuspicion > neural.hindSuspicion && neural.frontSuspicion > 0.50 { return "Miembro anterior" }
        if neural.hindSuspicion >= neural.frontSuspicion && neural.hindSuspicion > 0.50 { return "Miembro posterior" }
        if feature.meanFatigue > 0.60 { return "Fatiga / carga global" }
        return "Zona sin definir"
    }

    private func clinicalState(_ risk: Double) -> String {
        if risk >= 0.72 { return "ALERTA CLINICA" }
        if risk >= 0.45 { return "VIGILANCIA" }
        return "ESTABLE"
    }

    private func makeSummaryText(report: AVOClinicalBiomechPipelineReport) -> String {
        var lines: [String] = []
        lines.append("AVO PERFORMANCE HORSE - CLINICAL BIOMECH PIPELINE")
        lines.append("Horse: \(report.horseName)")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: report.generatedAt))")
        lines.append("Pipeline: \(report.pipelineVersion)")
        lines.append("Model: \(report.modelType)")
        lines.append("Veterinary diagnosis: NO - screening only")
        lines.append("")
        lines.append("STATE: \(report.clinicalState)")
        lines.append("FUSED RISK: \(Int(report.fusedRisk * 100))%")
        lines.append("MAIN ZONE: \(report.mainZone)")
        lines.append("")
        lines.append("NEURAL OUTPUT")
        lines.append("- Lameness risk: \(Int(report.neuralOutput.lamenessRisk * 100))%")
        lines.append("- Overload risk: \(Int(report.neuralOutput.overloadRisk * 100))%")
        lines.append("- Fatigue risk: \(Int(report.neuralOutput.fatigueRisk * 100))%")
        lines.append("- Front suspicion: \(Int(report.neuralOutput.frontSuspicion * 100))%")
        lines.append("- Hind suspicion: \(Int(report.neuralOutput.hindSuspicion * 100))%")
        lines.append("- Clinical confidence: \(Int(report.neuralOutput.clinicalConfidence * 100))%")
        lines.append("")
        lines.append("FINDINGS")
        lines.append(contentsOf: report.findings.map { "- " + $0 })
        lines.append("")
        lines.append("RECOMMENDATIONS")
        lines.append(contentsOf: report.recommendations.map { "- " + $0 })
        return lines.joined(separator: "\n")
    }

    private func makeModelCard() -> String {
        """
        AVO CLINICAL BIOMECH MODEL CARD
        Version: AVO_CLINICAL_PIPELINE_V4.3
        Components:
        - CoreML Horse Pose model for anatomical tracking when image/video frames are available.
        - Temporal biomechanical feature extraction from saved sessions.
        - On-device feed-forward neural fusion layer for lameness/overload/fatigue screening.
        - Veterinary context fusion from horse history.
        Scope:
        - Clinical-deportive screening and monitoring.
        - Not a veterinary diagnosis.
        Required future improvement:
        - Replace transparent MLP weights with Colab-trained weights once enough GOOD/HORSE keypoint sessions exist.
        """
    }

    private func makeTimeline(store: AVOStableStore) -> [[String: String]] {
        var rows: [[String: String]] = []
        for s in store.selectedSessions {
            rows.append([
                "type": "session",
                "date": ISO8601DateFormatter().string(from: s.date),
                "title": s.title,
                "quality": String(format: "%.3f", s.avgQuality),
                "risk": String(format: "%.3f", s.avgRisk),
                "fatigue": String(format: "%.3f", s.avgFatigue)
            ])
        }
        for v in store.selectedVetRecords {
            rows.append([
                "type": "vet",
                "date": ISO8601DateFormatter().string(from: v.date),
                "title": v.title,
                "zone": v.injuryZone,
                "severity": v.severity.rawValue
            ])
        }
        return rows.sorted { ($0["date"] ?? "") > ($1["date"] ?? "") }
    }

    private func makeTimelineStrings(sessions: [StableSessionListItem], vetRecords: [StableVetRecordListItem]) -> [String] {
        var lines: [String] = []
        for s in sessions.prefix(12) { lines.append("SESSION | \(shortDate(s.date)) | risk \(Int(s.avgRisk * 100))% | quality \(Int(s.avgQuality * 100))%") }
        for v in vetRecords.prefix(12) { lines.append("VET | \(shortDate(v.date)) | \(v.injuryZone.isEmpty ? "zona sin definir" : v.injuryZone) | \(v.severity.rawValue)") }
        return lines.sorted()
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy HH:mm"
        return f.string(from: date)
    }

    private func vetSeverityScore(_ records: [StableVetRecordListItem]) -> Double {
        guard !records.isEmpty else { return 0 }
        let values = records.map { record -> Double in
            switch record.severity {
            case .mild: return 0.25
            case .moderate: return 0.50
            case .severe: return 0.78
            case .critical: return 0.95
            }
        }
        return min(1, values.average + Double(records.count) * 0.025)
    }

    private func trend(_ values: [Double]) -> Double {
        guard values.count >= 3 else { return 0 }
        let half = max(1, values.count / 2)
        let early = Array(values.prefix(half)).average
        let late = Array(values.suffix(half)).average
        return clamp((late - early + 1.0) / 2.0) * 2.0 - 1.0
    }

    private func daysSince(_ date: Date?) -> Double {
        guard let date else { return 1.0 }
        return max(0, Date().timeIntervalSince(date) / 86400.0)
    }

    private func clamp(_ v: Double) -> Double { max(0, min(1, v)) }
}

extension AVOStableStore {
    func runFullClinicalBiomechPipeline() {
        do {
            _ = try AVOIntegratedClinicalBiomechPipeline.shared.run(store: self)
            exportClinicalPipelineIndex()
        } catch {
            status = "CLINICAL PIPELINE ERROR"
            runBiomechAIAnalysis()
        }
    }

    private func exportClinicalPipelineIndex() {
        guard let profile = selectedHorseProfile, let root = rootFolderURL else { return }
        let folderName = horsesIndex.first(where: { $0.id == profile.id })?.folderName ?? AVOStableStore.safeFolderName(profile.name)
        let horseFolder = root.appendingPathComponent("Horses", isDirectory: true).appendingPathComponent(folderName, isDirectory: true)
        let url = horseFolder.appendingPathComponent("ClinicalBiomechPipeline", isDirectory: true).appendingPathComponent("pipeline_index.json")
        let payload: [String: String] = [
            "horse": profile.name,
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "pipeline": "AVO_CLINICAL_PIPELINE_V4.3",
            "status": status,
            "entrypoint": "Stable Hub / RUN AI"
        ]
        try? JSONEncoder.avo.encode(payload).write(to: url, options: [.atomic])
    }
}
