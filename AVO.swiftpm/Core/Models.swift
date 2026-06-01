import SwiftUI
import CoreLocation

struct SessionSample: Codable {
    let time: Double
    let quality: Double
    let risk: Double
    let fatigue: Double
    let latitude: Double
    let longitude: Double
    let gait: String
    let score: String
    let pulse: String
    let speed: String
    let rssi: String
}

struct IMUBatchSample: Codable, Identifiable {
    var id = UUID()
    let dt: Double
    let pitch: Double
    let roll: Double
    let impact: Double
}

struct BiomechFrame {
    let time: Date
    let horseBox: CGRect
    let riderBox: CGRect
    let quality: Double
    let risk: Double
    let fatigue: Double
    let latitude: Double
    let longitude: Double
}

struct HorseProfile: Codable {
    var name: String
    var age: Int
    var breed: String
    var notes: String
}

struct RiderProfile: Codable {
    var name: String
    var level: String
    var weight: Double
    var notes: String
}

enum DashboardMode: String, CaseIterable {
    case live = "LIVE"
    case biomech = "BIOMECH"
    case replay = "REPLAY"
    case videoEditor = "VIDEO"
    case analysis = "ANALYSIS"
    case profiles = "PROFILES"
    case stable = "STABLE"
    case sensors = "SENSORS"
    case report = "REPORT"
    case settings = "SETTINGS"
    case hardware = "HARDWARE"
    case devices = "DEVICES"
    case review = "REVIEW"
    case aiTraining = "AI TRAIN"
    case configHub = "SERVER"
}

enum CommercialMode: String, CaseIterable {
    case simple = "SIMPLE"
    case expert = "EXPERT"
    case veterinary = "VET"
}

struct TrainingZonePoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TrainingZone: Codable {
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var polygon: [TrainingZonePoint]

    init(name: String, latitude: Double, longitude: Double, radiusMeters: Double, polygon: [TrainingZonePoint] = []) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.polygon = polygon
    }

    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, radiusMeters, polygon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        radiusMeters = try container.decode(Double.self, forKey: .radiusMeters)
        polygon = try container.decodeIfPresent([TrainingZonePoint].self, forKey: .polygon) ?? []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var polygonCoordinates: [CLLocationCoordinate2D] {
        polygon.map { $0.coordinate }
    }

    var isFreeDrawZone: Bool {
        polygon.count >= 3
    }
}


// MARK: - Real Horse Anatomy Model Slots
// These structures are intentionally empty until a real CoreML horse pose model is connected.
// Phase 1 rule: no synthetic anatomy is generated or drawn.

enum HorseJoint: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }

    case nose
    case poll
    case neckBase
    case withers
    case back
    case croup
    case tailBase

    case leftShoulder
    case leftElbow
    case leftCarpus
    case leftFetlock
    case leftHoof

    case rightShoulder
    case rightElbow
    case rightCarpus
    case rightFetlock
    case rightHoof

    case leftHip
    case leftStifle
    case leftHock
    case leftHindFetlock
    case leftHindHoof

    case rightHip
    case rightStifle
    case rightHock
    case rightHindFetlock
    case rightHindHoof
}

struct HorseKeypoint: Identifiable, Codable, Hashable {
    var id: HorseJoint { joint }
    let joint: HorseJoint
    let x: Double
    let y: Double
    let confidence: Double
}

struct HorseDetection: Codable, Hashable {
    let boxX: Double
    let boxY: Double
    let boxW: Double
    let boxH: Double
    let confidence: Double
    let source: String
}

struct HorseSkeletonEdge: Identifiable, Hashable {
    var id: String { "\(from.rawValue)-\(to.rawValue)" }
    let from: HorseJoint
    let to: HorseJoint
}

extension HorseJoint {
    static let skeletonEdges: [HorseSkeletonEdge] = [
        HorseSkeletonEdge(from: .nose, to: .poll),
        HorseSkeletonEdge(from: .poll, to: .neckBase),
        HorseSkeletonEdge(from: .neckBase, to: .withers),
        HorseSkeletonEdge(from: .withers, to: .back),
        HorseSkeletonEdge(from: .back, to: .croup),
        HorseSkeletonEdge(from: .croup, to: .tailBase),

        HorseSkeletonEdge(from: .withers, to: .leftShoulder),
        HorseSkeletonEdge(from: .leftShoulder, to: .leftElbow),
        HorseSkeletonEdge(from: .leftElbow, to: .leftCarpus),
        HorseSkeletonEdge(from: .leftCarpus, to: .leftFetlock),
        HorseSkeletonEdge(from: .leftFetlock, to: .leftHoof),

        HorseSkeletonEdge(from: .withers, to: .rightShoulder),
        HorseSkeletonEdge(from: .rightShoulder, to: .rightElbow),
        HorseSkeletonEdge(from: .rightElbow, to: .rightCarpus),
        HorseSkeletonEdge(from: .rightCarpus, to: .rightFetlock),
        HorseSkeletonEdge(from: .rightFetlock, to: .rightHoof),

        HorseSkeletonEdge(from: .croup, to: .leftHip),
        HorseSkeletonEdge(from: .leftHip, to: .leftStifle),
        HorseSkeletonEdge(from: .leftStifle, to: .leftHock),
        HorseSkeletonEdge(from: .leftHock, to: .leftHindFetlock),
        HorseSkeletonEdge(from: .leftHindFetlock, to: .leftHindHoof),

        HorseSkeletonEdge(from: .croup, to: .rightHip),
        HorseSkeletonEdge(from: .rightHip, to: .rightStifle),
        HorseSkeletonEdge(from: .rightStifle, to: .rightHock),
        HorseSkeletonEdge(from: .rightHock, to: .rightHindFetlock),
        HorseSkeletonEdge(from: .rightHindFetlock, to: .rightHindHoof)
    ]
}

// MARK: - Spanish labels for manual annotation UI
extension HorseJoint {
    var spanishName: String {
        switch self {
        case .nose: return "Morro / nariz"
        case .poll: return "Nuca"
        case .neckBase: return "Base del cuello"
        case .withers: return "Cruz"
        case .back: return "Dorso"
        case .croup: return "Grupa"
        case .tailBase: return "Base de la cola"
        case .leftShoulder: return "Hombro izquierdo"
        case .leftElbow: return "Codo izquierdo"
        case .leftCarpus: return "Rodilla delantera izq."
        case .leftFetlock: return "Menudillo delantero izq."
        case .leftHoof: return "Casco delantero izq."
        case .rightShoulder: return "Hombro derecho"
        case .rightElbow: return "Codo derecho"
        case .rightCarpus: return "Rodilla delantera der."
        case .rightFetlock: return "Menudillo delantero der."
        case .rightHoof: return "Casco delantero der."
        case .leftHip: return "Cadera izquierda"
        case .leftStifle: return "Babilla izquierda"
        case .leftHock: return "Corvejón izquierdo"
        case .leftHindFetlock: return "Menudillo trasero izq."
        case .leftHindHoof: return "Casco trasero izq."
        case .rightHip: return "Cadera derecha"
        case .rightStifle: return "Babilla derecha"
        case .rightHock: return "Corvejón derecho"
        case .rightHindFetlock: return "Menudillo trasero der."
        case .rightHindHoof: return "Casco trasero der."
        }
    }

    var spanishShort: String {
        switch self {
        case .nose: return "MOR"
        case .poll: return "NUC"
        case .neckBase: return "BCU"
        case .withers: return "CRZ"
        case .back: return "DOR"
        case .croup: return "GRU"
        case .tailBase: return "COL"
        case .leftShoulder: return "H-I"
        case .leftElbow: return "C-I"
        case .leftCarpus: return "RDI"
        case .leftFetlock: return "MDI"
        case .leftHoof: return "CDI"
        case .rightShoulder: return "H-D"
        case .rightElbow: return "C-D"
        case .rightCarpus: return "RDD"
        case .rightFetlock: return "MDD"
        case .rightHoof: return "CDD"
        case .leftHip: return "CAI"
        case .leftStifle: return "BAI"
        case .leftHock: return "COI"
        case .leftHindFetlock: return "MTI"
        case .leftHindHoof: return "CTI"
        case .rightHip: return "CAD"
        case .rightStifle: return "BAD"
        case .rightHock: return "COD"
        case .rightHindFetlock: return "MTD"
        case .rightHindHoof: return "CTD"
        }
    }
}
