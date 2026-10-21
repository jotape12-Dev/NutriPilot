import XCTest
@testable import NutriPilotCore

final class MealPlanComplianceEvaluatorTests: XCTestCase {

    private func makePlan(calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double = 30.0) -> DailyMealPlan {
        let food = FoodItem(
            name: "Alimento Composto",
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            fiberGrams: fiber
        )
        let item = PlannedMealItem(
            food: food,
            amount: 100.0,
            unit: "g",
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            fiberGrams: fiber
        )
        let meal = PlannedMeal(
            mealType: .lunch,
            name: "Refeição Principal",
            suggestedTime: "12:30",
            targetCalories: calories,
            items: [item]
        )
        return DailyMealPlan(
            targetCalories: calories,
            targetProteinGrams: protein,
            targetCarbsGrams: carbs,
            targetFatGrams: fat,
            targetFiberGrams: fiber,
            meals: [meal]
        )
    }

    // MARK: - 1. Plano Perfeitamente Alinhado (99-100%)
    func testPlanPerfectAlignment() {
        let target = NutritionTarget(
            calories: 2200.0,
            proteinGrams: 165.0,
            carbsGrams: 240.0,
            fatGrams: 65.0,
            fiberGrams: 30.0,
            waterMl: 3000.0
        )

        let plan = makePlan(
            calories: 2195.0, // 99.8%
            protein: 165.0,   // 100%
            carbs: 238.0,     // 99.2%
            fat: 65.0,        // 100%
            fiber: 30.0       // 100%
        )

        let report = MealPlanComplianceEvaluator.evaluate(
            plan: plan,
            target: target,
            goal: .maintenance,
            currentWeightKg: 80.0
        )

        XCTAssertEqual(report.overallLevel, .optimal)
        XCTAssertEqual(report.title, "Plano Perfeitamente Alinhado")
        XCTAssertEqual(report.calories.level, .optimal)
        XCTAssertEqual(report.protein.level, .optimal)
        XCTAssertEqual(report.fat.level, .optimal)
        XCTAssertEqual(report.carbs.level, .optimal)
        XCTAssertEqual(report.fiber.level, .optimal)
        XCTAssertFalse(report.alerts.contains(where: { $0.severity == .danger || $0.severity == .warning }))
        XCTAssertTrue(report.summaryVerdict.contains("distribuição equilibrada") || report.summaryVerdict.contains("100% pronto"))
    }

    // MARK: - 2. Plano com Déficit Excessivo (< 80%)
    func testExcessiveDeficitAlert() {
        let target = NutritionTarget(
            calories: 2000.0,
            proteinGrams: 160.0,
            carbsGrams: 200.0,
            fatGrams: 60.0,
            fiberGrams: 28.0,
            waterMl: 2800.0
        )

        // Usuário removeu refeições e plano ficou com apenas 1400 kcal (70% da meta)
        let plan = makePlan(
            calories: 1400.0,
            protein: 110.0,
            carbs: 150.0,
            fat: 40.0,
            fiber: 18.0
        )

        let report = MealPlanComplianceEvaluator.evaluate(
            plan: plan,
            target: target,
            goal: .fatLoss,
            currentWeightKg: 80.0
        )

        XCTAssertEqual(report.overallLevel, .critical)
        XCTAssertEqual(report.calories.level, .critical)
        XCTAssertTrue(report.alerts.contains(where: {
            $0.severity == .danger && $0.message.contains("Déficit calórico agressivo")
        }))
        // Alerta de remoção de comida
        XCTAssertTrue(report.alerts.contains(where: {
            $0.message.contains("Ao remover alimentos")
        }))
    }

    // MARK: - 3. Plano com Superávit Involuntário (> 110% em Perda de Gordura)
    func testUnintendedSurplusInFatLoss() {
        let target = NutritionTarget(
            calories: 2000.0,
            proteinGrams: 160.0,
            carbsGrams: 200.0,
            fatGrams: 60.0,
            fiberGrams: 28.0,
            waterMl: 2800.0
        )

        // Plano com 2380 kcal (119% da meta) em meta de fatLoss
        let plan = makePlan(
            calories: 2380.0,
            protein: 170.0,
            carbs: 270.0,
            fat: 70.0,
            fiber: 32.0
        )

        let report = MealPlanComplianceEvaluator.evaluate(
            plan: plan,
            target: target,
            goal: .fatLoss,
            currentWeightKg: 80.0
        )

        XCTAssertEqual(report.overallLevel, .critical)
        XCTAssertEqual(report.calories.level, .critical)
        XCTAssertTrue(report.alerts.contains(where: {
            $0.severity == .danger && $0.message.contains("Superávit calórico involuntário")
        }))
        XCTAssertTrue(report.alerts.contains(where: {
            $0.message.contains("Alimentos adicionados excederam a meta")
        }))
    }

    // MARK: - 4. Plano com Proteína Insuficiente (< 90% ou < 1.6 g/kg)
    func testInsufficientProtein() {
        let target = NutritionTarget(
            calories: 2100.0,
            proteinGrams: 180.0,
            carbsGrams: 210.0,
            fatGrams: 60.0,
            fiberGrams: 30.0,
            waterMl: 3000.0
        )

        // Usuário com 90kg consumindo apenas 110g de proteína (1.22 g/kg, 61% da meta)
        let plan = makePlan(
            calories: 2050.0,
            protein: 110.0,
            carbs: 270.0,
            fat: 58.0,
            fiber: 28.0
        )

        let report = MealPlanComplianceEvaluator.evaluate(
            plan: plan,
            target: target,
            goal: .fatLoss,
            currentWeightKg: 90.0
        )

        XCTAssertEqual(report.protein.level, .critical)
        XCTAssertEqual(report.proteinGramsPerKg, 1.22)
        XCTAssertTrue(report.alerts.contains(where: {
            $0.severity == .danger && $0.message.contains("abaixo do piso clínico de 1.6 g/kg")
        }))
    }

    // MARK: - 5. Gorduras Abaixo do Mínimo de Segurança Hormonal (< 30g)
    func testCriticallyLowFatsHormonalAlert() {
        let target = NutritionTarget(
            calories: 1900.0,
            proteinGrams: 160.0,
            carbsGrams: 230.0,
            fatGrams: 50.0,
            fiberGrams: 25.0,
            waterMl: 2600.0
        )

        // Plano com apenas 20g de gordura
        let plan = makePlan(
            calories: 1850.0,
            protein: 165.0,
            carbs: 260.0,
            fat: 20.0,
            fiber: 26.0
        )

        let report = MealPlanComplianceEvaluator.evaluate(
            plan: plan,
            target: target,
            goal: .fatLoss,
            currentWeightKg: 75.0
        )

        XCTAssertEqual(report.fat.level, .critical)
        XCTAssertEqual(report.overallLevel, .critical)
        XCTAssertTrue(report.alerts.contains(where: {
            $0.severity == .danger && $0.message.contains("segurança hormonal")
        }))
    }

    // MARK: - 6. Teste com Dados Reais do Laudo Importado (2.458 kcal) contra Perfil do João
    func testRealImportedDietAgainstJoaoProfile() {
        // Perfil real do João: 1.91m (191cm), 95kg, idade 28, sexo masc, musculação (.moderate / 3-5 dias), déficit (.fatLoss)
        let joaoProfile = UserProfile(
            name: "João",
            birthDate: Calendar.current.date(byAdding: .year, value: -28, to: Date())!,
            sex: .male,
            heightCm: 191.0,
            currentWeightKg: 95.0,
            activityLevel: .moderate,
            goal: .fatLoss
        )

        let calcResult = NutritionCalculator.calculateFullTarget(from: joaoProfile)
        let joaoTarget = NutritionTarget(
            calories: calcResult.targetCalories,
            proteinGrams: calcResult.targetProteinGrams,
            carbsGrams: calcResult.targetCarbsGrams,
            fatGrams: calcResult.targetFatGrams,
            fiberGrams: calcResult.targetFiberGrams,
            waterMl: calcResult.targetWaterMl,
            source: .initialCalculation
        )

        // Plano alimentar importado de prescrição nutricional real para João (~2.458 kcal, 192g proteína, 245g carbo, 78g gordura, 32g fibra)
        let importedDietPlan = makePlan(
            calories: 2458.0,
            protein: 192.0,
            carbs: 245.0,
            fat: 78.0,
            fiber: 32.0
        )

        let report = MealPlanComplianceEvaluator.evaluate(
            plan: importedDietPlan,
            target: joaoTarget,
            goal: joaoProfile.goal,
            currentWeightKg: joaoProfile.currentWeightKg
        )

        // A meta de déficit de João calculada fica em torno de 2.770 kcal (ou ~2.490 se moderado)
        // O plano de 2.458 kcal está dentro da faixa de adesão clínica (ou aceitável/ideal)
        XCTAssertNotNil(report.proteinGramsPerKg)
        XCTAssertGreaterThanOrEqual(report.proteinGramsPerKg!, 2.0, "João deve ter pelo menos 2.0 g/kg de proteína")
        XCTAssertFalse(report.alerts.contains(where: { $0.severity == AlertSeverity.danger }), "Dieta prescrita de 2.458 kcal não deve conter alertas críticos de perigo")
        XCTAssertTrue(report.overallLevel == ComplianceLevel.optimal || report.overallLevel == ComplianceLevel.acceptable)
    }
}
