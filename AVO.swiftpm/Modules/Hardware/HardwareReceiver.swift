import Foundation
import CoreLocation
import Network
import CoreBluetooth

struct BLEDiscoveredDevice: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let mac: String
    let rssi: Int
}

struct AVOTrainingNotificationEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let type: String
    let title: String
    let body: String

    init(type: String, title: String, body: String) {
        self.id = UUID()
        self.date = Date()
        self.type = type
        self.title = title
        self.body = body
    }
}


private final class AVOSimpleKalman1D {
    private var estimate: Double = 0
    private var errorEstimate: Double = 1
    private let processNoise: Double
    private let measurementNoise: Double
    private var hasEstimate = false

    init(processNoise: Double = 0.015, measurementNoise: Double = 0.18) {
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
    }

    func filter(_ measurement: Double) -> Double {
        if !hasEstimate {
            estimate = measurement
            hasEstimate = true
            return measurement
        }
        errorEstimate += processNoise
        let gain = errorEstimate / (errorEstimate + measurementNoise)
        estimate += gain * (measurement - estimate)
        errorEstimate = (1 - gain) * errorEstimate
        return estimate
    }
}

final class AVOHardwareReceiver: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @Published var udpStatus = "UDP 7777 READY"
    @Published var bleStatus = "BLE WAITING"
    @Published var esp32Status = "ESP32 WAITING"
    @Published var packetStatus = "PACKETS --"
    @Published var vestConnectionState = "VEST WAITING"
    @Published var vestConnectionAlert = "Chaleco esperando conexión"
    @Published var vestIsConnected = false
    @Published var activeVestHorse = "NO HORSE"
    @Published var activeVestRider = "NO RIDER"
    @Published var geofenceStatus = "GEOFENCE NOT SENT"
    @Published var trainingZonePresence = "ZONE UNKNOWN"
    @Published var isInsideTrainingZone = false
    @Published var latestNotificationTitle = "AVO LIVE READY"
    @Published var latestNotificationBody = "Esperando eventos del chaleco"
    @Published var notificationSerial = 0
    @Published var notificationFeed: [AVOTrainingNotificationEvent] = []
    
    // MARK: - Raspberry Cloud Dashboard Link
    @Published var cloudStatus = "CLOUD OFF"
    @Published var cloudAPI = "https://live.avoperformance.org:443/api/telemetry"
    @Published var cloudEnabled = false
    @Published var cloudLastError = "--"
    @Published var cloudLastHTTPCode = 0
    @Published var cloudLastPayload = "--"
    @Published var selectedVestID = "VEST_001"
    @Published var vestRegistryStatus = "REGISTRY WAITING"
    @Published var availableVests: [String] = []
    @Published var lastVestSeenSeconds = -1.0
    @Published var gpsFix = "NO_FIX"
    @Published var gpsSatellites = 0
    @Published var gpsHDOP = 99.9
    @Published var gpsNTRIP = false
    @Published var gpsAltitude = 0.0
    
    @Published var protocolStatus =
    "PROTO: t,seq,lat,lon,pulse,speed,cadence,rssi,battery,pitch,roll,impact,horse,rider,imu[]"
    
    @Published var rssi = "RSSI --"
    @Published var remoteBattery = "BAT --"
    
    @Published var hasExternalRTK = false
    
    @Published var externalCoordinate =
    CLLocationCoordinate2D(latitude: 43.4145, longitude: -3.4168)
    
    @Published var externalPath: [CLLocationCoordinate2D] = []
    
    @Published var pulse = "41 BPM"
    @Published var speed = "14.6 km/h"
    @Published var cadence = "112 BPM"
    
    @Published var imuPitch = 0.0
    @Published var imuRoll = 0.0
    /// Real impact after gravity removal, in dynamic G. In rest this must be near 0.00.
    @Published var imuImpact = 0.0
    @Published var motionIntensity = 0.0
    @Published var gaitState = "STATIC"
    @Published var linearAccelX = 0.0
    @Published var linearAccelY = 0.0
    @Published var linearAccelZ = 0.0
    @Published var gravityX = 0.0
    @Published var gravityY = 0.0
    @Published var gravityZ = 1.0
    @Published var heartHistory: [Double] = []
    @Published var speedHistory: [Double] = []
    @Published var impactHistory: [Double] = []
    @Published var motionHistory: [Double] = []
    
    @Published var nfcHorse = "HORSE01"
    @Published var nfcRider = "RIDER01"
    @Published var lastNFCTag = "NFC DISABLED"
    
    @Published var lastTimestamp: Double = 0
    @Published var lastSeq: Int = -1
    @Published var lostPackets = 0
    @Published var packetHz = 0.0
    @Published var liveRateText = "LIVE RATE --"
    @Published var seqStatus = "SEQ --"
    @Published var batchCount = 0
    @Published var lastIMUBatch: [IMUBatchSample] = []
    
    @Published var isScanning = false
    @Published var discoveredDevices: [BLEDiscoveredDevice] = []
    
    private var listener: NWListener?
    private var packetCount = 0
    private var currentPort: UInt16 = 7777
    private var cloudTask: Task<Void, Never>?
    private var connectionWatchTask: Task<Void, Never>?
    private var lastPacketDate = Date.distantPast
    private var pendingVestPayload: String?
    private var lastZoneInsideState: Bool?
    private var lastHorseNotification = ""
    private var lastRiderNotification = ""
    private var lastRegistryFetchDate = Date.distantPast

    private let pitchKalman = AVOSimpleKalman1D()
    private let rollKalman = AVOSimpleKalman1D()
    private let impactKalman = AVOSimpleKalman1D(processNoise: 0.025, measurementNoise: 0.22)
    private let motionKalman = AVOSimpleKalman1D(processNoise: 0.025, measurementNoise: 0.20)
    private let gravityAlpha = 0.92
    private let maxLiveHistoryPoints = 80
    private var latestSpeedKmh = 0.0
    
    private var hzWindowStart = Date()
    private var hzWindowPackets = 0
    
    private var central: CBCentralManager?
    private var heltecPeripheral: CBPeripheral?
    private var notifyCharacteristic: CBCharacteristic?
    
    private var bleBuffer = ""
    
    private let serviceUUID = CBUUID(string: "7A100001-4F8B-4B2A-A812-1234567890AB")
    private let characteristicUUID = CBUUID(string: "7A100002-4F8B-4B2A-A812-1234567890AB")
    
    private let targetNames = [
        "AVO_HORSE_HELTEC",
        "AVO",
        "HELTEC",
        "Heltec",
        "ESP32",
        "Horse"
    ]
    
    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        startUDP(port: currentPort)
        startRaspberryCloud()
        startConnectionWatchdog()
    }
    


    // MARK: - Vest connection state / outbound commands

    private func markVestConnected(source: String) {
        lastPacketDate = Date()
        if !vestIsConnected {
            vestConnectionAlert = "Chaleco conectado por \(source)"
            emitTrainingEvent(
                type: "vest.connected",
                title: "Chaleco conectado",
                body: "Conexión activa por \(source)"
            )
            transmitPendingVestPayload(sentText: "QUEUED CONFIG SENT BLE", fallbackText: geofenceStatus)
        }
        vestIsConnected = true
        vestConnectionState = "VEST CONNECTED · \(source)"
    }

    private func markVestDisconnected(reason: String) {
        if vestIsConnected {
            vestConnectionAlert = "Chaleco desconectado · \(reason)"
            emitTrainingEvent(
                type: "vest.disconnected",
                title: "Chaleco desconectado",
                body: reason
            )
        }
        vestIsConnected = false
        vestConnectionState = "VEST DISCONNECTED · \(reason)"
    }

    private func startConnectionWatchdog() {
        connectionWatchTask?.cancel()
        connectionWatchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let self = self else { return }
                    if self.vestIsConnected && Date().timeIntervalSince(self.lastPacketDate) > 4.0 {
                        self.markVestDisconnected(reason: "sin datos 4s")
                    }
                }
            }
        }
    }

    func setActiveVestHorse(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = clean.isEmpty ? "NO HORSE" : clean
        activeVestHorse = resolved
        if resolved != "NO HORSE", resolved != lastHorseNotification {
            lastHorseNotification = resolved
            emitTrainingEvent(type: "horse.loaded", title: "Caballo cargado", body: resolved)
        }
    }

    func setActiveVestRider(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = clean.isEmpty ? "NO RIDER" : clean
        activeVestRider = resolved
        nfcRider = resolved
        if resolved != "NO RIDER", resolved != lastRiderNotification {
            lastRiderNotification = resolved
            emitTrainingEvent(type: "rider.loaded", title: "Jinete cargado", body: resolved)
        }
    }

    func updateTrainingZonePresence(_ zone: TrainingZone) {
        let horseLocation = CLLocation(latitude: externalCoordinate.latitude, longitude: externalCoordinate.longitude)
        let center = CLLocation(latitude: zone.latitude, longitude: zone.longitude)
        let distance = horseLocation.distance(from: center)
        let inside: Bool
        if zone.isFreeDrawZone {
            inside = pointInPolygon(externalCoordinate, polygon: zone.polygonCoordinates)
        } else {
            inside = distance <= zone.radiusMeters
        }
        isInsideTrainingZone = inside
        let mode = zone.isFreeDrawZone ? "DRAW" : "CIRCLE"
        trainingZonePresence = inside ? String(format: "INSIDE %@ · %.0fm", mode, distance) : String(format: "OUTSIDE %@ · %.0fm", mode, distance)
        if lastZoneInsideState != inside {
            lastZoneInsideState = inside
            if inside {
                emitTrainingEvent(type: "zone.inside", title: "Caballo dentro de zona", body: "\(activeVestHorse) está dentro de \(zone.name)")
            } else {
                emitTrainingEvent(type: "zone.outside", title: "Caballo fuera de zona", body: "\(activeVestHorse) salió de \(zone.name)")
            }
        }
    }

    private func pointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        let x = point.longitude
        let y = point.latitude
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            let intersects = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 0.0000001 : (yj - yi)) + xi)
            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }

    private func emitTrainingEvent(type: String, title: String, body: String) {
        latestNotificationTitle = title
        latestNotificationBody = body
        notificationSerial += 1
        notificationFeed.insert(AVOTrainingNotificationEvent(type: type, title: title, body: body), at: 0)
        if notificationFeed.count > 30 { notificationFeed.removeLast(notificationFeed.count - 30) }

        // Push delivery is intentionally NOT fired here.
        // The dashboard bridge consumes notificationSerial once and applies anti-spam/frozen-state rules.
    }

    func acknowledgeAppNotificationDelivery() {
        // Reserved for future Android/cloud bridge acknowledgements.
    }

    func sendTrainingZone(_ zone: TrainingZone, horseName: String) {
        let polygonPayload = zone.polygon.map { ["lat": $0.latitude, "lon": $0.longitude] }
        let payload: [String: Any] = [
            "cmd": "training_zone",
            "applyOnBoot": true,
            "horse": horseName,
            "zone": [
                "name": zone.name,
                "type": zone.isFreeDrawZone ? "polygon" : "circle",
                "lat": zone.latitude,
                "lon": zone.longitude,
                "radius_m": zone.radiusMeters,
                "polygon": polygonPayload
            ]
        ]
        sendVestPayload(payload, readyText: "GEOFENCE QUEUED", sentText: "GEOFENCE SENT BLE")
    }

    private func sendVestPayload(_ payload: [String: Any], readyText: String, sentText: String) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              var text = String(data: data, encoding: .utf8) else {
            geofenceStatus = "GEOFENCE JSON ERROR"
            emitTrainingEvent(type: "geofence.error", title: "Geocerca no enviada", body: "Error creando JSON")
            return
        }
        text += "\n"
        pendingVestPayload = text
        protocolStatus = text
        transmitPendingVestPayload(sentText: sentText, fallbackText: readyText)
    }

    private func transmitPendingVestPayload(sentText: String = "CONFIG SENT BLE", fallbackText: String = "BLE CONFIG READY / NOT CONNECTED") {
        guard let text = pendingVestPayload else { return }
        guard let peripheral = heltecPeripheral,
              let characteristic = notifyCharacteristic,
              characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) else {
            esp32Status = fallbackText
            geofenceStatus = fallbackText
            return
        }
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(Data(text.utf8), for: characteristic, type: writeType)
        pendingVestPayload = nil
        esp32Status = sentText
        geofenceStatus = sentText
        protocolStatus = "LAST VEST TX"
        emitTrainingEvent(type: "geofence.sent", title: "Geocerca enviada", body: sentText)
    }

    // MARK: - Raspberry Cloud HTTP Polling

    func configureRaspberryCloud(host: String, port: Int, path: String, useHTTPS: Bool, pollSeconds: Double, enabled: Bool) {
        let cleanHost = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? path : "/" + path
        let scheme = useHTTPS ? "https" : "http"
        cloudAPI = "\(scheme)://\(cleanHost):\(port)\(cleanPath)"
        cloudEnabled = enabled
        if enabled {
            startRaspberryCloud(interval: pollSeconds)
        } else {
            stopRaspberryCloud()
        }
    }

    func startRaspberryCloud(interval: Double = 0.5) {
        cloudTask?.cancel()
        cloudEnabled = true
        cloudStatus = "CLOUD CONNECTING"
        let safeInterval = max(0.25, interval)

        cloudTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchRaspberryLatest()
                let ns = UInt64(safeInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    func stopRaspberryCloud() {
        cloudTask?.cancel()
        cloudTask = nil
        cloudEnabled = false
        cloudStatus = "CLOUD OFF"
    }

    @MainActor
    private func applyCloudPacket(_ json: [String: Any], rawText: String, httpCode: Int) {
        cloudLastHTTPCode = httpCode
        cloudLastPayload = String(rawText.prefix(240))
        cloudLastError = "--"
        cloudStatus = "CLOUD ONLINE"
        markVestConnected(source: "CLOUD")
        parsePacket(rawText)
    }

    @MainActor
    private func applyVestRegistry(_ json: [String: Any], rawText: String, httpCode: Int) {
        cloudLastHTTPCode = httpCode
        cloudLastPayload = String(rawText.prefix(240))
        cloudLastError = "--"

        let list = (json["vests"] as? [[String: Any]]) ?? (json["items"] as? [[String: Any]]) ?? []
        let ids = list.compactMap { item in
            (item["id"] as? String) ?? (item["vestId"] as? String) ?? (item["vest_id"] as? String)
        }
        if !ids.isEmpty {
            availableVests = ids
            if !ids.contains(selectedVestID) { selectedVestID = ids[0] }
        }
        vestRegistryStatus = ids.isEmpty ? "REGISTRY EMPTY" : "REGISTRY \(ids.count) VESTS"
    }

    @MainActor
    private func applyVestStatus(_ json: [String: Any], rawText: String, httpCode: Int) {
        cloudLastHTTPCode = httpCode
        cloudLastPayload = String(rawText.prefix(240))
        cloudLastError = "--"

        let state = ((json["connectionState"] as? String) ??
                     (json["connection_state"] as? String) ??
                     (json["state"] as? String) ??
                     (json["status"] as? String) ?? "UNKNOWN").uppercased()

        let frozen = jsonBool(json["frozen"]) ?? state.contains("FROZEN")
        let online = state.contains("ONLINE") || state.contains("CONNECTED") || state == "ON"
        lastVestSeenSeconds = jsonDouble(json["lastPacketAge"]) ?? jsonDouble(json["last_packet_age"]) ?? jsonDouble(json["lastSeenSeconds"]) ?? jsonDouble(json["last_seen_seconds"]) ?? jsonDouble(json["ageSeconds"]) ?? lastVestSeenSeconds

        if let vestID = (json["id"] as? String) ?? (json["vestId"] as? String) ?? (json["vest_id"] as? String) { selectedVestID = vestID }
        if let horse = (json["horse"] as? String) ?? (json["horseId"] as? String) ?? (json["horse_id"] as? String) { setActiveVestHorse(horse) }
        if let rider = (json["rider"] as? String) ?? (json["riderId"] as? String) ?? (json["rider_id"] as? String) { setActiveVestRider(rider) }
        if let battery = jsonInt(json["battery"]) ?? jsonInt(json["batteryPercent"]) ?? jsonInt(json["battery_percent"]) { remoteBattery = "BAT \(battery)%" }

        if let gps = json["gps"] as? [String: Any] { applyGPSDictionary(gps) }

        if frozen && lastVestSeenSeconds > 20 {
            vestRegistryStatus = "VEST OFFLINE"
            cloudStatus = "CLOUD ONLINE"
            markVestDisconnected(reason: "sin heartbeat >20s")
        } else if frozen {
            vestConnectionAlert = "Cloud conectado · chaleco FROZEN"
            vestConnectionState = "VEST FROZEN"
            vestRegistryStatus = "VEST FROZEN"
            vestIsConnected = false
            cloudStatus = "CLOUD FROZEN"
        } else if online {
            vestRegistryStatus = "VEST ONLINE"
            cloudStatus = "CLOUD ONLINE"
            markVestConnected(source: "CLOUD")
        } else {
            vestRegistryStatus = "VEST OFFLINE"
            cloudStatus = "CLOUD ONLINE"
            markVestDisconnected(reason: "servidor marca OFFLINE")
        }
    }

    private func raspberryAPIURL(path: String) -> URL? {
        let raw = cloudAPI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), let scheme = url.scheme, let host = url.host else { return nil }
        var root = "\(scheme)://\(host)"
        if let port = url.port { root += ":\(port)" }
        let cleanPath = path.hasPrefix("/") ? path : "/" + path
        return URL(string: root + cleanPath)
    }

    private func fetchRaspberryJSON(url: URL) async throws -> (json: [String: Any], text: String, code: Int) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AVO.Raspberry", code: code, userInfo: [NSLocalizedDescriptionKey: "INVALID JSON"])
        }
        return (obj, text, code)
    }

    private func fetchRaspberryLatest() async {
        guard cloudEnabled else { return }

        do {
            // FIX 1.2.1/34: la app debe tomar como fuente principal el endpoint configurado.
            // En campo el servidor real responde en /api/latest con HTTP 200 y JSON válido.
            // Antes se consultaban primero /api/vests/VEST_001/status y /api/telemetry,
            // lo que podía marcar OFFLINE/FROZEN aunque /api/latest estuviera entregando datos LIVE.
            guard let primaryURL = URL(string: cloudAPI) else {
                await MainActor.run {
                    self.cloudStatus = "CLOUD BAD URL"
                    self.cloudLastError = "BAD URL"
                }
                return
            }

            let latest = try await fetchRaspberryJSON(url: primaryURL)
            await applyCloudPacket(latest.json, rawText: latest.text, httpCode: latest.code)

            // Registro de chalecos solo como información secundaria. Nunca debe tumbar el CLOUD ONLINE
            // si /api/latest acaba de responder bien.
            if Date().timeIntervalSince(lastRegistryFetchDate) > 8.0,
               let registryURL = raspberryAPIURL(path: "/api/vests"),
               let registry = try? await fetchRaspberryJSON(url: registryURL) {
                await applyVestRegistry(registry.json, rawText: registry.text, httpCode: registry.code)
                lastRegistryFetchDate = Date()
            }
        } catch {
            await MainActor.run {
                self.cloudLastError = error.localizedDescription
                self.cloudLastHTTPCode = 0

                // Anti-parpadeo: no declarar OFFLINE por un fallo aislado de red/Cloudflare.
                // Solo cae a offline si pasan más de 10 s sin ningún paquete válido.
                let age = Date().timeIntervalSince(self.lastPacketDate)
                if age > 10.0 {
                    self.cloudStatus = "CLOUD OFFLINE"
                    self.markVestDisconnected(reason: "cloud sin datos >10s")
                } else {
                    self.cloudStatus = "CLOUD ONLINE"
                    self.vestConnectionAlert = "Cloud con latencia · manteniendo último paquete"
                }
            }
        }
    }

    func startUDP(port: UInt16) {
        currentPort = port
        
        do {
            listener?.cancel()
            
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                udpStatus = "UDP BAD PORT"
                return
            }
            
            listener = try NWListener(using: .udp, on: nwPort)
            
            listener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .global(qos: .userInitiated))
                self?.receive(on: connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
            DispatchQueue.main.async {
                self.udpStatus = "UDP \(port) LISTENING"
            }
            
        } catch {
            DispatchQueue.main.async {
                self.udpStatus = "UDP ERROR"
            }
        }
    }
    
    func stopUDP() {
        listener?.cancel()
        listener = nil
        udpStatus = "UDP STOPPED"
    }
    
    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, _ in
            if let data = data,
               let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.parsePacket(text)
                }
            }
            
            self?.receive(on: connection)
        }
    }
    
    func startBLEScan() {
        guard let central = central else {
            bleStatus = "BLE NOT READY"
            return
        }
        
        guard central.state == .poweredOn else {
            bleStatus = "BLE OFF / NO PERMISSION"
            return
        }
        
        central.stopScan()
        
        heltecPeripheral = nil
        notifyCharacteristic = nil
        bleBuffer = ""
        discoveredDevices.removeAll()
        isScanning = true
        
        bleStatus = "BLE SCANNING"
        
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    
    func stopBLE() {
        central?.stopScan()
        isScanning = false
        
        if let peripheral = heltecPeripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        
        heltecPeripheral = nil
        notifyCharacteristic = nil
        bleBuffer = ""
        bleStatus = "BLE STOPPED"
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bleStatus = "BLE READY"
        case .poweredOff:
            bleStatus = "BLE OFF"
        case .unauthorized:
            bleStatus = "BLE UNAUTHORIZED"
        case .unsupported:
            bleStatus = "BLE UNSUPPORTED"
        case .resetting:
            bleStatus = "BLE RESETTING"
        case .unknown:
            bleStatus = "BLE UNKNOWN"
        @unknown default:
            bleStatus = "BLE ERROR"
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name =
        peripheral.name ??
        advertisementData[CBAdvertisementDataLocalNameKey] as? String ??
        ""
        
        let identifier = peripheral.identifier.uuidString
        
        let item = BLEDiscoveredDevice(
            name: name.isEmpty ? "UNKNOWN BLE" : name,
            mac: identifier,
            rssi: RSSI.intValue
        )
        
        if !discoveredDevices.contains(where: { $0.mac == item.mac }) {
            discoveredDevices.append(item)
        }
        
        let matchesName = targetNames.contains {
            name.localizedCaseInsensitiveContains($0)
        }
        
        guard matchesName else { return }
        
        rssi = "BLE RSSI \(RSSI.intValue)"
        bleStatus = "BLE FOUND \(name)"
        
        central.stopScan()
        isScanning = false
        
        heltecPeripheral = peripheral
        peripheral.delegate = self
        
        bleStatus = "BLE CONNECTING"
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        bleStatus = "BLE CONNECTED"
        esp32Status = "ESP32 BLE"
        markVestConnected(source: "BLE")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        bleStatus = "BLE CONNECT FAIL"
        esp32Status = "ESP32 FAIL"
        notifyCharacteristic = nil
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        bleStatus = "BLE DISCONNECTED"
        esp32Status = "ESP32 WAITING"
        markVestDisconnected(reason: "BLE lost")
        notifyCharacteristic = nil
        heltecPeripheral = nil
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if error != nil {
            bleStatus = "BLE SERVICE ERROR"
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            bleStatus = "BLE NO SERVICES"
            return
        }
        
        bleStatus = "BLE SERVICES \(services.count)"
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if error != nil {
            bleStatus = "BLE CHAR ERROR"
            return
        }
        
        guard let characteristics = service.characteristics else {
            bleStatus = "BLE NO CHARS"
            return
        }
        
        if let characteristic = characteristics.first(where: { $0.uuid == characteristicUUID }) {
            notifyCharacteristic = characteristic
            transmitPendingVestPayload(sentText: "QUEUED CONFIG SENT BLE", fallbackText: "BLE CONFIG READY")
            
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
                bleStatus = "BLE NOTIFY READY"
                esp32Status = "ESP32 BLE READY"
            }
            
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            
            return
        }
        
        if let notify = characteristics.first(where: { $0.properties.contains(.notify) }) {
            notifyCharacteristic = notify
            peripheral.setNotifyValue(true, for: notify)
            bleStatus = "BLE NOTIFY READY"
            esp32Status = "ESP32 BLE READY"
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if error != nil {
            bleStatus = "BLE NOTIFY ERROR"
            return
        }
        
        if characteristic.isNotifying {
            bleStatus = "BLE NOTIFY READY"
            esp32Status = "ESP32 BLE READY"
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if error != nil {
            bleStatus = "BLE DATA ERROR"
            return
        }
        
        guard let data = characteristic.value else { return }
        
        if let text = String(data: data, encoding: .utf8) {
            bleStatus = "BLE DATA RX"
            parseBLEBuffer(text)
        }
    }
    
    private func parseBLEBuffer(_ text: String) {
        bleBuffer += text
        
        while let start = bleBuffer.firstIndex(of: "{"),
              let end = bleBuffer[start...].firstIndex(of: "}") {
            
            let packet = String(bleBuffer[start...end])
            parsePacket(packet)
            
            let next = bleBuffer.index(after: end)
            bleBuffer = String(bleBuffer[next...])
        }
        
        if bleBuffer.count > 4096 {
            bleBuffer.removeAll()
        }
    }
    
    func parsePacket(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else { return }
        
        packetCount += 1
        hzWindowPackets += 1
        
        packetStatus = "PACKETS \(packetCount)"
        esp32Status = "ESP32 ONLINE"
        markVestConnected(source: cloudStatus.uppercased().contains("ONLINE") ? "CLOUD" : "UDP/BLE")
        
        updateHz()
        
        if let data = cleanText.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            parseJSON(json)
            return
        }
        
        let parts = cleanText.split(separator: ",").map { String($0) }
        
        for part in parts {
            let kv = part.split(separator: "=").map { String($0) }
            if kv.count != 2 { continue }
            parseKeyValue(key: kv[0], value: kv[1])
        }
        appendLiveHistorySample()
    }
    
    private func updateHz() {
        let now = Date()
        let elapsed = now.timeIntervalSince(hzWindowStart)
        
        if elapsed >= 1.0 {
            packetHz = Double(hzWindowPackets) / elapsed
            liveRateText = String(format: "LIVE %.1f Hz", packetHz)
            hzWindowPackets = 0
            hzWindowStart = now
        }
    }
    
    private func applyGPSDictionary(_ gps: [String: Any]) {
        if let lat = jsonDouble(gps["lat"]) ?? jsonDouble(gps["latitude"]) {
            externalCoordinate.latitude = lat
            hasExternalRTK = true
        }
        if let lon = jsonDouble(gps["lon"]) ?? jsonDouble(gps["lng"]) ?? jsonDouble(gps["longitude"]) {
            externalCoordinate.longitude = lon
            hasExternalRTK = true
            appendPath()
        }
        if let spd = jsonDouble(gps["speed"]) ?? jsonDouble(gps["speedKmh"]) ?? jsonDouble(gps["speed_kmh"]) {
            latestSpeedKmh = spd
            speed = String(format: "%.1f km/h", spd)
        }
        if let fix = (gps["fix"] as? String) ?? (gps["fixType"] as? String) ?? (gps["fix_type"] as? String) { gpsFix = fix }
        if let ntrip = jsonBool(gps["ntrip"]) ?? jsonBool(gps["ntripConnected"]) ?? jsonBool(gps["ntrip_connected"]) { gpsNTRIP = ntrip }
        if let sats = jsonInt(gps["sats"]) ?? jsonInt(gps["satellites"]) { gpsSatellites = sats }
        if let hdop = jsonDouble(gps["hdop"]) ?? jsonDouble(gps["accuracy"]) ?? jsonDouble(gps["accuracy_m"]) { gpsHDOP = hdop }
        if let altitude = jsonDouble(gps["altitude"]) ?? jsonDouble(gps["alt"]) { gpsAltitude = altitude }
    }

    private func parseJSON(_ json: [String: Any]) {
        if let telemetry = json["telemetry"] as? [String: Any] {
            parseJSON(telemetry)
            return
        }
        if let vest = json["vest"] as? [String: Any] {
            if let horse = (vest["horse"] as? String) ?? (vest["horseId"] as? String) { setActiveVestHorse(horse) }
            if let rider = (vest["rider"] as? String) ?? (vest["riderId"] as? String) { setActiveVestRider(rider) }
            if let battery = jsonInt(vest["battery"]) ?? jsonInt(vest["batteryPercent"]) { remoteBattery = "BAT \(battery)%" }
            if let state = (vest["connectionState"] as? String) ?? (vest["state"] as? String) { vestConnectionState = "VEST \(state.uppercased())" }
        }
        if let gps = json["gps"] as? [String: Any] {
            applyGPSDictionary(gps)
        }

        if let t = jsonDouble(json["t"]) {
            lastTimestamp = t
        }
        
        if let seq = jsonInt(json["seq"]) {
            updateSequence(seq)
        }
        
        if let horse = json["horseId"] as? String {
            nfcHorse = horse
            setActiveVestHorse(horse)
        }

        if let gps = json["gps"] as? [String: Any] {
            if let lat = jsonDouble(gps["lat"]) {
                externalCoordinate.latitude = lat
                hasExternalRTK = true
            }
            if let lon = jsonDouble(gps["lon"]) {
                externalCoordinate.longitude = lon
                hasExternalRTK = true
                appendPath()
            }
            if let spd = jsonDouble(gps["speed"]) {
                latestSpeedKmh = spd
                speed = String(format: "%.1f km/h", spd)
            }
            if let fix = gps["fix"] as? String {
                gpsFix = fix
            }
            if let ntrip = gps["ntrip"] as? Bool {
                gpsNTRIP = ntrip
            }
            if let sats = jsonInt(gps["sats"]) {
                gpsSatellites = sats
            }
            if let hdop = jsonDouble(gps["hdop"]) {
                gpsHDOP = hdop
            }
            if let altitude = jsonDouble(gps["altitude"]) {
                gpsAltitude = altitude
            }
        }

        let hasRawIMUDictionary = json["imu"] is [String: Any]
        if let imu = json["imu"] as? [String: Any] {
            let imuAx = jsonDouble(imu["ax"]) ?? jsonDouble(imu["accelX"]) ?? jsonDouble(imu["x"]) ?? 0
            let imuAy = jsonDouble(imu["ay"]) ?? jsonDouble(imu["accelY"]) ?? jsonDouble(imu["y"]) ?? 0
            let imuAz = jsonDouble(imu["az"]) ?? jsonDouble(imu["accelZ"]) ?? jsonDouble(imu["z"]) ?? 0
            ingestRawIMU(ax: imuAx, ay: imuAy, az: imuAz)
            lastIMUBatch = [
                IMUBatchSample(dt: 0, pitch: imuPitch, roll: imuRoll, impact: imuImpact),
                IMUBatchSample(dt: 1, pitch: linearAccelX, roll: linearAccelY, impact: motionIntensity)
            ]
            batchCount = lastIMUBatch.count
        }
        
        if let lat = jsonDouble(json["lat"]) {
            externalCoordinate.latitude = lat
            hasExternalRTK = true
        }
        
        if let lon = jsonDouble(json["lon"]) {
            externalCoordinate.longitude = lon
            hasExternalRTK = true
            appendPath()
        }
        
        if let v = jsonInt(json["pulse"]) {
            pulse = "\(v) BPM"
        }
        
        if let v = jsonDouble(json["speed"]) {
            latestSpeedKmh = v
            speed = String(format: "%.1f km/h", v)
        }
        
        if let v = jsonInt(json["cadence"]) {
            cadence = "\(v) BPM"
        }
        
        if let v = jsonInt(json["rssi"]) {
            rssi = "RSSI \(v)"
        }
        
        if let v = jsonInt(json["battery"]) {
            remoteBattery = "BAT \(v)%"
        }
        
        if let v = jsonDouble(json["pitch"]) {
            imuPitch = v
        }
        
        if let v = jsonDouble(json["roll"]) {
            imuRoll = v
        }
        
        if let v = jsonDouble(json["impact"]), !hasRawIMUDictionary, !(json["imu"] is [[String: Any]]) {
            ingestLegacyImpact(v)
        }
        
        if let v = json["horse"] as? String {
            nfcHorse = v
            setActiveVestHorse(v)
        }
        
        if let v = json["rider"] as? String {
            setActiveVestRider(v)
        }
        if let source = json["source"] as? String {
            esp32Status = source
        }
        
        parseIMUBatch(json)
        appendLiveHistorySample()
    }
    
    private func parseIMUBatch(_ json: [String: Any]) {
        guard let imuArray = json["imu"] as? [[String: Any]] else {
            if !(json["imu"] is [String: Any]) { batchCount = 0 }
            return
        }

        var parsed: [IMUBatchSample] = []
        for item in imuArray {
            if let ax = jsonDouble(item["ax"]) ?? jsonDouble(item["accelX"]) ?? jsonDouble(item["x"]),
               let ay = jsonDouble(item["ay"]) ?? jsonDouble(item["accelY"]) ?? jsonDouble(item["y"]),
               let az = jsonDouble(item["az"]) ?? jsonDouble(item["accelZ"]) ?? jsonDouble(item["z"]) {
                ingestRawIMU(ax: ax, ay: ay, az: az)
                parsed.append(IMUBatchSample(dt: jsonDouble(item["dt"]) ?? 0, pitch: imuPitch, roll: imuRoll, impact: imuImpact))
            } else {
                let dt = jsonDouble(item["dt"]) ?? 0
                let pitch = jsonDouble(item["pitch"]) ?? 0
                let roll = jsonDouble(item["roll"]) ?? 0
                let impact = jsonDouble(item["impact"]) ?? 0
                imuPitch = pitchKalman.filter(pitch)
                imuRoll = rollKalman.filter(roll)
                ingestLegacyImpact(impact)
                parsed.append(IMUBatchSample(dt: dt, pitch: imuPitch, roll: imuRoll, impact: imuImpact))
            }
        }

        batchCount = parsed.count
        if !parsed.isEmpty { lastIMUBatch = parsed }
    }

    private func ingestRawIMU(ax: Double, ay: Double, az: Double) {
        // The LilyGO may send m/s² (~9.81 at rest) or G (~1.0 at rest). Normalize to G first.
        let rawMagnitude = sqrt(ax * ax + ay * ay + az * az)
        let divisor = rawMagnitude > 4.0 ? 9.80665 : 1.0
        let gx = ax / divisor
        let gy = ay / divisor
        let gz = az / divisor

        gravityX = gravityAlpha * gravityX + (1.0 - gravityAlpha) * gx
        gravityY = gravityAlpha * gravityY + (1.0 - gravityAlpha) * gy
        gravityZ = gravityAlpha * gravityZ + (1.0 - gravityAlpha) * gz

        linearAccelX = gx - gravityX
        linearAccelY = gy - gravityY
        linearAccelZ = gz - gravityZ

        let dynamicG = sqrt(linearAccelX * linearAccelX + linearAccelY * linearAccelY + linearAccelZ * linearAccelZ)
        let deadbandedImpact = max(0.0, dynamicG - 0.025)
        imuImpact = impactKalman.filter(deadbandedImpact)
        motionIntensity = motionKalman.filter(max(0.0, dynamicG - 0.010))

        let pitchDegrees = atan2(gx, sqrt(gy * gy + gz * gz)) * 180.0 / .pi
        let rollDegrees = atan2(gy, sqrt(gx * gx + gz * gz)) * 180.0 / .pi
        imuPitch = pitchKalman.filter(pitchDegrees)
        imuRoll = rollKalman.filter(rollDegrees)
        updateGaitState()
    }

    private func ingestLegacyImpact(_ value: Double) {
        // Legacy packets sometimes sent total acceleration including gravity. Convert that into dynamic impact.
        let normalized = value > 4.0 ? value / 9.80665 : value
        let dynamicOnly = max(0.0, abs(normalized - 1.0))
        imuImpact = impactKalman.filter(dynamicOnly)
        motionIntensity = motionKalman.filter(dynamicOnly)
        updateGaitState()
    }

    private func updateGaitState() {
        let intensity = motionIntensity
        let speed = latestSpeedKmh
        if intensity < 0.035 && speed < 0.8 {
            gaitState = "STATIC"
        } else if intensity < 0.16 && speed < 7.0 {
            gaitState = "WALK"
        } else if intensity < 0.38 && speed < 18.0 {
            gaitState = "TROT"
        } else {
            gaitState = "GALLOP"
        }
    }

    private func appendLiveHistorySample() {
        appendBounded(&heartHistory, numericValue(from: pulse))
        appendBounded(&speedHistory, latestSpeedKmh)
        appendBounded(&impactHistory, imuImpact)
        appendBounded(&motionHistory, motionIntensity)
    }

    private func appendBounded(_ array: inout [Double], _ value: Double) {
        array.append(value)
        if array.count > maxLiveHistoryPoints {
            array.removeFirst(array.count - maxLiveHistoryPoints)
        }
    }

    private func numericValue(from text: String) -> Double {
        let allowed = text.filter { "0123456789.,-".contains($0) }.replacingOccurrences(of: ",", with: ".")
        return Double(allowed) ?? 0
    }

    private func parseKeyValue(key: String, value: String) {
        let k = key.lowercased()
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if k == "t", let t = Double(v) {
            lastTimestamp = t
        }
        
        if k == "seq", let seq = Int(v) {
            updateSequence(seq)
        }
        
        if k == "lat", let lat = Double(v) {
            externalCoordinate.latitude = lat
            hasExternalRTK = true
        }
        
        if k == "lon", let lon = Double(v) {
            externalCoordinate.longitude = lon
            hasExternalRTK = true
            appendPath()
        }
        
        if k == "pulse" { pulse = "\(v) BPM" }
        if k == "speed", let value = Double(v) { latestSpeedKmh = value; speed = String(format: "%.1f km/h", value); updateGaitState() }
        if k == "cadence" { cadence = "\(v) BPM" }
        if k == "rssi" { rssi = "RSSI \(v)" }
        if k == "battery" { remoteBattery = "BAT \(v)%" }
        
        if k == "pitch", let value = Double(v) { imuPitch = pitchKalman.filter(value) }
        if k == "roll", let value = Double(v) { imuRoll = rollKalman.filter(value) }
        if k == "impact", let value = Double(v) { ingestLegacyImpact(value) }
        
        if k == "horse" { nfcHorse = v; setActiveVestHorse(v) }
        if k == "rider" { setActiveVestRider(v) }
    }
    
    private func updateSequence(_ seq: Int) {
        if lastSeq >= 0 {
            let expected = lastSeq + 1
            if seq > expected {
                lostPackets += seq - expected
            }
        }
        
        lastSeq = seq
        seqStatus = "SEQ \(seq) / LOST \(lostPackets)"
    }
    
    private func appendPath() {
        externalPath.append(externalCoordinate)
        
        if externalPath.count > 500 {
            externalPath.removeFirst()
        }
    }
    
    private func jsonBool(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "yes", "on", "online", "connected", "1"].contains(lower) { return true }
            if ["false", "no", "off", "offline", "disconnected", "0"].contains(lower) { return false }
        }
        return nil
    }

    private func jsonDouble(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Float { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
    
    private func jsonInt(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? Float { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
    


    func sendDeviceConfiguration(_ config: AVODeviceConfiguration) {
        let payload: [String: Any] = [
            "cmd": "config",
            "device": "lilygo_tsim",
            "server": [
                "enabled": config.raspberryServerEnabled,
                "host": config.raspberryHost,
                "port": config.raspberryPort
            ],
            "sim": [
                "enabled": config.simEnabled,
                "apn": config.simAPN,
                "ntripHost": config.ntripHost,
                "ntripPort": config.ntripPort,
                "ntripMount": config.ntripMount,
                "ntripUser": config.ntripUser,
                "ntripPassword": config.ntripPassword
            ],
            "modules": [
                "rtk": config.rtkEnabled,
                "imu": config.imuEnabled,
                "girth": config.girthEnabled,
                "nfc": config.nfcEnabled,
                "lora": config.loraEnabled,
                "ble": config.bleEnabled
            ],
            "stream": [
                "rateHz": config.streamRateHz
            ]
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              var text = String(data: data, encoding: .utf8)
        else {
            esp32Status = "CONFIG JSON ERROR"
            return
        }

        text += "\n"

        guard let peripheral = heltecPeripheral,
              let characteristic = notifyCharacteristic
        else {
            esp32Status = "BLE CONFIG READY / NOT CONNECTED"
            protocolStatus = text
            return
        }

        let writeType: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse

        if characteristic.properties.contains(.write) ||
            characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(Data(text.utf8), for: characteristic, type: writeType)
            esp32Status = "CONFIG SENT BLE"
            protocolStatus = "LAST CONFIG TX"
        } else {
            esp32Status = "BLE CHAR NOT WRITABLE"
            protocolStatus = text
        }
    }

    func simulateDeviceDiscovery() {
        discoveredDevices = [
            BLEDiscoveredDevice(name: "AVO_HORSE_HELTEC", mac: "SIM-HELT-001", rssi: -42)
        ]
        bleStatus = "BLE SIM DEVICE"
    }
    
    func simulatePacket() {
        hasExternalRTK = true
        
        let nextSeq = lastSeq < 0 ? 1 : lastSeq + 1
        
        externalCoordinate.latitude += Double.random(in: -0.00003...0.00003)
        externalCoordinate.longitude += Double.random(in: -0.00003...0.00003)
        
        appendPath()
        updateSequence(nextSeq)
        
        lastTimestamp = Date().timeIntervalSince1970 * 1000.0
        
        pulse = "\(Int.random(in: 38...58)) BPM"
        speed = String(format: "%.1f km/h", Double.random(in: 10.0...22.0))
        cadence = "\(Int.random(in: 92...128)) BPM"
        rssi = "RSSI -\(Int.random(in: 52...88))"
        remoteBattery = "BAT \(Int.random(in: 55...99))%"
        
        imuPitch = Double.random(in: -3.0...3.0)
        imuRoll = Double.random(in: -4.0...4.0)
        imuImpact = Double.random(in: 0.05...0.85)
        
        lastIMUBatch = (0..<10).map { i in
            IMUBatchSample(
                dt: Double(i * 10),
                pitch: imuPitch + Double.random(in: -0.2...0.2),
                roll: imuRoll + Double.random(in: -0.2...0.2),
                impact: imuImpact + Double.random(in: -0.05...0.05)
            )
        }
        
        batchCount = lastIMUBatch.count
        
        esp32Status = "ESP32 SIM"
        
        packetCount += 1
        hzWindowPackets += 1
        packetStatus = "PACKETS \(packetCount)"
        updateHz()
    }
}
