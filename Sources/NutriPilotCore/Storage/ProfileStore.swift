import Foundation
import SwiftUI
import Observation

@Observable
public final class ProfileStore: @unchecked Sendable {
    public static let shared = ProfileStore()

    public var currentProfile: UserProfile?
    public var currentTarget: NutritionTarget?
    public var hasCompletedOnboarding: Bool = false

    private let fileManager = FileManager.default
    private let fileName = "nutripilot_profile_v1.json"
    private let customStorageURL: URL?

    public init(storageURL: URL? = nil) {
        self.customStorageURL = storageURL
        loadProfile()
    }

    private var storageURL: URL {
        if let custom = customStorageURL {
            return custom
        }
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("NutriPilot", isDirectory: true)

        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }

        return appSupportDir.appendingPathComponent(fileName)
    }

    public func saveProfile(_ profile: UserProfile, target: NutritionTarget? = nil) {
        self.currentProfile = profile

        // Se target não fornecido, calcula automaticamente pelo NutritionCalculator
        if let target = target {
            self.currentTarget = target
        } else {
            let calculation = NutritionCalculator.calculateFullTarget(from: profile)
            self.currentTarget = NutritionTarget(
                calories: calculation.targetCalories,
                proteinGrams: calculation.targetProteinGrams,
                carbsGrams: calculation.targetCarbsGrams,
                fatGrams: calculation.targetFatGrams,
                fiberGrams: calculation.targetFiberGrams,
                waterMl: calculation.targetWaterMl,
                source: .initialCalculation,
                notes: "Estimativa inicial calculada por Mifflin-St Jeor"
            )
        }

        self.hasCompletedOnboarding = true
        persistToDisk()
    }

    public func updateTarget(_ target: NutritionTarget) {
        self.currentTarget = target
        persistToDisk()
    }

    private func persistToDisk() {
        guard let profile = currentProfile else { return }
        let payload = StoragePayload(profile: profile, target: currentTarget, hasCompletedOnboarding: hasCompletedOnboarding)

        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Erro ao persistir perfil no disco: \(error)")
        }
    }

    private func loadProfile() {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let payload = try JSONDecoder().decode(StoragePayload.self, from: data)
            self.currentProfile = payload.profile
            self.currentTarget = payload.target
            self.hasCompletedOnboarding = payload.hasCompletedOnboarding
        } catch {
            print("Erro ao carregar perfil do disco: \(error)")
        }
    }
}

private struct StoragePayload: Codable {
    let profile: UserProfile
    let target: NutritionTarget?
    let hasCompletedOnboarding: Bool
}
