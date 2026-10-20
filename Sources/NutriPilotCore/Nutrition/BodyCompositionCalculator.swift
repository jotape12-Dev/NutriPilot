import Foundation

/// Resultado consolidado da avaliação antropométrica e composição corporal fracionada.
public struct BodyCompositionResult: Sendable, Equatable {
    public let bodyDensity: Double
    public let bodyFatPercent: Double
    public let fatMassKg: Double
    public let leanMassKg: Double
    public let muscleMassKg: Double
    public let boneMassKg: Double
    public let residualMassKg: Double
    public let protocolUsed: String

    public init(
        bodyDensity: Double,
        bodyFatPercent: Double,
        fatMassKg: Double,
        leanMassKg: Double,
        muscleMassKg: Double,
        boneMassKg: Double,
        residualMassKg: Double,
        protocolUsed: String
    ) {
        self.bodyDensity = (bodyDensity * 10000.0).rounded() / 10000.0
        self.bodyFatPercent = bodyFatPercent.rounded(to: 1)
        self.fatMassKg = fatMassKg.rounded(to: 2)
        self.leanMassKg = leanMassKg.rounded(to: 2)
        self.muscleMassKg = muscleMassKg.rounded(to: 2)
        self.boneMassKg = boneMassKg.rounded(to: 2)
        self.residualMassKg = residualMassKg.rounded(to: 2)
        self.protocolUsed = protocolUsed
    }
}

/// Motor de cálculo de composição corporal por dobras cutâneas (Jackson & Pollock 3 e 7 dobras),
/// conversão de densidade para gordura pela equação de Siri e fracionamento em 4 componentes de massa.
public enum BodyCompositionCalculator {

    // MARK: - Jackson & Pollock 7 Dobras

    /// Calcula a composição corporal pelo protocolo Jackson & Pollock 7 Dobras.
    /// Dobras necessárias: Peitoral, Axilar Média, Tricipital, Subescapular, Suprailíaca, Abdominal e Coxa.
    public static func calculate7Folds(
        skinfolds: SkinfoldMeasurements,
        weightKg: Double,
        ageYears: Double,
        sex: BiologicalSex
    ) -> BodyCompositionResult? {
        guard let sum7 = skinfolds.sumOf7Folds, sum7 > 0, weightKg > 0, ageYears > 0 else {
            return nil
        }

        let density: Double
        switch sex {
        case .male:
            // Jackson & Pollock (1978) - Homens 7 Dobras
            // BD = 1.112 - (0.00043499 * sum7) + (0.00000055 * sum7^2) - (0.00028826 * age)
            density = 1.112 - (0.00043499 * sum7) + (0.00000055 * pow(sum7, 2)) - (0.00028826 * ageYears)
        case .female:
            // Jackson, Pollock & Ward (1980) - Mulheres 7 Dobras
            // BD = 1.097 - (0.00046971 * sum7) + (0.00000056 * sum7^2) - (0.00012828 * age)
            density = 1.097 - (0.00046971 * sum7) + (0.00000056 * pow(sum7, 2)) - (0.00012828 * ageYears)
        }

        let bfPercent = siriEquation(bodyDensity: density)
        return fractionateMass(
            weightKg: weightKg,
            bodyFatPercent: bfPercent,
            bodyDensity: density,
            sex: sex,
            protocolUsed: "Jackson & Pollock 7 Dobras"
        )
    }

    // MARK: - Jackson & Pollock 3 Dobras

    /// Calcula a composição corporal pelo protocolo Jackson & Pollock 3 Dobras.
    /// Homens: Peitoral, Abdominal e Coxa.
    /// Mulheres: Tríceps, Suprailíaca e Coxa.
    public static func calculate3Folds(
        skinfolds: SkinfoldMeasurements,
        weightKg: Double,
        ageYears: Double,
        sex: BiologicalSex
    ) -> BodyCompositionResult? {
        guard weightKg > 0, ageYears > 0 else { return nil }

        let density: Double
        switch sex {
        case .male:
            guard let sum3 = skinfolds.sumOf3FoldsMale, sum3 > 0 else { return nil }
            // Jackson & Pollock (1978) - Homens 3 Dobras
            // BD = 1.10938 - (0.0008267 * sum3) + (0.0000016 * sum3^2) - (0.0002574 * age)
            density = 1.10938 - (0.0008267 * sum3) + (0.0000016 * pow(sum3, 2)) - (0.0002574 * ageYears)
        case .female:
            guard let sum3 = skinfolds.sumOf3FoldsFemale, sum3 > 0 else { return nil }
            // Jackson, Pollock & Ward (1980) - Mulheres 3 Dobras
            // BD = 1.0994921 - (0.0009929 * sum3) + (0.0000023 * sum3^2) - (0.0001392 * age)
            density = 1.0994921 - (0.0009929 * sum3) + (0.0000023 * pow(sum3, 2)) - (0.0001392 * ageYears)
        }

        let bfPercent = siriEquation(bodyDensity: density)
        return fractionateMass(
            weightKg: weightKg,
            bodyFatPercent: bfPercent,
            bodyDensity: density,
            sex: sex,
            protocolUsed: "Jackson & Pollock 3 Dobras"
        )
    }

    // MARK: - Equação de Siri

    /// Converte a densidade corporal calculada (g/cm³) em percentual de gordura corporal (%BF).
    /// Fórmula de Siri (1956): %Gordura = ((4.95 / Densidade) - 4.50) * 100
    public static func siriEquation(bodyDensity: Double) -> Double {
        guard bodyDensity > 0 else { return 0.0 }
        let rawPercent = ((4.95 / bodyDensity) - 4.50) * 100.0
        // Clampa entre limites fisiológicos extremos (3% a 65%)
        return min(max(rawPercent, 3.0), 65.0)
    }

    // MARK: - Fracionamento em 4 Componentes de Massa

    /// Realiza o fracionamento em Massa Gorda, Massa Magra, Massa Óssea e Massa Residual (Fórmula de Würch / Rocha).
    public static func fractionateMass(
        weightKg: Double,
        bodyFatPercent: Double,
        bodyDensity: Double,
        sex: BiologicalSex,
        protocolUsed: String
    ) -> BodyCompositionResult {
        let fatMass = weightKg * (bodyFatPercent / 100.0)
        let leanMass = max(0.0, weightKg - fatMass)

        // Massa Residual (Fórmula de Würch):
        // Homens: 24.1% do peso total | Mulheres: 20.9% do peso total
        let residualMassFraction: Double
        switch sex {
        case .male: residualMassFraction = 0.241
        case .female: residualMassFraction = 0.209
        }
        let residualMass = weightKg * residualMassFraction

        // Massa Óssea estimada (~15% do peso corporal total conforme antropometria clínica clássica)
        let boneMass = weightKg * 0.15

        // Massa Muscular = Massa Livre de Gordura - (Massa Óssea + Massa Residual)
        // Garantindo que permaneça sempre positiva e fisiológica
        let muscleMass = max(0.0, leanMass - (boneMass * 0.5 + residualMass * 0.5))

        return BodyCompositionResult(
            bodyDensity: bodyDensity,
            bodyFatPercent: bodyFatPercent,
            fatMassKg: fatMass,
            leanMassKg: leanMass,
            muscleMassKg: muscleMass,
            boneMassKg: boneMass,
            residualMassKg: residualMass,
            protocolUsed: protocolUsed
        )
    }
}
