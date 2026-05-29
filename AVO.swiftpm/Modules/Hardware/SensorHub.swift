import Foundation

class SensorHub: ObservableObject {
    
    @Published var imuStatus = "IMU READY"
    @Published var rtkStatus = "RTK READY"
    
    @Published var loraStatus = "LORA WAITING"
    @Published var pulseStatus = "41 BPM"
    @Published var speedStatus = "14.6 km/h"
    @Published var cadenceStatus = "112 BPM"
    
    @Published var esp32Status = "ESP32 WAITING"
    @Published var remoteBattery = "BAT --"
    
    @Published var imuPitch = 0.0
    @Published var imuRoll = 0.0
    @Published var imuImpact = 0.0
    @Published var motionIntensity = 0.0
    @Published var gaitState = "STATIC"
    
    @Published var liveRateText = "LIVE RATE --"
    @Published var seqStatus = "SEQ --"
    @Published var batchStatus = "IMU BATCH --"

    var impactStatus: String {
        String(format: "%.2f G", imuImpact)
    }
    
    func updateFromHardware(_ hardware: AVOHardwareReceiver) {
        esp32Status = hardware.esp32Status
        
        loraStatus =
        hardware.rssi == "RSSI --"
        ? "LORA WAITING"
        : hardware.rssi
        
        pulseStatus = hardware.pulse
        speedStatus = hardware.speed
        cadenceStatus = hardware.cadence
        remoteBattery = hardware.remoteBattery
        
        imuPitch = hardware.imuPitch
        imuRoll = hardware.imuRoll
        imuImpact = hardware.imuImpact
        motionIntensity = hardware.motionIntensity
        gaitState = hardware.gaitState
        
        rtkStatus =
        hardware.hasExternalRTK
        ? "RTK EXTERNAL"
        : "RTK READY"
        
        imuStatus =
        abs(hardware.imuPitch) > 0.01 || abs(hardware.imuRoll) > 0.01
        ? "IMU LIVE"
        : "IMU READY"
        
        liveRateText = hardware.liveRateText
        seqStatus = hardware.seqStatus
        batchStatus = "IMU BATCH \(hardware.batchCount)"
    }
}
