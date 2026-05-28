import SwiftUI
import MapKit
import CoreLocation

private struct AVOSavedGeofencePreset: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var horseId: String
    var zone: TrainingZone
    var savedAt: Date = Date()
}

struct AVOTrainingGeofenceEditorPage: View {
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings
    @ObservedObject var stableStore: AVOStableStore
    let onClose: () -> Void

    @State private var zoneName: String = ""
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""
    @State private var radiusMeters: Double = 120
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var drawMode = true
    @State private var drawnPolygon: [CLLocationCoordinate2D] = []
    @State private var savedPresets: [AVOSavedGeofencePreset] = []
    @State private var selectedPresetID: UUID?

    private var activeHorseName: String {
        let stable = stableStore.selectedHorseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stable.isEmpty && stable != "NO HORSE" { return stable }
        let vest = hardware.activeVestHorse.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vest.isEmpty && vest != "NO HORSE" { return vest }
        return hardware.nfcHorse
    }

    private var draftCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: Double(latitudeText.replacingOccurrences(of: ",", with: ".")) ?? settings.trainingZone.latitude,
            longitude: Double(longitudeText.replacingOccurrences(of: ",", with: ".")) ?? settings.trainingZone.longitude
        )
    }

    private var draftZone: TrainingZone {
        TrainingZone(
            name: zoneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TRAINING_ZONE" : zoneName,
            latitude: draftCoordinate.latitude,
            longitude: draftCoordinate.longitude,
            radiusMeters: radiusMeters,
            polygon: simplifiedPolygon().map { TrainingZonePoint(latitude: $0.latitude, longitude: $0.longitude) }
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.010, green: 0.014, blue: 0.016), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 8) {
                    header.frame(height: 54)

                    HStack(spacing: 10) {
                        mapEditor
                            .frame(width: geo.size.width * 0.68)
                        controlPanel
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    footer.frame(height: 34)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear { loadSavedPresets(); loadZone() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TRAINING GEOFENCE EDITOR")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Dibuja la zona con Apple Pencil o dedo. También puedes usar círculo rápido por GPS.")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            Spacer()
            pill("HORSE", activeHorseName, .green)
            pill("VEST", hardware.vestIsConnected ? "CONNECTED" : "WAITING", hardware.vestIsConnected ? .green : .orange)
            Button { onClose() } label: {
                Text("CERRAR")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var mapEditor: some View {
        ZStack(alignment: .topLeading) {
            MapReader { proxy in
                ZStack {
                    Map(position: $mapPosition) {
                        if drawnPolygon.count >= 3 {
                            MapPolygon(coordinates: simplifiedPolygon())
                                .foregroundStyle(.green.opacity(0.22))
                                .stroke(.green, lineWidth: 3)
                        } else {
                            MapCircle(center: draftCoordinate, radius: radiusMeters)
                                .foregroundStyle(.green.opacity(0.18))
                                .stroke(.green, lineWidth: 3)
                        }
                        Marker("HORSE", coordinate: hardware.externalCoordinate).tint(.red)
                        Marker(drawnPolygon.count >= 3 ? "DRAW ZONE" : "CIRCLE", coordinate: draftCoordinate).tint(.green)
                        if hardware.externalPath.count > 1 {
                            MapPolyline(coordinates: hardware.externalPath).stroke(.cyan, lineWidth: 4)
                        }
                    }
                    .mapStyle(.imagery(elevation: .realistic))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .allowsHitTesting(!drawMode)

                    if drawMode {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        guard let coordinate = proxy.convert(value.location, from: .local) else { return }
                                        appendDrawPoint(coordinate)
                                    }
                                    .onEnded { _ in updateCenterFromDrawing() }
                            )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(drawMode ? "PENCIL DRAW MODE" : "MAP MOVE MODE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(drawMode ? .green : .cyan)
                Text(drawnPolygon.count >= 3 ? "POLYGON · \(drawnPolygon.count) pts" : String(format: "CIRCLE · %.0fm", radiusMeters))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(String(format: "%.6f  %.6f", draftCoordinate.latitude, draftCoordinate.longitude))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(10)
            .background(Color.black.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(12)
        }
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.28), lineWidth: 1.2))
    }

    private var controlPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                panelTitle("GEOFENCE DATA")
                savedGeofenceSelector
                modeButtons
                labeledField("NAME", text: $zoneName)
                HStack(spacing: 8) {
                    labeledField("LAT", text: $latitudeText)
                    labeledField("LON", text: $longitudeText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("RADIUS CIRCLE FALLBACK")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.62))
                        Spacer()
                        Text("\(Int(radiusMeters)) m")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    Slider(value: $radiusMeters, in: 20...1000, step: 5)
                }
                .padding(8)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 8) {
                    actionButton("USE HORSE GPS", .cyan) { useCurrentHorseGPS() }
                    actionButton("CENTER", .green) { centerMap(on: draftCoordinate) }
                }
                HStack(spacing: 8) {
                    actionButton("SAVE APP", .green) { saveZoneOnly() }
                    actionButton("SEND VEST", .orange) { sendZoneToVest() }
                }
                HStack(spacing: 8) {
                    actionButton("SAVE PRESET", .cyan) { savePreset() }
                    actionButton("LOAD PRESET", .green) { loadSelectedPreset() }
                }

                ProBox("VEST COMMAND STATUS") {
                    VStack(alignment: .leading, spacing: 6) {
                        MiniText(name: "CONNECTION", value: hardware.vestConnectionState, color: hardware.vestIsConnected ? .green : .orange)
                        MiniText(name: "GEOFENCE", value: hardware.geofenceStatus, color: hardware.geofenceStatus.contains("SENT") ? .green : .orange)
                        MiniText(name: "TYPE", value: drawnPolygon.count >= 3 ? "FREE DRAW POLYGON" : "CIRCLE", color: drawnPolygon.count >= 3 ? .green : .orange)
                        MiniText(name: "HORSE", value: activeHorseName, color: .green)
                        MiniText(name: "APPLY", value: "Auto-send when BLE vest connects", color: .cyan)
                    }
                }
            }
        }
    }

    private var savedGeofenceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAVED GEOFENCES")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            if savedPresets.isEmpty {
                Text("No saved geofences yet. Save one to associate it with this horse.")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            } else {
                Picker("Saved geofence", selection: Binding(get: { selectedPresetID ?? savedPresets.first?.id }, set: { selectedPresetID = $0 })) {
                    ForEach(savedPresets) { preset in
                        Text("\(preset.name) · \(preset.horseId)").tag(Optional(preset.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.green)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var modeButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton(drawMode ? "DRAW ON" : "DRAW OFF", drawMode ? .green : .cyan) { drawMode.toggle() }
                actionButton("CLEAR DRAW", .red) { drawnPolygon.removeAll() }
            }
            Text("Con DRAW ON el mapa no se mueve: pintas la geocerca. Con DRAW OFF puedes mover/zoom del mapa.")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(2)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("Geocerca: \(drawnPolygon.count >= 3 ? "polígono dibujado" : "círculo") · payload preparado para chaleco · v1.2.1 build 34.")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text("RTK: \(hardware.gpsFix) · SAT: \(hardware.gpsSatellites) · PATH: \(hardware.externalPath.count)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)
        }
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.50))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadSavedPresets() {
        guard let data = UserDefaults.standard.data(forKey: "AVO_SAVED_GEOFENCE_PRESETS"),
              let presets = try? JSONDecoder().decode([AVOSavedGeofencePreset].self, from: data) else { return }
        savedPresets = presets
        selectedPresetID = presets.first?.id
    }

    private func persistSavedPresets() {
        if let data = try? JSONEncoder().encode(savedPresets) {
            UserDefaults.standard.set(data, forKey: "AVO_SAVED_GEOFENCE_PRESETS")
        }
    }

    private func savePreset() {
        let preset = AVOSavedGeofencePreset(name: draftZone.name, horseId: activeHorseName, zone: draftZone)
        savedPresets.removeAll { $0.name == preset.name && $0.horseId == preset.horseId }
        savedPresets.insert(preset, at: 0)
        if savedPresets.count > 20 { savedPresets.removeLast(savedPresets.count - 20) }
        selectedPresetID = preset.id
        persistSavedPresets()
        saveZoneOnly()
    }

    private func loadSelectedPreset() {
        guard let id = selectedPresetID, let preset = savedPresets.first(where: { $0.id == id }) else { return }
        let zone = preset.zone
        zoneName = zone.name
        latitudeText = String(format: "%.6f", zone.latitude)
        longitudeText = String(format: "%.6f", zone.longitude)
        radiusMeters = zone.radiusMeters
        drawnPolygon = zone.polygonCoordinates
        settings.trainingZone = zone
        hardware.setActiveVestHorse(preset.horseId)
        hardware.updateTrainingZonePresence(zone)
        centerMap(on: zone.coordinate)
    }

    private func loadZone() {
        zoneName = settings.trainingZone.name
        latitudeText = String(format: "%.6f", settings.trainingZone.latitude)
        longitudeText = String(format: "%.6f", settings.trainingZone.longitude)
        radiusMeters = settings.trainingZone.radiusMeters
        drawnPolygon = settings.trainingZone.polygonCoordinates
        centerMap(on: settings.trainingZone.coordinate)
        hardware.setActiveVestHorse(activeHorseName)
    }

    private func useCurrentHorseGPS() {
        latitudeText = String(format: "%.6f", hardware.externalCoordinate.latitude)
        longitudeText = String(format: "%.6f", hardware.externalCoordinate.longitude)
        centerMap(on: hardware.externalCoordinate)
    }

    private func saveZoneOnly() {
        let zone = draftZone
        settings.trainingZone = zone
        hardware.geofenceStatus = "GEOFENCE SAVED APP · SENDING SERVER"
        hardware.setActiveVestHorse(activeHorseName)
        hardware.updateTrainingZonePresence(zone)
        hardware.saveTrainingZoneToServer(zone, horseName: activeHorseName)
    }

    private func sendZoneToVest() {
        let zone = draftZone
        settings.trainingZone = zone
        hardware.setActiveVestHorse(activeHorseName)
        hardware.updateTrainingZonePresence(zone)
        hardware.saveTrainingZoneToServer(zone, horseName: activeHorseName)
        hardware.sendTrainingZone(zone, horseName: activeHorseName)
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        mapPosition = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)))
    }

    private func appendDrawPoint(_ coordinate: CLLocationCoordinate2D) {
        if let last = drawnPolygon.last {
            let a = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let b = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if a.distance(from: b) < 2 { return }
        }
        drawnPolygon.append(coordinate)
        if drawnPolygon.count > 450 { drawnPolygon.removeFirst(drawnPolygon.count - 450) }
    }

    private func simplifiedPolygon() -> [CLLocationCoordinate2D] {
        guard drawnPolygon.count > 80 else { return drawnPolygon }
        let step = max(1, drawnPolygon.count / 80)
        return drawnPolygon.enumerated().compactMap { index, coordinate in index % step == 0 ? coordinate : nil }
    }

    private func updateCenterFromDrawing() {
        let poly = simplifiedPolygon()
        guard poly.count >= 3 else { return }
        let lat = poly.map(\.latitude).reduce(0, +) / Double(poly.count)
        let lon = poly.map(\.longitude).reduce(0, +) / Double(poly.count)
        latitudeText = String(format: "%.6f", lat)
        longitudeText = String(format: "%.6f", lon)
    }

    private func pill(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.58))
            Text(value).font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(color).lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(color.opacity(0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func panelTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(.green)
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.58))
            TextField(label, text: text)
                .textInputAutocapitalization(.characters)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.black.opacity(0.62))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    private func actionButton(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
