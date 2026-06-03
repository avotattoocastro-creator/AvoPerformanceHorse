import Foundation
import SwiftUI

// MARK: - AVO APP DATA SYNC
// Single bridge that keeps PROFILES, STABLE, BIOTECH, HARDWARE and RECORDING using the same active horse/rider.

@MainActor
enum AVOAppDataSync {
    static let noHorseNames: Set<String> = [
        "", "NO HORSE", "NO HORSE SELECTED", "SIN_CABALLO", "SIN CABALLO", "NO_HORSE", "NO HORSE SELECTED"
    ]

    static func syncAll(profiles: ProfileStore,
                        stableStore: AVOStableStore,
                        riderName: String? = nil,
                        preferStable: Bool = true) {
        if preferStable, let stableProfile = stableStore.selectedHorseProfile, !isEmptyHorse(stableProfile.name) {
            profiles.selectOrCreateLegacyHorse(from: stableProfile)
            publishActiveStableHorse(profile: stableProfile, stableStore: stableStore, riderName: riderName ?? profiles.riderName)
            profiles.profileStatus = "SYNC STABLE → APP"
            return
        }

        let legacy = profiles.currentHorseProfile
        if !isEmptyHorse(legacy.name) {
            stableStore.selectOrCreateHorse(from: legacy)
            if let stableProfile = stableStore.selectedHorseProfile {
                publishActiveStableHorse(profile: stableProfile, stableStore: stableStore, riderName: riderName ?? profiles.riderName)
            } else {
                publishActiveHorse(name: legacy.name, riderName: riderName ?? profiles.riderName)
            }
            profiles.profileStatus = "SYNC PROFILES → APP"
            return
        }

        publishActiveHorse(name: "SIN_CABALLO", riderName: riderName ?? profiles.riderName)
        profiles.profileStatus = "NO HORSE SELECTED"
    }

    static func selectHorseFromProfiles(index: Int,
                                        profiles: ProfileStore,
                                        stableStore: AVOStableStore) {
        profiles.selectHorseIndex(index)
        let horse = profiles.currentHorseProfile
        if !isEmptyHorse(horse.name) {
            stableStore.selectOrCreateHorse(from: horse)
            if let stableProfile = stableStore.selectedHorseProfile {
                publishActiveStableHorse(profile: stableProfile, stableStore: stableStore, riderName: profiles.riderName)
            } else {
                publishActiveHorse(name: horse.name, riderName: profiles.riderName)
            }
            profiles.profileStatus = "ACTIVE HORSE LINKED"
        }
    }

    static func selectHorseFromStable(id: UUID,
                                      profiles: ProfileStore,
                                      stableStore: AVOStableStore) {
        stableStore.loadHorse(id: id)
        if let profile = stableStore.selectedHorseProfile {
            profiles.selectOrCreateLegacyHorse(from: profile)
            publishActiveStableHorse(profile: profile, stableStore: stableStore, riderName: profiles.riderName)
            profiles.profileStatus = "ACTIVE HORSE LINKED"
        }
    }


    static func publishActiveStableHorse(profile: StableHorseProfile,
                                         stableStore: AVOStableStore,
                                         riderName: String) {
        let folderName = stableStore.folderNameForSelectedHorse()
        let horse = cleanHorseName(profile.name)
        AVOMasterSessionCore.shared.setActiveHorse(name: horse, id: profile.id, stableRoot: stableStore.rootFolderURL, stableFolderName: folderName)
        if BiotechHorseSessionRecorder.shared.selectedHorseName != horse {
            BiotechHorseSessionRecorder.shared.setSelectedHorse(horse)
        }
        if AVOHardwareTelemetryHub.shared.selectedHorseName != horse {
            AVOHardwareTelemetryHub.shared.selectHorse(name: horse)
        }
        let rider = riderName.isEmpty ? "SIN_JINETE" : riderName
        if AVOHardwareTelemetryHub.shared.selectedRiderId != rider {
            AVOHardwareTelemetryHub.shared.selectRider(id: rider)
        }
        AVOSystemDataBus.shared.lastSystemMessage = "ACTIVE HORSE -> \(horse)"
        AVOSystemDataBus.shared.lastUpdatedAt = Date()
    }

    static func publishActiveHorse(name: String, riderName: String) {
        let horse = cleanHorseName(name)
        AVOMasterSessionCore.shared.setActiveHorse(name: horse)
        if BiotechHorseSessionRecorder.shared.selectedHorseName != horse {
            BiotechHorseSessionRecorder.shared.setSelectedHorse(horse)
        }
        if AVOHardwareTelemetryHub.shared.selectedHorseName != horse {
            AVOHardwareTelemetryHub.shared.selectHorse(name: horse)
        }
        let rider = riderName.isEmpty ? "SIN_JINETE" : riderName
        if AVOHardwareTelemetryHub.shared.selectedRiderId != rider {
            AVOHardwareTelemetryHub.shared.selectRider(id: rider)
        }
        AVOSystemDataBus.shared.lastSystemMessage = "ACTIVE HORSE -> \(horse)"
        AVOSystemDataBus.shared.lastUpdatedAt = Date()
    }

    static func isEmptyHorse(_ name: String) -> Bool {
        noHorseNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    static func cleanHorseName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return isEmptyHorse(trimmed) ? "SIN_CABALLO" : trimmed
    }
}

@MainActor
extension ProfileStore {
    var currentHorseProfile: HorseProfile {
        if horses.indices.contains(selectedHorseIndex) { return horses[selectedHorseIndex] }
        return HorseProfile(name: "NO HORSE SELECTED", age: 0, breed: "", notes: "")
    }

    func selectHorseIndex(_ index: Int) {
        guard horses.indices.contains(index) else { return }
        selectedHorseIndex = index
        UserDefaults.standard.set(index, forKey: "AVOUnifiedSelectedHorseIndexV1")
        profileStatus = "HORSE SELECTED"
    }

    func selectOrCreateLegacyHorse(from stable: StableHorseProfile) {
        let target = stable.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !AVOAppDataSync.isEmptyHorse(target) else { return }

        if let idx = horses.firstIndex(where: { $0.name.caseInsensitiveCompare(target) == .orderedSame }) {
            selectedHorseIndex = idx
            horses[idx] = HorseProfile(name: stable.name, age: max(0, Calendar.current.dateComponents([.year], from: stable.birthDate, to: Date()).year ?? 0), breed: stable.breed, notes: stable.notes)
        } else {
            horses.append(HorseProfile(name: stable.name, age: max(0, Calendar.current.dateComponents([.year], from: stable.birthDate, to: Date()).year ?? 0), breed: stable.breed, notes: stable.notes))
            selectedHorseIndex = horses.count - 1
        }
        UserDefaults.standard.set(selectedHorseIndex, forKey: "AVOUnifiedSelectedHorseIndexV1")
        saveProfiles()
    }
}

@MainActor
extension AVOStableStore {
    func selectOrCreateHorse(from legacy: HorseProfile) {
        let name = legacy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !AVOAppDataSync.isEmptyHorse(name) else { return }

        if let existing = horsesIndex.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            loadHorse(id: existing.id)
            UserDefaults.standard.set(existing.id.uuidString, forKey: "AVOUnifiedSelectedStableHorseIDV1")
            return
        }

        let birth = Calendar.current.date(byAdding: .year, value: -max(0, legacy.age), to: Date()) ?? Date()
        createHorse(name: name, birthDate: birth, sex: .unknown, breed: legacy.breed, competitionMode: "Tira", notes: legacy.notes)
        if let id = selectedHorseID {
            UserDefaults.standard.set(id.uuidString, forKey: "AVOUnifiedSelectedStableHorseIDV1")
        }
    }
}


@MainActor
extension AVOStableStore {
    func folderNameForSelectedHorse() -> String? {
        guard let id = selectedHorseID else { return nil }
        return horsesIndex.first(where: { $0.id == id })?.folderName
    }
}
