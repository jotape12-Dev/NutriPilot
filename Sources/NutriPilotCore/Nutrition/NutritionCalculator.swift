import Foundation

public struct NutritionCalculationResult: Sendable, Equatable {
    public let bmr: Double
    public let tdee: Double
    public let targetCalories: Double
    public let targetProteinGrams: Double
    public let targetCarbsGrams: Double
    public let targetFatGrams: Double
    public let targetFiberGrams: Double
    public let targetWaterMl: Double
    public let formulaUsed: String

    public init(
        bmr: Double,
        tdee: Double,
        targetCalories: Double,
        targetProteinGrams: Double,
        targetCarbsGrams: Double,
        targetFatGrams: Double,
        targetFiberGrams: Double,
        targetWaterMl: Double,
        formulaUsed: String = "Mifflin-St Jeor"
    ) {
        self.bmr = bmr
        self.tdee = tdee
        self.targetCalories = targetCalories
        self.targetProteinGrams = targetProteinGrams
        self.targetCarbsGrams = targetCarbsGrams
        self.targetFatGrams = targetFatGrams
        self.targetFiberGrams = targetFiberGrams
        self.targetWaterMl = targetWaterMl
        self.formulaUsed = formulaUsed
    }
}

public enum NutritionCalculator {
    /// Calcula a Taxa Metabólica Basal (TMB / BMR) usando a fórmula de Mifflin-St Jeor.
    public static func calculateBMR(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex) -> Double {
        let base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * Double(age))
        switch sex {
        case .male:
            return (base + 5.0).rounded()
        case .female:
            return (base - 161.0).rounded()
        }
    }

    /// Calcula a Taxa Metabólica Basal (TMB / BMR) usando a fórmula Katch-McArdle baseada em massa magra (kg).
    /// TMB = 370 + (21.6 * leanMassKg)
    public static func calculateBMRKatchMcArdle(leanMassKg: Double) -> Double {
        return (370.0 + (21.6 * leanMassKg)).rounded()
    }

    /// Calcula a Taxa Metabólica Basal (TMB / BMR) usando Katch-McArdle a partir do peso e percentual de gordura.
    public static func calculateBMRKatchMcArdle(weightKg: Double, bodyFatPercentage: Double) -> Double {
        let leanMassKg = max(0.0, weightKg * (1.0 - (bodyFatPercentage / 100.0)))
        return calculateBMRKatchMcArdle(leanMassKg: leanMassKg)
    }

    /// Calcula o Gasto Energético Total (GET / TDEE) baseado no nível de atividade.
    public static func calculateTDEE(bmr: Double, activityLevel: ActivityLevel) -> Double {
        return (bmr * activityLevel.multiplier).rounded()
    }

    /// Calcula a meta diária de hidratação (ml) baseada no peso e atividade.
    public static func calculateWaterMl(weightKg: Double, activityLevel: ActivityLevel) -> Double {
        let baseMlPerKg: Double = 35.0
        var water = weightKg * baseMlPerKg

        // Bônus para compensar sudorese por atividade física
        switch activityLevel {
        case .sedentary: break
        case .light: water += 300.0
        case .moderate: water += 600.0
        case .intense: water += 900.0
        case .extreme: water += 1200.0
        }

        return (water / 50.0).rounded() * 50.0 // Arredonda para múltiplos de 50ml
    }

    /// Executa o cálculo nutricional completo determinístico a partir do perfil do usuário.
    /// Se `leanMassKg` ou `bodyFatPercentage` forem informados (ex: via laudo de bioimpedância),
    /// utiliza a equação Katch-McArdle, trazendo maior precisão clínica.
    public static func calculateFullTarget(
        from profile: UserProfile,
        leanMassKg: Double? = nil,
        bodyFatPercentage: Double? = nil
    ) -> NutritionCalculationResult {
        let bmr: Double
        let formulaUsed: String

        if let leanMass = leanMassKg, leanMass > 0 {
            bmr = calculateBMRKatchMcArdle(leanMassKg: leanMass)
            formulaUsed = "Katch-McArdle (Bioimpedância)"
        } else if let bf = bodyFatPercentage, bf > 0, bf < 100 {
            bmr = calculateBMRKatchMcArdle(weightKg: profile.currentWeightKg, bodyFatPercentage: bf)
            formulaUsed = "Katch-McArdle (Bioimpedância)"
        } else {
            bmr = calculateBMR(
                weightKg: profile.currentWeightKg,
                heightCm: profile.heightCm,
                age: profile.age,
                sex: profile.sex
            )
            formulaUsed = "Mifflin-St Jeor"
        }

        let tdee = calculateTDEE(bmr: bmr, activityLevel: profile.activityLevel)
        let rawTargetCalories = tdee * (1.0 + profile.goal.calorieAdjustmentPercent)
        let targetCalories = (rawTargetCalories / 10.0).rounded() * 10.0 // Múltiplo de 10 kcal

        // Definição de proteína por kg de acordo com o objetivo
        let proteinPerKg: Double
        switch profile.goal {
        case .fatLoss:
            proteinPerKg = 2.0 // Preservação de massa magra em déficit
        case .muscleGain:
            proteinPerKg = 2.0
        case .recomposition:
            proteinPerKg = 2.2 // Maior estímulo proteico
        case .maintenance, .performance:
            proteinPerKg = 1.8
        }

        let proteinGrams = (profile.currentWeightKg * proteinPerKg).rounded()
        let proteinCalories = proteinGrams * 4.0

        // Gorduras saudáveis: ~0.9g por kg
        let fatPerKg = 0.9
        let fatGrams = (profile.currentWeightKg * fatPerKg).rounded()
        let fatCalories = fatGrams * 9.0

        // Carboidratos completam as calorias restantes
        let remainingCalories = max(0.0, targetCalories - (proteinCalories + fatCalories))
        let carbsGrams = (remainingCalories / 4.0).rounded()

        // Fibras: ~14g por 1000 kcal consumidas (mínimo 25g, teto 45g)
        let rawFiber = (targetCalories / 1000.0) * 14.0
        let fiberGrams = min(45.0, max(25.0, rawFiber.rounded()))

        let waterMl = calculateWaterMl(weightKg: profile.currentWeightKg, activityLevel: profile.activityLevel)

        return NutritionCalculationResult(
            bmr: bmr,
            tdee: tdee,
            targetCalories: targetCalories,
            targetProteinGrams: proteinGrams,
            targetCarbsGrams: carbsGrams,
            targetFatGrams: fatGrams,
            targetFiberGrams: fiberGrams,
            targetWaterMl: waterMl,
            formulaUsed: formulaUsed
        )
    }

    /// Calcula a decomposição aprofundada dos componentes de gasto energético diário.
    public static func calculateMetabolicBreakdown(
        profile: UserProfile,
        leanMassKg: Double? = nil,
        bodyFatPercentage: Double? = nil,
        measuredBMR: Double? = nil
    ) -> MetabolicBreakdown {
        let baselineMifflin = calculateBMR(
            weightKg: profile.currentWeightKg,
            heightCm: profile.heightCm,
            age: profile.age,
            sex: profile.sex
        )

        let bmr: Double
        let formula: String
        if let measured = measuredBMR, measured > 500 {
            bmr = measured.rounded()
            formula = "Laudo Bioimpedância (Medido)"
        } else if let lean = leanMassKg, lean > 0 {
            bmr = calculateBMRKatchMcArdle(leanMassKg: lean)
            formula = "Katch-McArdle (Massa Magra)"
        } else if let bf = bodyFatPercentage, bf > 0, bf < 100 {
            bmr = calculateBMRKatchMcArdle(weightKg: profile.currentWeightKg, bodyFatPercentage: bf)
            formula = "Katch-McArdle (% Gordura)"
        } else {
            bmr = baselineMifflin
            formula = "Mifflin-St Jeor"
        }

        let tdee = calculateTDEE(bmr: bmr, activityLevel: profile.activityLevel)
        let tef = (tdee * 0.10).rounded()
        let totalActivity = max(0.0, tdee - bmr - tef)

        let eatRatio: Double
        switch profile.activityLevel {
        case .sedentary: eatRatio = 0.0
        case .light: eatRatio = 0.35
        case .moderate: eatRatio = 0.50
        case .intense: eatRatio = 0.65
        case .extreme: eatRatio = 0.75
        }

        let eat = (totalActivity * eatRatio).rounded()
        let neat = (totalActivity - eat).rounded()
        let bmrDelta = (bmr - baselineMifflin).rounded()

        return MetabolicBreakdown(
            bmr: bmr,
            neat: neat,
            eat: eat,
            tef: tef,
            tdee: tdee,
            formulaUsed: formula,
            baselineBMRMifflin: baselineMifflin,
            bmrDeltaVsMifflin: bmrDelta
        )
    }
}

/// Decomposição detalhada dos componentes de gasto calórico diário do usuário.
public struct MetabolicBreakdown: Sendable, Equatable, Codable {
    public let bmr: Double
    public let neat: Double
    public let eat: Double
    public let tef: Double
    public let tdee: Double
    public let formulaUsed: String
    public let baselineBMRMifflin: Double
    public let bmrDeltaVsMifflin: Double

    public init(
        bmr: Double,
        neat: Double,
        eat: Double,
        tef: Double,
        tdee: Double,
        formulaUsed: String,
        baselineBMRMifflin: Double,
        bmrDeltaVsMifflin: Double
    ) {
        self.bmr = bmr
        self.neat = neat
        self.eat = eat
        self.tef = tef
        self.tdee = tdee
        self.formulaUsed = formulaUsed
        self.baselineBMRMifflin = baselineBMRMifflin
        self.bmrDeltaVsMifflin = bmrDeltaVsMifflin
    }
}
