import XCTest
@testable import NutriPilotCore

final class MealPlanAdjustmentEngineTests: XCTestCase {

    private func makeTestPlan(
        meals: [PlannedMeal]
    ) -> DailyMealPlan {
        let totalCals = meals.reduce(0.0) { $0 + $1.totalCalories }
        let totalProt = meals.reduce(0.0) { $0 + $1.totalProtein }
        let totalCarbs = meals.reduce(0.0) { $0 + $1.totalCarbs }
        let totalFat = meals.reduce(0.0) { $0 + $1.totalFat }
        let totalFiber = meals.reduce(0.0) { $0 + $1.totalFiber }

        return DailyMealPlan(
            targetCalories: totalCals,
            targetProteinGrams: totalProt,
            targetCarbsGrams: totalCarbs,
            targetFatGrams: totalFat,
            targetFiberGrams: totalFiber,
            meals: meals
        )
    }

    private func makeMeal(
        id: UUID = UUID(),
        mealType: MealType,
        name: String,
        items: [PlannedMealItem]
    ) -> PlannedMeal {
        let targetCals = items.reduce(0.0) { $0 + $1.calories }
        return PlannedMeal(
            id: id,
            mealType: mealType,
            name: name,
            suggestedTime: "12:00",
            targetCalories: targetCals,
            items: items
        )
    }

    private func makeFoodItem(name: String, cals: Double, prot: Double, carbs: Double, fat: Double, fiber: Double = 0.0) -> FoodItem {
        FoodItem(
            name: name,
            servingSize: 100.0,
            servingUnit: "g",
            calories: cals,
            proteinGrams: prot,
            carbsGrams: carbs,
            fatGrams: fat,
            fiberGrams: fiber
        )
    }

    // MARK: - 1. Geração de sugestão quando proteína estiver baixa
    func testLowProteinSuggestion() {
        let chicken = makeFoodItem(name: "Peito de frango grelhado", cals: 165.0, prot: 31.0, carbs: 0.0, fat: 3.6)
        let rice = makeFoodItem(name: "Arroz branco cozido", cals: 130.0, prot: 2.7, carbs: 28.2, fat: 0.3)

        let lunchItem1 = PlannedMealItem(food: chicken, amount: 100.0, unit: "g", calories: 165.0, proteinGrams: 31.0, carbsGrams: 0.0, fatGrams: 3.6, fiberGrams: 0.0)
        let lunchItem2 = PlannedMealItem(food: rice, amount: 150.0, unit: "g", calories: 195.0, proteinGrams: 4.1, carbsGrams: 42.3, fatGrams: 0.5, fiberGrams: 0.5)

        let lunch = makeMeal(mealType: .lunch, name: "Almoço", items: [lunchItem1, lunchItem2])
        let afternoonSnack = makeMeal(mealType: .afternoonSnack, name: "Lanche da Tarde", items: [])

        let plan = makeTestPlan(meals: [lunch, afternoonSnack])

        // Meta exige 160g de proteína, mas o plano só tem ~35.1g (déficit > 15g)
        let target = NutritionTarget(
            calories: 2000.0,
            proteinGrams: 160.0,
            carbsGrams: 220.0,
            fatGrams: 55.0,
            fiberGrams: 28.0,
            waterMl: 2800.0
        )

        let suggestions = MealPlanAdjustmentEngine.generateSuggestions(plan: plan, target: target, goal: .fatLoss)

        XCTAssertFalse(suggestions.isEmpty)
        // Deve sugerir reforço proteico (Whey ou aumentar frango)
        let hasProteinSuggestion = suggestions.contains(where: {
            $0.badgeLabel.contains("Proteína") || $0.title.contains("Proteína") || $0.title.contains("Frango")
        })
        XCTAssertTrue(hasProteinSuggestion)
    }

    // MARK: - 2. Geração de sugestão quando calorias estiverem muito baixas (< 90% ou delta < -250 kcal)
    func testExcessiveDeficitSuggestion() {
        let rice = makeFoodItem(name: "Arroz branco cozido", cals: 130.0, prot: 2.7, carbs: 28.2, fat: 0.3)
        let lunchItem = PlannedMealItem(food: rice, amount: 100.0, unit: "g", calories: 130.0, proteinGrams: 2.7, carbsGrams: 28.2, fatGrams: 0.3, fiberGrams: 0.5)

        let lunch = makeMeal(mealType: .lunch, name: "Almoço", items: [lunchItem])
        let plan = makeTestPlan(meals: [lunch]) // Apenas 130 kcal

        let target = NutritionTarget(
            calories: 2200.0,
            proteinGrams: 160.0,
            carbsGrams: 250.0,
            fatGrams: 60.0,
            fiberGrams: 30.0,
            waterMl: 3000.0
        )

        let suggestions = MealPlanAdjustmentEngine.generateSuggestions(plan: plan, target: target, goal: .fatLoss)

        XCTAssertFalse(suggestions.isEmpty)
        let hasCarbIncreaseSuggestion = suggestions.contains(where: {
            $0.title.contains("Arroz") || $0.title.contains("Carboidrato") || $0.badgeLabel.contains("Carbos") || $0.badgeLabel.contains("kcal")
        })
        XCTAssertTrue(hasCarbIncreaseSuggestion)
    }

    // MARK: - 3. Geração de sugestão quando calorias estiverem acima da meta de corte
    func testCalorieSurplusSuggestion() {
        let azeite = makeFoodItem(name: "Azeite de oliva extra virgem", cals: 884.0, prot: 0.0, carbs: 0.0, fat: 100.0)
        let lunchItem = PlannedMealItem(food: azeite, amount: 20.0, unit: "ml", calories: 176.8, proteinGrams: 0.0, carbsGrams: 0.0, fatGrams: 20.0, fiberGrams: 0.0)

        let lunch = makeMeal(mealType: .lunch, name: "Almoço", items: [lunchItem])
        let plan = makeTestPlan(meals: [lunch])

        // Meta calórica baixa (ex: 150 kcal), plano com 176.8 kcal (> 105% em fatLoss)
        let target = NutritionTarget(
            calories: 150.0,
            proteinGrams: 10.0,
            carbsGrams: 10.0,
            fatGrams: 5.0,
            fiberGrams: 5.0,
            waterMl: 1000.0
        )

        let suggestions = MealPlanAdjustmentEngine.generateSuggestions(plan: plan, target: target, goal: .fatLoss)

        XCTAssertFalse(suggestions.isEmpty)
        let hasReductionSuggestion = suggestions.contains(where: {
            $0.title.contains("Reduzir") || $0.badgeLabel.contains("-")
        })
        XCTAssertTrue(hasReductionSuggestion)
    }

    // MARK: - 4. Testar MealPlanStore.updateItemAmount recalculando macros e totais corretamente
    func testMealPlanStoreUpdateItemAmount() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString).json")
        let store = MealPlanStore(storageURL: tempURL)

        let chicken = makeFoodItem(name: "Peito de frango grelhado", cals: 165.0, prot: 31.0, carbs: 0.0, fat: 3.6)
        let chickenItemId = UUID()
        let chickenItem = PlannedMealItem(
            id: chickenItemId,
            food: chicken,
            amount: 100.0,
            unit: "g",
            calories: 165.0,
            proteinGrams: 31.0,
            carbsGrams: 0.0,
            fatGrams: 3.6,
            fiberGrams: 0.0
        )

        let mealId = UUID()
        let meal = makeMeal(id: mealId, mealType: .lunch, name: "Almoço", items: [chickenItem])
        let initialPlan = makeTestPlan(meals: [meal])

        store.setActivePlan(initialPlan)
        XCTAssertEqual(store.activePlan?.totalCalories, 165.0)
        XCTAssertEqual(store.activePlan?.totalProtein, 31.0)

        // Atualiza a gramatura de 100g para 200g (deve dobrar: 330 kcal, 62g proteína)
        store.updateItemAmount(mealId: mealId, itemId: chickenItemId, newAmount: 200.0)

        guard let updatedPlan = store.activePlan else {
            XCTFail("activePlan não deve ser nil")
            return
        }

        XCTAssertEqual(updatedPlan.totalCalories, 330.0)
        XCTAssertEqual(updatedPlan.totalProtein, 62.0)
        XCTAssertEqual(updatedPlan.meals[0].items[0].amount, 200.0)
    }

    // MARK: - 5. Testar MealPlanStore.applyAdjustment aplicando sugestão e atingindo a meta
    func testMealPlanStoreApplyAdjustment() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString).json")
        let store = MealPlanStore(storageURL: tempURL)

        let rice = makeFoodItem(name: "Arroz branco cozido", cals: 130.0, prot: 2.7, carbs: 28.2, fat: 0.3)
        let riceItemId = UUID()
        let riceItem = PlannedMealItem(
            id: riceItemId,
            food: rice,
            amount: 100.0,
            unit: "g",
            calories: 130.0,
            proteinGrams: 2.7,
            carbsGrams: 28.2,
            fatGrams: 0.3,
            fiberGrams: 0.5
        )

        let mealId = UUID()
        let meal = makeMeal(id: mealId, mealType: .lunch, name: "Almoço", items: [riceItem])
        let initialPlan = makeTestPlan(meals: [meal])

        store.setActivePlan(initialPlan)

        let whey = makeFoodItem(name: "Whey Protein Concentrado 80%", cals: 400.0, prot: 80.0, carbs: 6.0, fat: 5.0)
        let suggestion = PlanAdjustmentSuggestion(
            title: "Reforçar Proteína",
            explanation: "Adicionar 30g de whey",
            actionType: .addFood(mealId: mealId, food: whey, amount: 30.0),
            macroImpact: MacroBreakdown(calories: 120.0, proteinGrams: 24.0, carbsGrams: 1.8, fatGrams: 1.5, fiberGrams: 0.0),
            badgeLabel: "+24g Proteína",
            buttonLabel: "Adicionar"
        )

        store.applyAdjustment(suggestion)

        guard let updatedPlan = store.activePlan else {
            XCTFail("activePlan não deve ser nil")
            return
        }

        XCTAssertEqual(updatedPlan.meals[0].items.count, 2)
        XCTAssertEqual(updatedPlan.totalCalories, 250.0) // 130 + 120
        XCTAssertEqual(updatedPlan.totalProtein, 26.7)   // 2.7 + 24.0
    }
}
