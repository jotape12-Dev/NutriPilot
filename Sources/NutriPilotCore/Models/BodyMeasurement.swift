import Foundation

public enum MeasurementSource: String, Codable, Sendable {
    case manual = "Manual"
    case smartScale = "Balança Inteligente"
    case bia = "Bioimpedância"
    case dexa = "DEXA"
    case clinicalAssessment = "Avaliação Antropométrica"
}

public struct SkinfoldMeasurements: Codable, Sendable, Equatable {
    public var chestMm: Double?          // Peitoral
    public var abdominalMm: Double?      // Abdominal
    public var middleAxillaryMm: Double? // Axilar Média
    public var subscapularMm: Double?    // Subescapular
    public var suprailiacMm: Double?     // Suprailíaca
    public var thighMm: Double?          // Coxa
    public var tricepsMm: Double?        // Tríceps

    public init(
        chestMm: Double? = nil,
        abdominalMm: Double? = nil,
        middleAxillaryMm: Double? = nil,
        subscapularMm: Double? = nil,
        suprailiacMm: Double? = nil,
        thighMm: Double? = nil,
        tricepsMm: Double? = nil
    ) {
        self.chestMm = chestMm
        self.abdominalMm = abdominalMm
        self.middleAxillaryMm = middleAxillaryMm
        self.subscapularMm = subscapularMm
        self.suprailiacMm = suprailiacMm
        self.thighMm = thighMm
        self.tricepsMm = tricepsMm
    }

    public var sumOf7Folds: Double? {
        guard let c = chestMm, let a = abdominalMm, let m = middleAxillaryMm,
              let s = subscapularMm, let si = suprailiacMm, let t = thighMm, let tr = tricepsMm else {
            return nil
        }
        return c + a + m + s + si + t + tr
    }

    /// Soma de 3 dobras para homens (Jackson & Pollock: Peitoral + Abdominal + Coxa)
    public var sumOf3FoldsMale: Double? {
        guard let c = chestMm, let a = abdominalMm, let t = thighMm else { return nil }
        return c + a + t
    }

    /// Soma de 3 dobras para mulheres (Jackson & Pollock: Tríceps + Suprailíaca + Coxa)
    public var sumOf3FoldsFemale: Double? {
        guard let tr = tricepsMm, let si = suprailiacMm, let t = thighMm else { return nil }
        return tr + si + t
    }
}

public struct BodyMeasurement: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var measuredAt: Date
    public var weightKg: Double

    // Circunferências Corporais (cm)
    public var waistCm: Double?
    public var hipCm: Double?
    public var chestCm: Double?
    public var shoulderCm: Double?
    public var abdomenCm: Double?
    public var leftArmRelaxedCm: Double?
    public var rightArmRelaxedCm: Double?
    public var leftArmContractedCm: Double?
    public var rightArmContractedCm: Double?
    public var leftForearmCm: Double?
    public var rightForearmCm: Double?
    public var leftThighCm: Double?
    public var rightThighCm: Double?
    public var leftCalfCm: Double?
    public var rightCalfCm: Double?

    // Composição Corporal (Calculada / BIA / DEXA)
    public var bodyFatPercent: Double?
    public var waterPercent: Double?          // % de Água Corporal (BIA)
    public var visceralFatLevel: Int?          // Nível de Gordura Visceral (BIA 1-59)
    public var leanMassKg: Double?
    public var fatMassKg: Double?
    public var muscularMassKg: Double?
    public var boneMassKg: Double?
    public var residualMassKg: Double?

    // Dobras Cutâneas
    public var skinfolds: SkinfoldMeasurements?

    public var source: MeasurementSource
    public var isReference: Bool

    public init(
        id: UUID = UUID(),
        measuredAt: Date = Date(),
        weightKg: Double,
        waistCm: Double? = nil,
        hipCm: Double? = nil,
        chestCm: Double? = nil,
        shoulderCm: Double? = nil,
        abdomenCm: Double? = nil,
        leftArmRelaxedCm: Double? = nil,
        rightArmRelaxedCm: Double? = nil,
        leftArmContractedCm: Double? = nil,
        rightArmContractedCm: Double? = nil,
        leftForearmCm: Double? = nil,
        rightForearmCm: Double? = nil,
        leftThighCm: Double? = nil,
        rightThighCm: Double? = nil,
        leftCalfCm: Double? = nil,
        rightCalfCm: Double? = nil,
        bodyFatPercent: Double? = nil,
        waterPercent: Double? = nil,
        visceralFatLevel: Int? = nil,
        leanMassKg: Double? = nil,
        fatMassKg: Double? = nil,
        muscularMassKg: Double? = nil,
        boneMassKg: Double? = nil,
        residualMassKg: Double? = nil,
        skinfolds: SkinfoldMeasurements? = nil,
        source: MeasurementSource = .manual,
        isReference: Bool = false
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.weightKg = weightKg
        self.waistCm = waistCm
        self.hipCm = hipCm
        self.chestCm = chestCm
        self.shoulderCm = shoulderCm
        self.abdomenCm = abdomenCm
        self.leftArmRelaxedCm = leftArmRelaxedCm
        self.rightArmRelaxedCm = rightArmRelaxedCm
        self.leftArmContractedCm = leftArmContractedCm
        self.rightArmContractedCm = rightArmContractedCm
        self.leftForearmCm = leftForearmCm
        self.rightForearmCm = rightForearmCm
        self.leftThighCm = leftThighCm
        self.rightThighCm = rightThighCm
        self.leftCalfCm = leftCalfCm
        self.rightCalfCm = rightCalfCm
        self.bodyFatPercent = bodyFatPercent
        self.waterPercent = waterPercent
        self.visceralFatLevel = visceralFatLevel
        self.leanMassKg = leanMassKg
        self.fatMassKg = fatMassKg
        self.muscularMassKg = muscularMassKg
        self.boneMassKg = boneMassKg
        self.residualMassKg = residualMassKg
        self.skinfolds = skinfolds
        self.source = source
        self.isReference = isReference
    }
}
