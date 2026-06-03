
import SwiftUI
import UIKit

struct AVOProfilesFullPage: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var profiles: ProfileStore
    @ObservedObject var stableStore: AVOStableStore
    @ObservedObject var hardware: AVOHardwareReceiver

    @State private var selectedTab: AVOProfileTab = .horse
    @State private var horseNameDraft = ""
    @State private var horseAgeDraft = ""
    @State private var horseBreedDraft = ""
    @State private var horseRaceDraft = ""
    @State private var horseModeDraft = ""
    @State private var horseHeightDraft = "1.55"
    @State private var horseWeightDraft = "460"
    @State private var horseNotesDraft = ""

    @State private var riderNameDraft = ""
    @State private var riderLevelDraft = ""
    @State private var riderWeightDraft = ""
    @State private var riderNotesDraft = ""

    enum AVOProfileTab: String {
        case horse = "HORSE PROFILES"
        case rider = "RIDER PROFILES"
    }

    private var selectedHorse: HorseProfile {
        if profiles.horses.indices.contains(profiles.selectedHorseIndex) {
            return profiles.horses[profiles.selectedHorseIndex]
        }
        return HorseProfile(name: "NO HORSE", age: 0, breed: "--", notes: "")
    }

    private var selectedRider: RiderProfile {
        if profiles.riders.indices.contains(profiles.selectedRiderIndex) {
            return profiles.riders[profiles.selectedRiderIndex]
        }
        return RiderProfile(name: "NO RIDER", level: "--", weight: 0, notes: "")
    }

    private var linkedSessionsCount: Int {
        stableStore.selectedSessions.count
    }

    private var linkedVetCount: Int {
        stableStore.selectedVetRecords.count
    }

    private var avgRisk: Double {
        let values = stableStore.selectedSessions.map { $0.avgRisk }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var lastSessionText: String {
        if let date = stableStore.selectedSessions.first?.date {
            return AVOProfilesFullPage.shortDate(date)
        }
        return "--"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    header

                    VStack(spacing: 10) {
                        tabBar

                        HStack(spacing: 10) {
                            profileList
                                .frame(width: max(260, geo.size.width * 0.22))

                            if selectedTab == .horse {
                                horseMainCard
                                    .frame(maxWidth: .infinity)
                            } else {
                                riderMainCard
                                    .frame(maxWidth: .infinity)
                            }

                            quickInfo
                                .frame(width: max(230, geo.size.width * 0.19))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        bottomActions
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.035))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.18), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            stableStore.loadIndex()
            AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: true)
            loadDrafts()
        }
    }

    private var header: some View {
        AVOUnifiedPageHeader(
            title: "Profiles",
            subtitle: "Caballo / jinete · stable · NFC · sesiones reales",
            status: profiles.profileStatus,
            accent: .green,
            onClose: { dismiss() }
        ) {
            AVOUnifiedHeaderActionButton(title: "SYNC", color: .cyan) {
                profiles.loadProfiles()
                stableStore.loadIndex()
                AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: true)
                loadDrafts()
            }
        }
    }


    private var tabBar: some View {
        HStack(spacing: 12) {
            profileTabButton(.horse)
            profileTabButton(.rider)
            Spacer()
            Text(profiles.profileStatus.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.green)
        }
        .padding(10)
        .background(Color.black.opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.15), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func profileTabButton(_ tab: AVOProfileTab) -> some View {
        Button {
            selectedTab = tab
            loadDrafts()
        } label: {
            Text(tab.rawValue)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(selectedTab == tab ? .green : .white.opacity(0.75))
                .frame(width: 210, height: 38)
                .background(selectedTab == tab ? Color.green.opacity(0.14) : Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedTab == tab ? Color.green.opacity(0.65) : Color.white.opacity(0.10), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var profileList: some View {
        AVOProfilesBox(title: selectedTab == .horse ? "HORSE INDEX" : "RIDER INDEX", accent: .green) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    if selectedTab == .horse {
                        profiles.newHorse()
                    } else {
                        profiles.newRider()
                    }
                    profiles.saveProfiles()
                    loadDrafts()
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text(selectedTab == .horse ? "NEW HORSE" : "NEW RIDER")
                    }
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.green.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.55), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                ScrollView {
                    VStack(spacing: 8) {
                        if selectedTab == .horse {
                            ForEach(Array(profiles.horses.enumerated()), id: \.offset) { index, horse in
                                Button {
                                    AVOAppDataSync.selectHorseFromProfiles(index: index, profiles: profiles, stableStore: stableStore)
                                    loadDrafts()
                                } label: {
                                    profileListRow(
                                        title: horse.name.uppercased(),
                                        subtitle: "\(horse.age)y · \(horse.breed) · \(horse.notes.isEmpty ? "--" : horse.notes)",
                                        active: index == profiles.selectedHorseIndex
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            ForEach(Array(profiles.riders.enumerated()), id: \.offset) { index, rider in
                                Button {
                                    profiles.selectedRiderIndex = index
                                    UserDefaults.standard.set(index, forKey: "AVOUnifiedSelectedRiderIndexV1")
                                    AVOAppDataSync.publishActiveHorse(name: profiles.horseName, riderName: profiles.riderName)
                                    loadDrafts()
                                } label: {
                                    profileListRow(
                                        title: rider.name.uppercased(),
                                        subtitle: "\(rider.level) · \(Int(rider.weight)) kg · \(rider.notes.isEmpty ? "--" : rider.notes)",
                                        active: index == profiles.selectedRiderIndex
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func profileListRow(title: String, subtitle: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(active ? .green : .white)

            Text(subtitle)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(active ? .cyan : .white.opacity(0.52))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(active ? Color.green.opacity(0.22) : Color.black.opacity(0.34))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color.green.opacity(0.45) : Color.white.opacity(0.07), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var horseMainCard: some View {
        AVOProfilesBox(title: "HORSE PROFILE", accent: .cyan) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    profileLine("NAME", horseNameDraft.uppercased())
                    editableField("NAME", text: $horseNameDraft)

                    profileLine("AGE", "\(selectedHorse.age) years")
                    editableField("AGE", text: $horseAgeDraft)

                    profileLine("SEX", stableStore.selectedHorseProfile?.sex.rawValue ?? "Sin definir")
                    profileLine("BREED", selectedHorse.breed.uppercased())
                    editableField("BREED", text: $horseBreedDraft)

                    profileLine("RACE", horseRaceDraft.isEmpty ? "Semental" : horseRaceDraft)
                    editableField("RACE", text: $horseRaceDraft)

                    profileLine("MODALITY", horseModeDraft.isEmpty ? "Tira" : horseModeDraft)
                    editableField("MODALITY", text: $horseModeDraft)

                    HStack(spacing: 10) {
                        profileLine("HEIGHT", horseHeightDraft + " m")
                        profileLine("WEIGHT", horseWeightDraft + " kg")
                    }

                    editableField("NOTES", text: $horseNotesDraft)

                    Text(horseNotesDraft.isEmpty ? "Caballo conectado al módulo Stable y sesiones biomecánicas." : horseNotesDraft)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                }

                VStack(spacing: 10) {
                    profilePhotoBox
                        .frame(width: 260, height: 240)

                    Button {
                        stableStore.openRootFolder()
                    } label: {
                        AVOProfilesButtonText("CHANGE PHOTO", .cyan)
                    }
                }
                .frame(width: 280)
            }
        }
    }

    private var riderMainCard: some View {
        AVOProfilesBox(title: "RIDER PROFILE", accent: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                profileLine("NAME", riderNameDraft.uppercased())
                editableField("NAME", text: $riderNameDraft)

                profileLine("LEVEL", riderLevelDraft.uppercased())
                editableField("LEVEL", text: $riderLevelDraft)

                profileLine("WEIGHT", riderWeightDraft + " kg")
                editableField("WEIGHT", text: $riderWeightDraft)

                profileLine("NFC RIDER ID", hardware.nfcRider)
                editableField("NOTES", text: $riderNotesDraft)

                Text(riderNotesDraft.isEmpty ? "Jinete enlazado a sesiones, telemetría y perfiles NFC." : riderNotesDraft)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(3)

                Spacer()
            }
        }
    }

    private var profilePhotoBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.45))

            if let image = selectedStableImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                LinearGradient(colors: [Color(red: 0.18, green: 0.12, blue: 0.06), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Image(systemName: "hare.fill")
                    .font(.system(size: 70, weight: .black))
                    .foregroundColor(.white.opacity(0.32))

                Text("PHOTO")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .offset(y: 76)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
    }

    private var quickInfo: some View {
        AVOProfilesBox(title: "QUICK INFO", accent: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                quickMetric(title: "SESSIONS", value: "\(linkedSessionsCount)", color: .orange)
                quickMetric(title: "LAST SESSION", value: lastSessionText, color: .white)
                quickMetric(title: "VET RECORDS", value: "\(linkedVetCount)", color: .orange)
                quickMetric(title: "AVG RISK", value: "\(Int(avgRisk * 100))%", color: avgRisk > 0.50 ? .red : .orange)
                quickMetric(title: "NFC HORSE", value: hardware.nfcHorse, color: .green)
                quickMetric(title: "STATUS", value: "ACTIVE", color: .green)
                Spacer()
            }
        }
    }

    private func quickMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.68))

            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                profiles.loadProfiles()
                stableStore.loadIndex()
                AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: true)
                loadDrafts()
            } label: {
                AVOProfilesButtonText("IMPORT", .cyan)
            }

            Button {
                profiles.saveProfiles()
            } label: {
                AVOProfilesButtonText("EXPORT ALL", .cyan)
            }

            Spacer()

            Button {
                saveCurrentDraft()
            } label: {
                AVOProfilesButtonText("EDIT", .green)
            }

            Button {
                duplicateCurrent()
            } label: {
                AVOProfilesButtonText("DUPLICATE", .cyan)
            }

            Button {
                if selectedTab == .horse {
                    profiles.deleteSelectedHorse()
                } else {
                    profiles.deleteSelectedRider()
                }
                profiles.saveProfiles()
                loadDrafts()
            } label: {
                AVOProfilesButtonText("DELETE", .red)
            }
        }
        .padding(.top, 4)
    }

    private func profileLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.68))
                .frame(width: 145, alignment: .leading)

            Text(value.isEmpty ? "--" : value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()
        }
    }

    private func editableField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 330)
    }

    private func loadDrafts() {
        let horse = selectedHorse
        horseNameDraft = horse.name
        horseAgeDraft = "\(horse.age)"
        horseBreedDraft = horse.breed
        horseRaceDraft = stableStore.selectedHorseProfile?.breed ?? horse.breed
        horseModeDraft = stableStore.selectedHorseProfile?.competitionMode ?? "Tira"
        horseNotesDraft = horse.notes

        let rider = selectedRider
        riderNameDraft = rider.name
        riderLevelDraft = rider.level
        riderWeightDraft = String(format: "%.0f", rider.weight)
        riderNotesDraft = rider.notes
    }

    private func saveCurrentDraft() {
        if selectedTab == .horse {
            profiles.updateSelectedHorse(
                name: horseNameDraft,
                ageText: horseAgeDraft,
                breed: horseBreedDraft,
                notes: horseNotesDraft
            )
        } else {
            profiles.updateSelectedRider(
                name: riderNameDraft,
                level: riderLevelDraft,
                weightText: riderWeightDraft,
                notes: riderNotesDraft
            )
        }
        profiles.saveProfiles()
        AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: selectedTab == .horse ? false : true)
        loadDrafts()
    }

    private func duplicateCurrent() {
        if selectedTab == .horse {
            let horse = selectedHorse
            profiles.horses.append(HorseProfile(name: horse.name + " COPY", age: horse.age, breed: horse.breed, notes: horse.notes))
            profiles.selectedHorseIndex = profiles.horses.count - 1
        } else {
            let rider = selectedRider
            profiles.riders.append(RiderProfile(name: rider.name + " COPY", level: rider.level, weight: rider.weight, notes: rider.notes))
            profiles.selectedRiderIndex = profiles.riders.count - 1
        }
        profiles.saveProfiles()
        AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: selectedTab == .horse ? false : true)
        loadDrafts()
    }

    private func selectedStableImage() -> UIImage? {
        guard let profile = stableStore.selectedHorseProfile,
              let rel = profile.photoRelativePath,
              let item = stableStore.horsesIndex.first(where: { $0.id == profile.id }),
              let root = stableStore.rootFolderURL else {
            return nil
        }
        let url = root.appendingPathComponent("Horses").appendingPathComponent(item.folderName).appendingPathComponent(rel)
        return UIImage(contentsOfFile: url.path)
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy HH:mm"
        return f.string(from: date)
    }
}

struct AVOProfilesBox<Content: View>: View {
    var title: String
    var accent: Color
    @ViewBuilder var content: Content

    init(title: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.01, green: 0.025, blue: 0.03).opacity(0.92))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AVOProfilesButtonText: View {
    var title: String
    var color: Color

    init(_ title: String, _ color: Color) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .foregroundColor(color == .yellow ? .black : .white)
            .frame(minWidth: 115)
            .frame(height: 44)
            .background(color.opacity(color == .red ? 0.82 : 0.72))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.9), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
