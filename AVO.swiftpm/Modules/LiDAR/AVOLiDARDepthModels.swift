import Foundation

struct AVOLiDARDepthSample: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Double
    var distanceMeters: Double
    var quality: Double
    var width: Int
    var height: Int
    var source: String
}


struct AVOLiDARPoint2D: Codable, Identifiable, Hashable {
    var id = UUID()
    var x: Double      // 0...1 horizontal position in depth map
    var y: Double      // 0...1 vertical position in depth map
    var z: Double      // meters
    var confidence: Double
}
