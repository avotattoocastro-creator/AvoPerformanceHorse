import Foundation
import SwiftUI
import UIKit
import AVFoundation

// MARK: - BIOTECH PHASE 117
// DATA STREAM TO REVIEW TRAINING
//
// Purpose:
// BIOTECH has the real camera/live overlay.
// REVIEW is the IA/dataset/retraining lab.
// When DATA is ON in BIOTECH, frames are pushed into a training buffer
// for REVIEW.
//
// Important:
// 120fps is a target capture mode. Real iPad camera/device support decides
// the actual FPS. This engine stores metadata with requestedFPS and measured flow.

public struct BiotechTrainingFramePacket: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var frameIndex: Int
    public var timestamp: Date
    public var timeSeconds: Double
    public var requestedFPS: Int
    public var source: String
    public var width: Int
    public var height: Int
    public var qualityTag: String

    public init(frameIndex: Int,
                timestamp: Date = Date(),
                timeSeconds: Double,
                requestedFPS: Int,
                source: String,
                width: Int,
                height: Int,
                qualityTag: String = "raw") {
        self.frameIndex = frameIndex
        self.timestamp = timestamp
        self.timeSeconds = timeSeconds
        self.requestedFPS = requestedFPS
        self.source = source
        self.width = width
        self.height = height
        self.qualityTag = qualityTag
    }
}

public struct BiotechTrainingImageSample: Identifiable {
    public var id = UUID()
    public var packet: BiotechTrainingFramePacket
    public var image: UIImage?

    public init(packet: BiotechTrainingFramePacket, image: UIImage? = nil) {
        self.packet = packet
        self.image = image
    }
}

public final class BiotechDataToReviewBridge: ObservableObject {

    public static let shared = BiotechDataToReviewBridge()

    @Published public private(set) var isDataOn: Bool = false
    @Published public private(set) var requestedFPS: Int = 120
    @Published public private(set) var capturedCount: Int = 0
    @Published public private(set) var droppedCount: Int = 0
    @Published public private(set) var buffer: [BiotechTrainingImageSample] = []
    @Published public private(set) var status: String = "DATA OFF"
    @Published public private(set) var lastFrameAt: Date?

    public var maxBufferFrames: Int = 720
    public var keepUIImageInMemory: Bool = false

    private var frameIndex: Int = 0
    private var lastAcceptedTime: TimeInterval = 0

    private init() {}

    public func setDataOn(_ on: Bool, requestedFPS: Int = 120) {
        self.requestedFPS = requestedFPS
        isDataOn = on

        if on {
            status = "DATA ON · REVIEW TRAINING \(requestedFPS)FPS"
        } else {
            status = "DATA OFF · BUFFER \(buffer.count)"
        }
    }

    public func toggleData(requestedFPS: Int = 120) {
        setDataOn(!isDataOn, requestedFPS: requestedFPS)
    }

    public func clearBuffer() {
        buffer.removeAll()
        capturedCount = 0
        droppedCount = 0
        frameIndex = 0
        lastAcceptedTime = 0
        status = isDataOn ? "DATA ON · BUFFER CLEARED" : "DATA OFF · BUFFER CLEARED"
    }

    public func acceptFrame(image: UIImage?,
                            source: String = "biotech-camera",
                            timeSeconds: Double = CACurrentMediaTime(),
                            width: Int = 0,
                            height: Int = 0,
                            qualityTag: String = "raw") {
        guard isDataOn else { return }

        let now = CACurrentMediaTime()
        let minInterval = 1.0 / Double(max(1, requestedFPS))

        if lastAcceptedTime > 0 && now - lastAcceptedTime < minInterval {
            droppedCount += 1
            return
        }

        lastAcceptedTime = now
        frameIndex += 1
        capturedCount += 1
        lastFrameAt = Date()

        let finalWidth = width > 0 ? width : Int(image?.size.width ?? 0)
        let finalHeight = height > 0 ? height : Int(image?.size.height ?? 0)

        let packet = BiotechTrainingFramePacket(
            frameIndex: frameIndex,
            timestamp: Date(),
            timeSeconds: timeSeconds,
            requestedFPS: requestedFPS,
            source: source,
            width: finalWidth,
            height: finalHeight,
            qualityTag: qualityTag
        )

        let sample = BiotechTrainingImageSample(
            packet: packet,
            image: keepUIImageInMemory ? image : nil
        )

        buffer.append(sample)

        if buffer.count > maxBufferFrames {
            buffer.removeFirst(buffer.count - maxBufferFrames)
            droppedCount += 1
        }

        status = "DATA ON · \(capturedCount) FRAMES · BUF \(buffer.count)"
    }

    public func exportManifestJSONData() throws -> Data {
        let packets = buffer.map { $0.packet }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(packets)
    }

    public func exportManifestCSV() -> String {
        var rows = ["frame,timestamp,time_seconds,requested_fps,source,width,height,quality"]

        let formatter = ISO8601DateFormatter()

        for sample in buffer {
            let p = sample.packet
            rows.append([
                String(p.frameIndex),
                formatter.string(from: p.timestamp),
                String(p.timeSeconds),
                String(p.requestedFPS),
                p.source,
                String(p.width),
                String(p.height),
                p.qualityTag
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    public var shortHUD: String {
        isDataOn ? "DATA ON \(capturedCount)" : "DATA OFF"
    }
}
