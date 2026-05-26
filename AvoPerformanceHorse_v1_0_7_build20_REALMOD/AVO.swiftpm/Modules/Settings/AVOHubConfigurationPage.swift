
import SwiftUI

struct AVOHubConfigurationPage: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("avoHubShowToolDock") private var showToolDock = true
    @AppStorage("avoHubShowBottomBar") private var showBottomBar = true
    @AppStorage("avoHubShowLowerTelemetry") private var showLowerTelemetry = true
    @AppStorage("avoHubShowFloatingRecord") private var showFloatingRecord = false
    @AppStorage("avoHubShowTopGate") private var showTopGate = false

    @AppStorage("avoHubShowHorseBox") private var showHorseBox = true
    @AppStorage("avoHubShowSkeleton") private var showSkeleton = true
    @AppStorage("avoHubShowJoints") private var showJoints = true
    @AppStorage("avoHubShowTrails") private var showTrails = true
    @AppStorage("avoHubShowRiderPoints") private var showRiderPoints = true
    @AppStorage("avoHubShowOverlayText") private var showOverlayText = true
    @AppStorage("avoHubShowBodyMap") private var showBodyMap = true
    @AppStorage("avoHubShowVetAlerts") private var showVetAlerts = true

    @AppStorage("avoHubShowInfoPanel") private var showInfoPanel = false
    @AppStorage("avoHubShowTrackingPanel") private var showTrackingPanel = false
    @AppStorage("avoHubAutoClean") private var autoClean = true
    @AppStorage("avoHubDimPanels") private var dimPanels = true

    @AppStorage("avoHubMetricGait") private var metricGait = true
    @AppStorage("avoHubMetricAsym") private var metricAsym = true
    @AppStorage("avoHubMetricRisk") private var metricRisk = true
    @AppStorage("avoHubMetricFatigue") private var metricFatigue = true
    @AppStorage("avoHubMetricQuality") private var metricQuality = true
    @AppStorage("avoHubMetricHR") private var metricHR = true
    @AppStorage("avoHubMetricSpeed") private var metricSpeed = true
    @AppStorage("avoHubMetricStride") private var metricStride = true

    @AppStorage("avoHubButtonClient") private var buttonClient = true
    @AppStorage("avoHubButtonAuto") private var buttonAuto = true
    @AppStorage("avoHubButtonSlow") private var buttonSlow = true
    @AppStorage("avoHubButtonSnap") private var buttonSnap = true
    @AppStorage("avoHubButtonData") private var buttonData = true
    @AppStorage("avoHubButtonReview") private var buttonReview = true
    @AppStorage("avoHubButtonExport") private var buttonExport = true
    @AppStorage("avoHubButtonExports") private var buttonExports = true
    @AppStorage("avoHubButtonSave") private var buttonSave = true
    @AppStorage("avoHubButtonLock") private var buttonLock = true

    @AppStorage("avoHubDockPoints") private var dockPoints = true
    @AppStorage("avoHubDockRec") private var dockRec = true
    @AppStorage("avoHubDockAuto") private var dockAuto = true
    @AppStorage("avoHubDockTrack") private var dockTrack = true
    @AppStorage("avoHubDockInfo") private var dockInfo = true
    @AppStorage("avoHubDockHUD") private var dockHUD = true
    @AppStorage("avoHubDockHeat") private var dockHeat = true
    @AppStorage("avoHubDockLock") private var dockLock = true
    @AppStorage("avoHubDockCam") private var dockCam = true
    @AppStorage("avoHubDockSettings") private var dockSettings = true

    @AppStorage("avoHubStatusRSSI") private var statusRSSI = true
    @AppStorage("avoHubStatusConnection") private var statusConnection = true
    @AppStorage("avoHubStatusFrequency") private var statusFrequency = true
    @AppStorage("avoHubStatusRecMode") private var statusRecMode = true
    @AppStorage("avoHubStatusLiDAR") private var statusLiDAR = true
    @AppStorage("avoHubStatusDataset") private var statusDataset = true
    @AppStorage("avoHubStatusAlert") private var statusAlert = true

    @AppStorage("biotech_show_phase133_rec_panel") private var biotechRecPanel = false
    @AppStorage("biotech_show_selected_horse_header") private var biotechHorseHeader = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 10) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        section("BIOTECH VISUAL") {
                            toggleRow("Caballo activo superior", "Solo una pastilla compacta arriba a la derecha en Biotech.", isOn: $biotechHorseHeader)
                            toggleRow("Panel REC V4 flotante", "REC CLIENT / REC BIOMECH / DATA. Por defecto oculto; se abre también desde el botón REC lateral.", isOn: $biotechRecPanel)
                        }

                        section("GENERAL HUB") {
                            toggleRow("Dock lateral del hub", "Botones PUNTOS, REC, AUTO, TRACK, INFO, HUD...", isOn: $showToolDock)
                            toggleRow("Barra inferior principal", "RSSI, conexión, frecuencia, REC MODE, LiDAR y acciones.", isOn: $showBottomBar)
                            toggleRow("Telemetría inferior", "GAIT, ASYM, RISK, FATIGUE, QUALITY, HR, SPEED, STRIDE.", isOn: $showLowerTelemetry)
                            toggleRow("Panel flotante de REC", "Panel cliente/slow/auto cuando se abre desde REC.", isOn: $showFloatingRecord)
                            toggleRow("Badge superior Gate/Body/AI", "Resumen superior de tracking, persistencia y biomecánica.", isOn: $showTopGate)
                            toggleRow("Auto Clean HUD", "Oculta paneles no críticos para dejar más cámara libre.", isOn: $autoClean)
                            toggleRow("Paneles transparentes", "Reduce opacidad visual de los paneles.", isOn: $dimPanels)
                        }

                        section("OVERLAY ANATÓMICO") {
                            toggleRow("Caja del caballo", "Rectángulo principal de lock del caballo.", isOn: $showHorseBox)
                            toggleRow("Esqueleto anatómico", "Líneas entre articulaciones.", isOn: $showSkeleton)
                            toggleRow("Puntos articulares", "Círculos sobre cada joint detectado.", isOn: $showJoints)
                            toggleRow("Trazas temporales", "Historial corto de movimiento por articulación.", isOn: $showTrails)
                            toggleRow("Puntos del jinete", "Puntos azules de rider pose.", isOn: $showRiderPoints)
                            toggleRow("Texto técnico del overlay", "Estado POSE, TRACK, GATE, BODY, AI.", isOn: $showOverlayText)
                            toggleRow("Body Map biomecánico", "Heatmap corporal por riesgo, fatiga y estabilidad.", isOn: $showBodyMap)
                            toggleRow("Alertas veterinarias IA", "Badge superior con riesgo biomecánico y sospecha.", isOn: $showVetAlerts)
                        }

                        section("PANELES DESPLEGABLES") {
                            toggleRow("Panel INFO permitido", "Modo, caballo, sesión, Auto REC, LiDAR, calidad.", isOn: $showInfoPanel)
                            toggleRow("Panel TRACK permitido", "Pose, joints, Gate, orientación, fase, AI.", isOn: $showTrackingPanel)
                        }

                        section("MÉTRICAS TELEMETRÍA") {
                            toggleRow("GAIT", "Marcha estimada.", isOn: $metricGait)
                            toggleRow("ASYM", "Asimetría global.", isOn: $metricAsym)
                            toggleRow("RISK", "Riesgo actual.", isOn: $metricRisk)
                            toggleRow("FATIGUE", "Fatiga.", isOn: $metricFatigue)
                            toggleRow("QUALITY", "Calidad tracking.", isOn: $metricQuality)
                            toggleRow("HR", "Pulso externo/BLE.", isOn: $metricHR)
                            toggleRow("SPEED", "Velocidad.", isOn: $metricSpeed)
                            toggleRow("STRIDE", "Zancada.", isOn: $metricStride)
                        }

                        section("BOTONES BARRA INFERIOR") {
                            toggleRow("CLIENT REC", "Grabación normal para clientes.", isOn: $buttonClient)
                            toggleRow("AUTO REC", "Grabación automática seleccionable.", isOn: $buttonAuto)
                            toggleRow("SLOW", "Grabación slowmotion biomecánica.", isOn: $buttonSlow)
                            toggleRow("SNAP", "Captura instantánea.", isOn: $buttonSnap)
                            toggleRow("DATA", "Dataset auto ON/OFF.", isOn: $buttonData)
                            toggleRow("REVIEW", "Abrir revisión dataset.", isOn: $buttonReview)
                            toggleRow("EXPORT", "Exportar dataset.", isOn: $buttonExport)
                            toggleRow("EXPORTS", "Abrir exportaciones.", isOn: $buttonExports)
                            toggleRow("SAVE", "Guardar sesión.", isOn: $buttonSave)
                            toggleRow("LOCK", "Bloquear/desbloquear modo.", isOn: $buttonLock)
                        }

                        section("BOTONES DOCK LATERAL") {
                            toggleRow("PUNTOS", "Mostrar/ocultar badge superior.", isOn: $dockPoints)
                            toggleRow("REC", "Abrir/ocultar panel REC.", isOn: $dockRec)
                            toggleRow("AUTO", "Activar/desactivar Auto REC.", isOn: $dockAuto)
                            toggleRow("TRACK", "Abrir/ocultar panel Tracking.", isOn: $dockTrack)
                            toggleRow("INFO", "Abrir/ocultar panel Info.", isOn: $dockInfo)
                            toggleRow("HUD", "Abrir/ocultar badge HUD.", isOn: $dockHUD)
                            toggleRow("HEAT", "Acceso a heatmap/tracking.", isOn: $dockHeat)
                            toggleRow("LOCK", "Bloqueo objeto.", isOn: $dockLock)
                            toggleRow("CAM", "Cambio cámara.", isOn: $dockCam)
                            toggleRow("SET", "Config rápida.", isOn: $dockSettings)
                        }

                        section("ESTADO INFERIOR") {
                            toggleRow("RSSI", "Potencia/enlace.", isOn: $statusRSSI)
                            toggleRow("CONNECTION", "Tipo de conexión.", isOn: $statusConnection)
                            toggleRow("FREQUENCY", "Frecuencia de datos.", isOn: $statusFrequency)
                            toggleRow("REC MODE", "Modo de grabación.", isOn: $statusRecMode)
                            toggleRow("LiDAR", "Estado LiDAR.", isOn: $statusLiDAR)
                            toggleRow("DATASET", "Estado dataset.", isOn: $statusDataset)
                            toggleRow("ALERT", "Alerta veterinaria/IA.", isOn: $statusAlert)
                        }

                        section("ACCIONES RÁPIDAS") {
                            Button { enableEssential() } label: { actionButton("MODO LIMPIO ESENCIAL", .green) }
                            Button { enableAll() } label: { actionButton("ACTIVAR TODO", .cyan) }
                            Button { hideVisualOverlays() } label: { actionButton("OCULTAR OVERLAYS VISUALES", .orange) }
                            Button { disableAll() } label: { actionButton("DESACTIVAR TODO", .red) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
            .padding(14)
        }
    }

    private var header: some View {
        AVOUnifiedPageHeader(
            title: "Configuración Hub",
            subtitle: "Activa/desactiva funciones visuales y operativas del Hub Biomech",
            status: "HUB CONFIG",
            accent: .green,
            onClose: { dismiss() }
        ) {
            EmptyView()
        }
    }


    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(.green)
                .font(.system(size: 15, weight: .black, design: .monospaced))
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                Text(subtitle)
                    .foregroundColor(.gray)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .lineLimit(2)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .green))
        .padding(.vertical, 5)
    }

    private func actionButton(_ title: String, _ color: Color) -> some View {
        Text(title)
            .foregroundColor(color == .yellow ? .black : .black)
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(color.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func enableEssential() {
        showToolDock = true
        showBottomBar = true
        showLowerTelemetry = true
        showFloatingRecord = false
        showTopGate = false
        biotechHorseHeader = true
        biotechRecPanel = false
        showHorseBox = true
        showSkeleton = true
        showJoints = true
        showTrails = false
        showRiderPoints = false
        showOverlayText = false
        showBodyMap = true
        showVetAlerts = true
        autoClean = true
        dimPanels = true
    }

    private func enableAll() {
        for set in [
            { showToolDock = true }, { showBottomBar = true }, { showLowerTelemetry = true }, { showFloatingRecord = true }, { showTopGate = true }, { biotechHorseHeader = true }, { biotechRecPanel = true },
            { showHorseBox = true }, { showSkeleton = true }, { showJoints = true }, { showTrails = true }, { showRiderPoints = true }, { showOverlayText = true }, { showBodyMap = true }, { showVetAlerts = true },
            { showInfoPanel = true }, { showTrackingPanel = true }, { autoClean = true }, { dimPanels = true },
            { metricGait = true }, { metricAsym = true }, { metricRisk = true }, { metricFatigue = true }, { metricQuality = true }, { metricHR = true }, { metricSpeed = true }, { metricStride = true },
            { buttonClient = true }, { buttonAuto = true }, { buttonSlow = true }, { buttonSnap = true }, { buttonData = true }, { buttonReview = true }, { buttonExport = true }, { buttonExports = true }, { buttonSave = true }, { buttonLock = true },
            { dockPoints = true }, { dockRec = true }, { dockAuto = true }, { dockTrack = true }, { dockInfo = true }, { dockHUD = true }, { dockHeat = true }, { dockLock = true }, { dockCam = true }, { dockSettings = true },
            { statusRSSI = true }, { statusConnection = true }, { statusFrequency = true }, { statusRecMode = true }, { statusLiDAR = true }, { statusDataset = true }, { statusAlert = true }
        ] { set() }
    }

    private func hideVisualOverlays() {
        showHorseBox = false
        showSkeleton = false
        showJoints = false
        showTrails = false
        showRiderPoints = false
        showOverlayText = false
        showBodyMap = false
        showVetAlerts = false
        showTopGate = false
        showFloatingRecord = false
        biotechRecPanel = false
        showInfoPanel = false
        showTrackingPanel = false
    }

    private func disableAll() {
        showToolDock = false
        showBottomBar = false
        showLowerTelemetry = false
        biotechHorseHeader = false
        biotechRecPanel = false
        showFloatingRecord = false
        showTopGate = false
        showHorseBox = false
        showSkeleton = false
        showJoints = false
        showTrails = false
        showRiderPoints = false
        showOverlayText = false
        showBodyMap = false
        showVetAlerts = false
        showInfoPanel = false
        showTrackingPanel = false
    }
}
