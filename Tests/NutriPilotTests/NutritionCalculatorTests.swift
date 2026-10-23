import XCTest
@testable import NutriPilotCore

final class NutritionCalculatorTests: XCTestCase {

    func testBMRCalculationMale() {
        // Homem de 78kg, 178cm, 25 anos
        // BMR = (10 * 78) + (6.25 * 178) - (5 * 25) + 5
        // BMR = 780 + 1112.5 - 125 + 5 = 1772.5 -> 1772 ou 1773
        let bmr = NutritionCalculator.calculateBMR(weightKg: 78, heightCm: 178, age: 25, sex: .male)
        XCTAssertEqual(bmr, 1772.0, accuracy: 2.0)
    }

    func testBMRCalculationFemale() {
        // Mulher de 60kg, 165cm, 30 anos
        // BMR = (10 * 60) + (6.25 * 165) - (5 * 30) - 161
        // BMR = 600 + 1031.25 - 150 - 161 = 1320.25
        let bmr = NutritionCalculator.calculateBMR(weightKg: 60, heightCm: 165, age: 30, sex: .female)
        XCTAssertEqual(bmr, 1320.0, accuracy: 2.0)
    }

    func testTDEECalculation() {
        let bmr = 1772.0
        let tdeeModerate = NutritionCalculator.calculateTDEE(bmr: bmr, activityLevel: .moderate)
        // 1772 * 1.55 = 2746.6 -> 2747
        XCTAssertEqual(tdeeModerate, 2747.0, accuracy: 2.0)
    }

    func testWaterCalculation() {
        // 78kg * 35ml = 2730 + 600 (moderado) = 3330 -> arredondado para múltiplo de 50 = 3350ml
        let water = NutritionCalculator.calculateWaterMl(weightKg: 78, activityLevel: .moderate)
        XCTAssertEqual(water, 3350.0, accuracy: 50.0)
    }

    func testFullTargetRecomposition() {
        // Criar perfil com data de nascimento de 25 anos atrás
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -25, to: Date())!

        let profile = UserProfile(
            name: "João",
            birthDate: birthDate,
            sex: .male,
            heightCm: 178,
            currentWeightKg: 78,
            activityLevel: .moderate,
            goal: .recomposition
        )

        let result = NutritionCalculator.calculateFullTarget(from: profile)

        XCTAssertGreaterThan(result.bmr, 1700)
        XCTAssertGreaterThan(result.tdee, 2600)
        XCTAssertGreaterThan(result.targetCalories, 2400)
        // Proteína recomposição = 78 * 2.2 = 171.6g -> ~172g
        XCTAssertEqual(result.targetProteinGrams, 172.0, accuracy: 2.0)
        // Gordura = 78 * 0.9 = 70.2g -> ~70g
        XCTAssertEqual(result.targetFatGrams, 70.0, accuracy: 2.0)
        // Carboidratos devem fechar a conta calórica
        let expectedTotalCals = (result.targetProteinGrams * 4) + (result.targetFatGrams * 9) + (result.targetCarbsGrams * 4)
        XCTAssertEqual(expectedTotalCals, result.targetCalories, accuracy: 10.0)
        // Fibras entre 25g e 45g
        XCTAssertGreaterThanOrEqual(result.targetFiberGrams, 25.0)
        XCTAssertLessThanOrEqual(result.targetFiberGrams, 45.0)
    }

    func testMetabolicBreakdownComponentsDecomposition() {
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -25, to: Date())!

        let profile = UserProfile(
            name: "João",
            birthDate: birthDate,
            sex: .male,
            heightCm: 178,
            currentWeightKg: 80.0,
            activityLevel: .moderate,
            goal: .fatLoss
        )

        // 1. Sem dados de bioimpedância -> Usa Mifflin-St Jeor
        let breakdownMifflin = NutritionCalculator.calculateMetabolicBreakdown(profile: profile)
        XCTAssertEqual(breakdownMifflin.formulaUsed, "Mifflin-St Jeor")
        XCTAssertEqual(breakdownMifflin.bmrDeltaVsMifflin, 0.0)
        // A soma dos componentes BMR + NEAT + EAT + TEF deve igualar TDEE (com tolerância de arredondamento de até 2 kcal)
        let sumComponentsMifflin = breakdownMifflin.bmr + breakdownMifflin.neat + breakdownMifflin.eat + breakdownMifflin.tef
        XCTAssertEqual(sumComponentsMifflin, breakdownMifflin.tdee, accuracy: 2.0)

        // 2. Com Massa Magra de 68kg -> Usa Katch-McArdle
        let breakdownKatch = NutritionCalculator.calculateMetabolicBreakdown(
            profile: profile,
            leanMassKg: 68.0
        )
        XCTAssertEqual(breakdownKatch.formulaUsed, "Katch-McArdle (Massa Magra)")
        // Katch-McArdle BMR = 370 + (21.6 * 68) = 370 + 1468.8 = 1838.8 -> 1839 kcal
        XCTAssertEqual(breakdownKatch.bmr, 1839.0, accuracy: 2.0)
        // Delta vs baseline
        XCTAssertEqual(breakdownKatch.bmrDeltaVsMifflin, (breakdownKatch.bmr - breakdownKatch.baselineBMRMifflin).rounded(), accuracy: 1.0)
        let sumComponentsKatch = breakdownKatch.bmr + breakdownKatch.neat + breakdownKatch.eat + breakdownKatch.tef
        XCTAssertEqual(sumComponentsKatch, breakdownKatch.tdee, accuracy: 2.0)
    }

    func testMetabolicBreakdownWithMeasuredBMR() {
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -28, to: Date())!

        let profile = UserProfile(
            name: "Lucas",
            birthDate: birthDate,
            sex: .male,
            heightCm: 180,
            currentWeightKg: 85.0,
            activityLevel: .intense,
            goal: .muscleGain
        )

        let breakdown = NutritionCalculator.calculateMetabolicBreakdown(
            profile: profile,
            leanMassKg: 72.0,
            measuredBMR: 1950.0
        )

        XCTAssertEqual(breakdown.formulaUsed, "Laudo Bioimpedância (Medido)")
        XCTAssertEqual(breakdown.bmr, 1950.0)
        XCTAssertGreaterThan(breakdown.eat, breakdown.neat) // Atividade intensa aloca 65% em EAT
    }

    func testProfileStoreUpdateProfileRecalculation() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_profile_\(UUID().uuidString).json")
        let store = ProfileStore(storageURL: tempURL)

        let birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        let initialProfile = UserProfile(
            name: "Carlos",
            birthDate: birthDate,
            sex: .male,
            heightCm: 175,
            currentWeightKg: 80.0,
            activityLevel: .light,
            goal: .fatLoss
        )

        store.saveProfile(initialProfile)
        let initialCals = store.currentTarget?.calories ?? 0

        // 1. Altera nível de atividade para intense -> Calorias devem subir consideravelmente
        store.updateProfile(activityLevel: .intense)
        XCTAssertEqual(store.currentProfile?.activityLevel, .intense)
        let intenseCals = store.currentTarget?.calories ?? 0
        XCTAssertGreaterThan(intenseCals, initialCals)

        // 2. Altera objetivo de fatLoss (-20%) para muscleGain (+10%)
        store.updateProfile(goal: .muscleGain)
        XCTAssertEqual(store.currentProfile?.goal, .muscleGain)
        let muscleCals = store.currentTarget?.calories ?? 0
        XCTAssertGreaterThan(muscleCals, intenseCals)

        // 3. Aplica massa magra de bioimpedância
        store.updateProfile(leanMassKg: 70.0)
        XCTAssertEqual(store.currentTarget?.source, .autoCalibrated)
        XCTAssertTrue(store.currentTarget?.notes?.contains("Katch-McArdle") == true)
    }
}
