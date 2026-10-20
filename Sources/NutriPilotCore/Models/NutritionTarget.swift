import Foundation

public enum TargetSource: String, Codable, Sendable {
    case initialCalculation = "Cálculo Inicial"
    case autoCalibrated = "Calibração Automática"
    case manualOverride = "Ajuste Manual"
}

public struct NutritionTarget: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var effectiveFrom: Date
    public var calories: Double
    public var proteinGrams: Double
    public var carbsGrams: Double
    public var fatGrams: Double
    public var fiberGrams: Double
    public var waterMl: Double
    public var source: TargetSource
    public var isManualLock: Bool
    public var notes: String?

    public init(
        id: UUID = UUID(),
        effectiveFrom: Date = Date(),
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double = 30.0,
        waterMl: Double,
        source: TargetSource = .initialCalculation,
        isManualLock: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.waterMl = waterMl
        self.source = source
        self.isManualLock = isManualLock
        self.notes = notes
    }
}
