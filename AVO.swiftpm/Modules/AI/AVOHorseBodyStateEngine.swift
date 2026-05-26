
import Foundation
import CoreGraphics

enum AVOHorseBodyOrientation: String, Codable {
    case leftSide = "LEFT SIDE"
    case rightSide = "RIGHT SIDE"
    case frontRear = "FRONT/REAR"
    case threeQuarter = "3/4"
    case unknown = "UNKNOWN"
}

enum AVOJointHealth: String, Codable {
    case solid = "SOLID"
    case predicted = "PREDICTED"
    case weak = "WEAK"
    case lost = "LOST"
}

struct AVOTrackedJointState: Identifiable, Hashable {
    var id: HorseJoint { joint }
    let joint: HorseJoint
    let x: Double
    let y: Double
    let confidence: Double
    let velocityX: Double
    let velocityY: Double
    let accelerationX: Double
    let accelerationY: Double
    let missedFrames: Int
    let health: AVOJointHealth
}

struct AVOTrackedHorseBodyState {
    let joints: [AVOTrackedJointState]
    let orientation: AVOHorseBodyOrientation
    let bodyLength: Double
    let bodyHeight: Double
    let temporalConfidence: Double
    let persistentScore: Double
    let gaitPhaseHint: String
    let heatmapSummary: String
    let eliteFrameRank: String
}

final class AVOHorseBodyStateEngine {
    private var previous: [HorseJoint: AVOTrackedJointState] = [:]
    private var phaseCounter: Int = 0

    func reset() {
        previous.removeAll()
        phaseCounter = 0
    }

    func update(tracked: [TrackedHorseJoint], gateScore: Double) -> AVOTrackedHorseBodyState {
        phaseCounter += 1

        var states: [AVOTrackedJointState] = []
        let prev = previous

        for point in tracked {
            let old = prev[point.joint]
            let vx = point.velocityX
            let vy = point.velocityY
            let ax = vx - (old?.velocityX ?? 0)
            let ay = vy - (old?.velocityY ?? 0)

            let health: AVOJointHealth
            if point.missedFrames > 5 {
                health = .lost
            } else if point.isPredicted {
                health = .predicted
            } else if point.confidence < 0.35 {
                health = .weak
            } else {
                health = .solid
            }

            states.append(
                AVOTrackedJointState(
                    joint: point.joint,
                    x: point.x,
                    y: point.y,
                    confidence: point.confidence,
                    velocityX: vx,
                    velocityY: vy,
                    accelerationX: ax,
                    accelerationY: ay,
                    missedFrames: point.missedFrames,
                    health: health
                )
            )
        }

        previous = Dictionary(uniqueKeysWithValues: states.map { ($0.joint, $0) })

        let body = bodyDimensions(states)
        let orientation = inferOrientation(states, bodyLength: body.length, bodyHeight: body.height)
        let temporalConfidence = temporalConfidence(states)
        let persistentScore = min(1, max(0, gateScore * 0.58 + temporalConfidence * 0.42))
        let phase = inferGaitPhase(states)
        let heatmap = heatmapSummary(states)
        let rank = frameRank(score: persistentScore, states: states)

        return AVOTrackedHorseBodyState(
            joints: states,
            orientation: orientation,
            bodyLength: body.length,
            bodyHeight: body.height,
            temporalConfidence: temporalConfidence,
            persistentScore: persistentScore,
            gaitPhaseHint: phase,
            heatmapSummary: heatmap,
            eliteFrameRank: rank
        )
    }

    private func bodyDimensions(_ states: [AVOTrackedJointState]) -> (length: Double, height: Double) {
        guard !states.isEmpty else { return (0, 0) }
        let xs = states.map { $0.x }
        let ys = states.map { $0.y }
        let length = (xs.max() ?? 0) - (xs.min() ?? 0)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        return (max(0, length), max(0, height))
    }

    private func inferOrientation(_ states: [AVOTrackedJointState], bodyLength: Double, bodyHeight: Double) -> AVOHorseBodyOrientation {
        guard states.count >= 6 else { return .unknown }

        let map = Dictionary(uniqueKeysWithValues: states.map { ($0.joint, $0) })
        let sideRatio = bodyHeight > 0.0001 ? bodyLength / bodyHeight : 0

        if sideRatio < 1.15 { return .frontRear }
        if sideRatio < 1.65 { return .threeQuarter }

        if let nose = map[.nose], let tail = map[.tailBase] ?? map[.croup] {
            return nose.x < tail.x ? .leftSide : .rightSide
        }

        return .unknown
    }

    private func temporalConfidence(_ states: [AVOTrackedJointState]) -> Double {
        guard !states.isEmpty else { return 0 }
        let healthScore = states.map { state -> Double in
            switch state.health {
            case .solid: return 1.0
            case .weak: return 0.58
            case .predicted: return 0.36
            case .lost: return 0.12
            }
        }.reduce(0, +) / Double(states.count)

        let confidence = states.map { $0.confidence }.reduce(0, +) / Double(states.count)
        return max(0, min(1, healthScore * 0.62 + confidence * 0.38))
    }

    private func inferGaitPhase(_ states: [AVOTrackedJointState]) -> String {
        let map = Dictionary(uniqueKeysWithValues: states.map { ($0.joint, $0) })
        let frontMotion = abs(map[.leftHoof]?.velocityY ?? 0) + abs(map[.rightHoof]?.velocityY ?? 0)
        let hindMotion = abs(map[.leftHindHoof]?.velocityY ?? 0) + abs(map[.rightHindHoof]?.velocityY ?? 0)
        let total = frontMotion + hindMotion

        if total < 0.002 { return "STANCE / STATIC" }
        if total < 0.008 { return "WALK PHASE" }
        if total < 0.018 { return "TROT PHASE" }
        return "FAST GAIT PHASE"
    }

    private func heatmapSummary(_ states: [AVOTrackedJointState]) -> String {
        let solid = states.filter { $0.health == .solid }.count
        let predicted = states.filter { $0.health == .predicted }.count
        let weak = states.filter { $0.health == .weak }.count
        let lost = states.filter { $0.health == .lost }.count
        return "S \(solid) / P \(predicted) / W \(weak) / L \(lost)"
    }

    private func frameRank(score: Double, states: [AVOTrackedJointState]) -> String {
        if score >= 0.82 && states.count >= 18 { return "ELITE" }
        if score >= 0.68 && states.count >= 13 { return "GOOD" }
        if score >= 0.52 && states.count >= 8 { return "USABLE" }
        if score >= 0.35 { return "LOW" }
        return "REJECTED"
    }
}
