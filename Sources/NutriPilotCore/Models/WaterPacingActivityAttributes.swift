#if canImport(ActivityKit)
import Foundation

#if os(iOS) || targetEnvironment(macCatalyst)
import ActivityKit

/// Modelo de Atributos do ActivityKit para a Dynamic Island e Tela de Bloqueio.
public struct WaterPacingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var currentWaterMl: Double
        public var pacingStatus: String
        public var intervalTargetMl: Double
        public var hourlyRateMl: Double
        public var lastUpdated: Date
        public var progressPercentage: Double

        public init(
            currentWaterMl: Double,
            pacingStatus: String,
            intervalTargetMl: Double,
            hourlyRateMl: Double,
            lastUpdated: Date = Date(),
            progressPercentage: Double
        ) {
            self.currentWaterMl = currentWaterMl
            self.pacingStatus = pacingStatus
            self.intervalTargetMl = intervalTargetMl
            self.hourlyRateMl = hourlyRateMl
            self.lastUpdated = lastUpdated
            self.progressPercentage = progressPercentage
        }

        public init(currentWaterMl: Double, breakdown: WaterPacingBreakdown, lastUpdated: Date = Date()) {
            self.currentWaterMl = currentWaterMl
            self.pacingStatus = breakdown.status.rawValue
            self.intervalTargetMl = breakdown.intervalTargetMl
            self.hourlyRateMl = breakdown.healthyHourlyRateMl
            self.lastUpdated = lastUpdated
            let target = max(1.0, breakdown.targetWaterMl)
            self.progressPercentage = min(100.0, max(0.0, (currentWaterMl / target) * 100.0))
        }
    }

    // Propriedades estáticas da atividade (fixas durante o ciclo de vida)
    public var targetWaterMl: Double
    public var startHour: Int
    public var endHour: Int

    public init(targetWaterMl: Double, startHour: Int = 8, endHour: Int = 22) {
        self.targetWaterMl = targetWaterMl
        self.startHour = startHour
        self.endHour = endHour
    }
}
#else
// Fallback para compilação em macOS/Linux onde ActivityKit existe mas ActivityAttributes é exclusivo de iOS
public struct WaterPacingActivityAttributes: Codable, Hashable, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var currentWaterMl: Double
        public var pacingStatus: String
        public var intervalTargetMl: Double
        public var hourlyRateMl: Double
        public var lastUpdated: Date
        public var progressPercentage: Double

        public init(
            currentWaterMl: Double,
            pacingStatus: String,
            intervalTargetMl: Double,
            hourlyRateMl: Double,
            lastUpdated: Date = Date(),
            progressPercentage: Double
        ) {
            self.currentWaterMl = currentWaterMl
            self.pacingStatus = pacingStatus
            self.intervalTargetMl = intervalTargetMl
            self.hourlyRateMl = hourlyRateMl
            self.lastUpdated = lastUpdated
            self.progressPercentage = progressPercentage
        }

        public init(currentWaterMl: Double, breakdown: WaterPacingBreakdown, lastUpdated: Date = Date()) {
            self.currentWaterMl = currentWaterMl
            self.pacingStatus = breakdown.status.rawValue
            self.intervalTargetMl = breakdown.intervalTargetMl
            self.hourlyRateMl = breakdown.healthyHourlyRateMl
            self.lastUpdated = lastUpdated
            let target = max(1.0, breakdown.targetWaterMl)
            self.progressPercentage = min(100.0, max(0.0, (currentWaterMl / target) * 100.0))
        }
    }

    public var targetWaterMl: Double
    public var startHour: Int
    public var endHour: Int

    public init(targetWaterMl: Double, startHour: Int = 8, endHour: Int = 22) {
        self.targetWaterMl = targetWaterMl
        self.startHour = startHour
        self.endHour = endHour
    }
}
#endif
#endif
