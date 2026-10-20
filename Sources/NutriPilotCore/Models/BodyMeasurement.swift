import Foundation

public enum MeasurementSource: String, Codable, Sendable {
    case manual = "Manual"
    case smartScale = "Balança Inteligente"
    case bia = "Bioimpedância"
    case dexa = "DEXA"
}

public struct BodyMeasurement: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var measuredAt: Date
    public var weightKg: Double
    public var waistCm: Double?
    public var hipCm: Double?
    public var chestCm: Double?
    public var armCm: Double?
    public var thighCm: Double?
    public var bodyFatPercent: Double?
    public var leanMassKg: Double?
    public var source: MeasurementSource
    public var isReference: Bool

    public init(
        id: UUID = UUID(),
        measuredAt: Date = Date(),
        weightKg: Double,
        waistCm: Double? = nil,
        hipCm: Double? = nil,
        chestCm: Double? = nil,
        armCm: Double? = nil,
        thighCm: Double? = nil,
        bodyFatPercent: Double? = nil,
        leanMassKg: Double? = nil,
        source: MeasurementSource = .manual,
        isReference: Bool = false
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.weightKg = weightKg
        self.waistCm = waistCm
        self.hipCm = hipCm
        self.chestCm = chestCm
        self.armCm = armCm
        self.thighCm = thighCm
        self.bodyFatPercent = bodyFatPercent
        self.leanMassKg = leanMassKg
        self.source = source
        self.isReference = isReference
    }
}
