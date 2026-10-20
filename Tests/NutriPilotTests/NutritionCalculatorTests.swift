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
}
