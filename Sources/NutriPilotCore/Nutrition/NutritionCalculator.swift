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

    public init(
        bmr: Double,
        tdee: Double,
        targetCalories: Double,
        targetProteinGrams: Double,
        targetCarbsGrams: Double,
        targetFatGrams: Double,
        targetFiberGrams: Double,
        targetWaterMl: Double
    ) {
        self.bmr = bmr
        self.tdee = tdee
        self.targetCalories = targetCalories
        self.targetProteinGrams = targetProteinGrams
        self.targetCarbsGrams = targetCarbsGrams
        self.targetFatGrams = targetFatGrams
        self.targetFiberGrams = targetFiberGrams
        self.targetWaterMl = targetWaterMl
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
    public static func calculateFullTarget(from profile: UserProfile) -> NutritionCalculationResult {
        let bmr = calculateBMR(
            weightKg: profile.currentWeightKg,
            heightCm: profile.heightCm,
            age: profile.age,
            sex: profile.sex
        )

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
            targetWaterMl: waterMl
        )
    }
}
