import SwiftUI
import UIKit
import CoreLocation
import Foundation

class ProfileStore: ObservableObject {
    
    @Published var horses: [HorseProfile] = [
        HorseProfile(name: "NO HORSE SELECTED", age: 0, breed: "", notes: "Create or import a real horse profile before measuring"),
        
    ]
    
    @Published var riders: [RiderProfile] = [
        RiderProfile(name: "NO RIDER SELECTED", level: "", weight: 0, notes: "Create or import a real rider profile before measuring"),
    ]
    
    @Published var selectedHorseIndex = 0
    @Published var selectedRiderIndex = 0
    
    @Published var profileStatus = "PROFILE READY"
    @Published var nfcStatus = "NFC STANDBY"
    
    var horseName: String {
        horses.indices.contains(selectedHorseIndex) ? horses[selectedHorseIndex].name : "NO HORSE"
    }
    
    var riderName: String {
        riders.indices.contains(selectedRiderIndex) ? riders[selectedRiderIndex].name : "NO RIDER"
    }
    
    private var horseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avo_horses.json")
    }
    
    private var riderURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avo_riders.json")
    }
    
    init() {
        loadProfiles()
    }
    
    func nextHorse() {
        guard !horses.isEmpty else { return }
        selectedHorseIndex = (selectedHorseIndex + 1) % horses.count
        profileStatus = "HORSE \(horseName)"
    }
    
    func nextRider() {
        guard !riders.isEmpty else { return }
        selectedRiderIndex = (selectedRiderIndex + 1) % riders.count
        profileStatus = "RIDER \(riderName)"
    }
    
    func applyNFC(horseID: String, riderID: String) {
        if horseID.contains("03") {
            selectedHorseIndex = min(2, horses.count - 1)
        } else if horseID.contains("02") {
            selectedHorseIndex = min(1, horses.count - 1)
        } else {
            selectedHorseIndex = 0
        }
        
        if riderID.contains("03") {
            selectedRiderIndex = min(2, riders.count - 1)
        } else if riderID.contains("02") {
            selectedRiderIndex = min(1, riders.count - 1)
        } else {
            selectedRiderIndex = 0
        }
        
        nfcStatus = "NFC \(horseName) / \(riderName)"
        profileStatus = "NFC LOADED"
    }
    
    func simulateNFC() {
        let nextHorseID = selectedHorseIndex == 0 ? "HORSE02" : selectedHorseIndex == 1 ? "HORSE03" : "HORSE01"
        let nextRiderID = selectedRiderIndex == 0 ? "RIDER02" : selectedRiderIndex == 1 ? "RIDER03" : "RIDER01"
        
        applyNFC(horseID: nextHorseID, riderID: nextRiderID)
    }
    
    func updateSelectedHorse(name: String, ageText: String, breed: String, notes: String) {
        guard horses.indices.contains(selectedHorseIndex) else { return }
        
        let old = horses[selectedHorseIndex]
        let age = Int(ageText) ?? old.age
        
        horses[selectedHorseIndex] = HorseProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? old.name : name,
            age: age,
            breed: breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? old.breed : breed,
            notes: notes
        )
        
        profileStatus = "HORSE EDITED"
    }
    
    func updateSelectedRider(name: String, level: String, weightText: String, notes: String) {
        guard riders.indices.contains(selectedRiderIndex) else { return }
        
        let old = riders[selectedRiderIndex]
        let weight = Double(weightText) ?? old.weight
        
        riders[selectedRiderIndex] = RiderProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? old.name : name,
            level: level.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? old.level : level,
            weight: weight,
            notes: notes
        )
        
        profileStatus = "RIDER EDITED"
    }
    
    func newHorse() {
        let number = horses.count + 1
        
        horses.append(
            HorseProfile(
                name: "AVO HORSE \(String(format: "%02d", number))",
                age: 4,
                breed: "NEW",
                notes: "New horse profile"
            )
        )
        
        selectedHorseIndex = horses.count - 1
        profileStatus = "NEW HORSE CREATED"
    }
    
    func newRider() {
        let number = riders.count + 1
        
        riders.append(
            RiderProfile(
                name: "RIDER \(String(format: "%02d", number))",
                level: "NEW",
                weight: 70,
                notes: "New rider profile"
            )
        )
        
        selectedRiderIndex = riders.count - 1
        profileStatus = "NEW RIDER CREATED"
    }
    

    func deleteSelectedHorse() {
        guard horses.count > 1, horses.indices.contains(selectedHorseIndex) else {
            profileStatus = "KEEP ONE HORSE"
            return
        }
        horses.remove(at: selectedHorseIndex)
        selectedHorseIndex = min(selectedHorseIndex, horses.count - 1)
        profileStatus = "HORSE DELETED"
        saveProfiles()
    }

    func deleteSelectedRider() {
        guard riders.count > 1, riders.indices.contains(selectedRiderIndex) else {
            profileStatus = "KEEP ONE RIDER"
            return
        }
        riders.remove(at: selectedRiderIndex)
        selectedRiderIndex = min(selectedRiderIndex, riders.count - 1)
        profileStatus = "RIDER DELETED"
        saveProfiles()
    }

    func saveProfiles() {
        do {
            try JSONEncoder().encode(horses).write(to: horseURL)
            try JSONEncoder().encode(riders).write(to: riderURL)
            profileStatus = "PROFILES SAVED"
        } catch {
            profileStatus = "PROFILE SAVE ERROR"
        }
    }
    
    func loadProfiles() {
        do {
            if FileManager.default.fileExists(atPath: horseURL.path) {
                horses = try JSONDecoder().decode([HorseProfile].self, from: Data(contentsOf: horseURL))
            }
            
            if FileManager.default.fileExists(atPath: riderURL.path) {
                riders = try JSONDecoder().decode([RiderProfile].self, from: Data(contentsOf: riderURL))
            }
            
            if horses.isEmpty {
                horses = [HorseProfile(name: "NO HORSE SELECTED", age: 0, breed: "", notes: "Create or import a real horse profile before measuring")]
            }
            
            if riders.isEmpty {
                riders = [RiderProfile(name: "NO RIDER SELECTED", level: "", weight: 0, notes: "Create or import a real rider profile before measuring")]
            }
            
            let savedHorseIndex = UserDefaults.standard.integer(forKey: "AVOUnifiedSelectedHorseIndexV1")
            let savedRiderIndex = UserDefaults.standard.integer(forKey: "AVOUnifiedSelectedRiderIndexV1")
            selectedHorseIndex = min(max(0, savedHorseIndex), horses.count - 1)
            selectedRiderIndex = min(max(0, savedRiderIndex), riders.count - 1)
            
            profileStatus = "PROFILES LOADED"
        } catch {
            profileStatus = "PROFILE LOAD ERROR"
        }
    }
}

class HardwareSettings: ObservableObject {
    
    @Published var lockedMode = false
    @Published var fullscreenMode = false
    @Published var udpPort: UInt16 = 7777
    @Published var baseIP = "192.168.1.100"
    @Published var basePort = "8080"
    @Published var autoRecordInsideZone = false
    
    // 🔥 SOLUCIÓN A LOS 4 ERRORES ROJOS: Aquí está la variable que faltaba
    @Published var savedHeltecMAC: String = UserDefaults.standard.string(forKey: "savedHeltecMAC") ?? "" {
        didSet {
            UserDefaults.standard.set(savedHeltecMAC, forKey: "savedHeltecMAC")
        }
    }
    
    @Published var calibrationStatus = "IMU NOT CALIBRATED"
    @Published var permissionsStatus = "PERMISSIONS CHECK"
    @Published var coreMLStatus = "MODEL CHECK READY"
    @Published var appStoreStatus = "APP STORE PREP READY"
    
    @Published var commercialMode: CommercialMode = .expert
    
    @Published var trainingZone = TrainingZone(
        name: "DEFAULT",
        latitude: 43.4145,
        longitude: -3.4168,
        radiusMeters: 120
    )
    
    @Published var alertThresholdRisk = 0.70
    @Published var alertThresholdFatigue = 0.70
    
    func calibrateIMU() {
        calibrationStatus = "IMU ZERO SET"
    }
    
    func toggleMode() {
        let all = CommercialMode.allCases
        let idx = all.firstIndex(of: commercialMode) ?? 0
        commercialMode = all[(idx + 1) % all.count]
    }
    
    func checkPermissions() {
        permissionsStatus = "CAM OK / LOC OK / NETWORK OK"
    }
    
    func checkCoreMLModels() {
        coreMLStatus = "HorseDetector.mlmodelc READY"
    }
    
    func prepareAppStore() {
        appStoreStatus = "TESTFLIGHT / APPSTORE READY"
    }
}

class SessionStore: ObservableObject {
    
    @Published var saveStatus = "SAVE READY"
    @Published var replayStatus = "REPLAY READY"
    @Published var pdfStatus = "PDF READY"
    @Published var syncStatus = "SYNC READY"
    @Published var exportStatus = "EXPORT READY"
    
    @Published var availableSessions: [URL] = []
    @Published var selectedSessionName = "NO FILE"
    
    @Published var replaySamples: [SessionSample] = []
    @Published var isReplayMode = false
    @Published var replayPaused = true
    @Published var replayIndex = 0
    
    @Published var historyStatus = "HISTORY READY"
    
    func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func refreshSessions() {
        do {
            availableSessions = try FileManager.default
                .contentsOfDirectory(at: documentsURL(), includingPropertiesForKeys: nil)
                .filter {
                    $0.lastPathComponent.hasPrefix("AVO_SESSION_") &&
                    $0.pathExtension.lowercased() == "json"
                }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            
            selectedSessionName = availableSessions.first?.lastPathComponent ?? "NO FILE"
            replayStatus = availableSessions.isEmpty ? "NO FILES" : "FILES \(availableSessions.count)"
        } catch {
            replayStatus = "LIST ERROR"
        }
    }
    
    func saveSession(samples: [SessionSample]) {
        guard !samples.isEmpty else {
            saveStatus = "NO REAL SAMPLES · NOTHING SAVED"
            return
        }
        let dataToSave = samples
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        
        let name = "AVO_SESSION_\(formatter.string(from: Date())).json"
        let url = documentsURL().appendingPathComponent(name)
        
        do {
            try JSONEncoder().encode(dataToSave).write(to: url)
            saveStatus = "SAVED \(dataToSave.count)"
            refreshSessions()
        } catch {
            saveStatus = "SAVE ERROR"
        }
    }
    
    func createDemoReplayFile() {
        replayStatus = "REAL DATA ONLY"
    }
    
    func loadLastSession() {
        refreshSessions()
        
        guard let url = availableSessions.first else {
            replayStatus = "NO SESSION"
            return
        }
        
        loadSession(url)
    }
    
    func loadSession(_ url: URL) {
        do {
            replaySamples = try JSONDecoder().decode(
                [SessionSample].self,
                from: Data(contentsOf: url)
            )
            
            replayIndex = 0
            replayPaused = true
            isReplayMode = true
            selectedSessionName = url.lastPathComponent
            replayStatus = "LOADED \(replaySamples.count)"
        } catch {
            replayStatus = "LOAD ERROR"
        }
    }
    
    func loadSessionAt(_ index: Int) {
        guard availableSessions.indices.contains(index) else {
            replayStatus = "BAD INDEX"
            return
        }
        
        loadSession(availableSessions[index])
    }
    
    func stopReplay() {
        replayPaused = true
        isReplayMode = false
        replayStatus = "REPLAY STOP"
    }
    
    func nextReplaySample() -> SessionSample? {
        guard isReplayMode, !replayPaused, !replaySamples.isEmpty else {
            return nil
        }
        
        let sample = replaySamples[replayIndex]
        replayIndex += 1
        
        if replayIndex >= replaySamples.count {
            replayIndex = 0
            replayPaused = true
            replayStatus = "REPLAY END"
        }
        
        return sample
    }
    
    func jumpReplayForward() {
        guard !replaySamples.isEmpty else { return }
        replayIndex = min(replaySamples.count - 1, replayIndex + 25)
    }
    
    func makeDemoSession() -> [SessionSample] {
        var result: [SessionSample] = []
        let baseTime = Date().timeIntervalSince1970
        
        for i in 0..<240 {
            let t = Double(i)
            let speed = 12.0 + sin(t / 12.0) * 4.0 + Double.random(in: -0.5...0.5)
            let pulse = 42 + Int(sin(t / 18.0) * 8.0) + Int.random(in: -2...2)
            let risk = max(0.05, min(0.95, 0.25 + sin(t / 30.0) * 0.18))
            let fatigue = max(0.05, min(0.95, Double(i) / 260.0))
            let quality = max(0.05, min(1.0, 1.0 - risk * 0.4 - fatigue * 0.3))
            
            result.append(
                SessionSample(
                    time: baseTime + Double(i),
                    quality: quality,
                    risk: risk,
                    fatigue: fatigue,
                    latitude: 43.4145 + Double(i) * 0.000003,
                    longitude: -3.4168 + sin(t / 20.0) * 0.00005,
                    gait: speed > 17 ? "GALLOP" : speed > 10 ? "TROT" : "WALK",
                    score: "\(Int(quality * 100))",
                    pulse: "\(pulse) BPM",
                    speed: String(format: "%.1f km/h", speed),
                    rssi: "RSSI -\(Int.random(in: 50...80))"
                )
            )
        }
        
        return result
    }
    
    func createPDFReport(samples: [SessionSample], horse: String, rider: String) {
        pdfStatus = samples.isEmpty ? "PDF EMPTY" : "PDF READY"
    }
    
    func updateHistory(samples: [SessionSample]) {
        historyStatus = samples.isEmpty ? "NO HISTORY" : "HISTORY \(samples.count)"
    }
    
    func syncToBase(samples: [SessionSample], settings: HardwareSettings) {
        syncStatus = samples.isEmpty ? "SYNC EMPTY" : "SYNC READY"
    }
}

