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

    // MARK: - 6. Testar Distribuição Multi-Refeição de Carboidratos (Almoço e Jantar)
    func testMultiMealCarbDistributionSuggestion() {
        let rice = makeFoodItem(name: "Arroz branco cozido", cals: 130.0, prot: 2.7, carbs: 28.2, fat: 0.3)
        let lunchRice = PlannedMealItem(food: rice, amount: 120.0, unit: "g", calories: 156.0, proteinGrams: 3.2, carbsGrams: 33.8, fatGrams: 0.4, fiberGrams: 0.6)
        let dinnerRice = PlannedMealItem(food: rice, amount: 100.0, unit: "g", calories: 130.0, proteinGrams: 2.7, carbsGrams: 28.2, fatGrams: 0.3, fiberGrams: 0.5)

        let lunch = makeMeal(mealType: .lunch, name: "Almoço", items: [lunchRice])
        let dinner = makeMeal(mealType: .dinner, name: "Jantar", items: [dinnerRice])
        let plan = makeTestPlan(meals: [lunch, dinner]) // ~286 kcal

        let target = NutritionTarget(
            calories: 2000.0,
            proteinGrams: 150.0,
            carbsGrams: 220.0,
            fatGrams: 55.0,
            waterMl: 2800.0
        )

        let suggestions = MealPlanAdjustmentEngine.generateSuggestions(plan: plan, target: target, goal: .fatLoss)

        XCTAssertFalse(suggestions.isEmpty)
        // Deve sugerir distribuição de arroz entre almoço e jantar via batchScaleFood
        guard let distributedSuggestion = suggestions.first(where: {
            $0.title.contains("Distribuir Arroz") || $0.badgeLabel.contains("2 Refeições")
        }) else {
            XCTFail("Deve conter sugestão de distribuição multi-refeição")
            return
        }

        if case .batchScaleFood(let targets) = distributedSuggestion.actionType {
            XCTAssertEqual(targets.count, 2)
            XCTAssertEqual(targets[0].newAmount, 155.0) // 120 + 35
            XCTAssertEqual(targets[1].newAmount, 135.0) // 100 + 35
        } else {
            XCTFail("actionType deve ser .batchScaleFood")
        }

        // Testar a aplicação no plano imutável
        let updatedPlan = MealPlanAdjustmentEngine.apply(suggestion: distributedSuggestion, to: plan)
        XCTAssertEqual(updatedPlan.meals[0].items[0].amount, 155.0)
        XCTAssertEqual(updatedPlan.meals[1].items[0].amount, 135.0)
    }

    // MARK: - 7. Testar Detecção e Normalização de Porção Aberrante (790g de arroz do screenshot)
    func testOverloadedRiceSafetyCapAndNormalization() {
        let rice = makeFoodItem(name: "Arroz branco cozido", cals: 130.0, prot: 2.7, carbs: 28.2, fat: 0.3)
        // 790g de arroz no almoço (1027 kcal)
        let lunchRice = PlannedMealItem(food: rice, amount: 790.0, unit: "g", calories: 1027.0, proteinGrams: 21.3, carbsGrams: 222.8, fatGrams: 2.4, fiberGrams: 4.0)

        let lunch = makeMeal(mealType: .lunch, name: "Almoço Balanceado", items: [lunchRice])
        let plan = makeTestPlan(meals: [lunch])

        let target = NutritionTarget(
            calories: 2000.0,
            proteinGrams: 150.0,
            carbsGrams: 220.0,
            fatGrams: 55.0,
            waterMl: 2800.0
        )

        let suggestions = MealPlanAdjustmentEngine.generateSuggestions(plan: plan, target: target, goal: .fatLoss)

        XCTAssertFalse(suggestions.isEmpty)
        // Deve sugerir imediatamente normalizar a porção de arroz
        guard let normalizationSuggestion = suggestions.first(where: {
            $0.title.contains("Normalizar Arroz") || $0.title.contains("Redistribuir Arroz")
        }) else {
            XCTFail("Deve detectar a porção de 790g e sugerir normalização")
            return
        }

        XCTAssertTrue(normalizationSuggestion.badgeLabel.contains("kcal") || normalizationSuggestion.badgeLabel.contains("Rebalancear"))

        // Aplicar a normalização
        let correctedPlan = MealPlanAdjustmentEngine.apply(suggestion: normalizationSuggestion, to: plan)
        XCTAssertEqual(correctedPlan.meals[0].items[0].amount, MealPlanAdjustmentEngine.targetStandardRiceServingGrams)
        XCTAssertLessThan(correctedPlan.totalCalories, 300.0)
    }

    // MARK: - 8. Testar Calibração e Rebalanceamento Automático Global de Todas as Refeições
    func testAutoRebalancePlanDistributesMacrosHarmoniouslyAcrossMeals() {
        let rice = makeFoodItem(name: "Arroz branco cozido", cals: 130.0, prot: 2.7, carbs: 28.2, fat: 0.3)
        let chicken = makeFoodItem(name: "Peito de frango grelhado", cals: 165.0, prot: 31.0, carbs: 0.0, fat: 3.6)
        let azeite = makeFoodItem(name: "Azeite de oliva extra virgem", cals: 884.0, prot: 0.0, carbs: 0.0, fat: 100.0)
        let bread = makeFoodItem(name: "Pão francês", cals: 300.0, prot: 8.0, carbs: 58.0, fat: 3.0)
        let eggs = makeFoodItem(name: "Ovos mexidos", cals: 150.0, prot: 12.0, carbs: 1.5, fat: 11.0)

        // Café: Pão e Ovos
        let b1 = PlannedMealItem(food: bread, amount: 50.0, unit: "g", calories: 150.0, proteinGrams: 4.0, carbsGrams: 29.0, fatGrams: 1.5, fiberGrams: 1.0)
        let b2 = PlannedMealItem(food: eggs, amount: 100.0, unit: "g", calories: 150.0, proteinGrams: 12.0, carbsGrams: 1.5, fatGrams: 11.0, fiberGrams: 0.0)
        let breakfast = makeMeal(mealType: .breakfast, name: "Café da Manhã", items: [b1, b2])

        // Almoço com os 790g de arroz do screenshot
        let l1 = PlannedMealItem(food: rice, amount: 790.0, unit: "g", calories: 1027.0, proteinGrams: 21.3, carbsGrams: 222.8, fatGrams: 2.4, fiberGrams: 4.0)
        let l2 = PlannedMealItem(food: chicken, amount: 150.0, unit: "g", calories: 247.5, proteinGrams: 46.5, carbsGrams: 0.0, fatGrams: 5.4, fiberGrams: 0.0)
        let l3 = PlannedMealItem(food: azeite, amount: 10.0, unit: "ml", calories: 88.4, proteinGrams: 0.0, carbsGrams: 0.0, fatGrams: 10.0, fiberGrams: 0.0)
        let lunch = makeMeal(mealType: .lunch, name: "Almoço", items: [l1, l2, l3])

        // Lanche com Aveia e Whey
        let oats = makeFoodItem(name: "Aveia em flocos", cals: 360.0, prot: 14.0, carbs: 60.0, fat: 7.0)
        let s1 = PlannedMealItem(food: oats, amount: 30.0, unit: "g", calories: 108.0, proteinGrams: 4.2, carbsGrams: 18.0, fatGrams: 2.1, fiberGrams: 3.0)
        let snack = makeMeal(mealType: .afternoonSnack, name: "Lanche da Tarde", items: [s1])

        // Jantar com porção tímida
        let d1 = PlannedMealItem(food: rice, amount: 80.0, unit: "g", calories: 104.0, proteinGrams: 2.2, carbsGrams: 22.6, fatGrams: 0.2, fiberGrams: 0.4)
        let d2 = PlannedMealItem(food: chicken, amount: 100.0, unit: "g", calories: 165.0, proteinGrams: 31.0, carbsGrams: 0.0, fatGrams: 3.6, fiberGrams: 0.0)
        let dinner = makeMeal(mealType: .dinner, name: "Jantar", items: [d1, d2])

        let uncalibratedPlan = makeTestPlan(meals: [breakfast, lunch, snack, dinner])

        let target = NutritionTarget(
            calories: 2200.0,
            proteinGrams: 150.0,
            carbsGrams: 240.0,
            fatGrams: 60.0,
            waterMl: 3000.0
        )

        // Executar a calibração automática global
        let calibratedPlan = MealPlanAdjustmentEngine.autoRebalancePlan(plan: uncalibratedPlan, target: target)

        // 1. Arroz do almoço não pode mais ser 790g, deve ter sido normalizado para <= 220g
        let lunchRiceItem = calibratedPlan.meals[1].items[0]
        XCTAssertLessThanOrEqual(lunchRiceItem.amount, 220.0, "Arroz do almoço deve respeitar o teto fisiológico de 220g")
        XCTAssertGreaterThanOrEqual(lunchRiceItem.amount, 120.0)

        // 2. Arroz do jantar deve ter recebido carboidratos de forma equilibrada (>= 100g)
        let dinnerRiceItem = calibratedPlan.meals[3].items[0]
        XCTAssertGreaterThanOrEqual(dinnerRiceItem.amount, 100.0, "Jantar deve ter porção de carboidrato equilibrada")
        XCTAssertLessThanOrEqual(dinnerRiceItem.amount, 220.0)

        // 3. Totais do plano rebalanceado devem estar alinhados com a meta diária (tolerância clínica)
        XCTAssertEqual(calibratedPlan.totalCalories, target.calories, accuracy: 150.0)
        XCTAssertEqual(calibratedPlan.totalProtein, target.proteinGrams, accuracy: 20.0)
        XCTAssertEqual(calibratedPlan.totalCarbs, target.carbsGrams, accuracy: 30.0)
    }

    // MARK: - 9. Testar MealPlanStore.autoRebalanceActivePlan persistindo e sincronizando
    func testMealPlanStoreAutoRebalance() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_rebalance_\(UUID().uuidString).json")
        let store = MealPlanStore(storageURL: tempURL)

        let rice = makeFoodItem(name: "Arroz branco cozido", cals: 130.0, prot: 2.7, carbs: 28.2, fat: 0.3)
        let l1 = PlannedMealItem(food: rice, amount: 790.0, unit: "g", calories: 1027.0, proteinGrams: 21.3, carbsGrams: 222.8, fatGrams: 2.4, fiberGrams: 4.0)
        let lunch = makeMeal(mealType: .lunch, name: "Almoço", items: [l1])
        let plan = makeTestPlan(meals: [lunch])

        store.setActivePlan(plan)
        XCTAssertEqual(store.activePlan?.meals[0].items[0].amount, 790.0)

        let target = NutritionTarget(calories: 2000.0, proteinGrams: 150.0, carbsGrams: 220.0, fatGrams: 55.0, waterMl: 2800.0)
        store.autoRebalanceActivePlan(target: target)

        guard let rebalanced = store.activePlan else {
            XCTFail("activePlan não deve ser nil")
            return
        }

        XCTAssertLessThanOrEqual(rebalanced.meals[0].items[0].amount, 220.0)
        XCTAssertLessThan(rebalanced.totalCalories, 1000.0)
    }

    // MARK: - 10. Testar conversão e formatação de frutas e alimentos unitários
    func testFoodItemUnitConversionsForFruitsAndHouseholdItems() {
        let banana = makeFoodItem(name: "Banana prata crua", cals: 89.0, prot: 1.1, carbs: 22.8, fat: 0.3)
        XCTAssertNotNil(banana.referenceUnitPortion)
        XCTAssertEqual(banana.referenceUnitPortion?.gramWeight, 70.0)

        // 140g de banana -> 2 unidades
        let units = banana.unitsForAmount(140.0)
        XCTAssertEqual(units, 2.0)

        let formattedPreferUnits = banana.formattedPortion(amount: 140.0, preferUnits: true)
        XCTAssertEqual(formattedPreferUnits, "2 unidades (140g)")

        let formattedPreferGrams = banana.formattedPortion(amount: 140.0, preferUnits: false)
        XCTAssertEqual(formattedPreferGrams, "140g")

        // Ovo -> 1 unidade = 50g
        let egg = makeFoodItem(name: "Ovo de galinha cozido", cals: 155.0, prot: 13.0, carbs: 1.1, fat: 10.6)
        XCTAssertEqual(egg.formattedPortion(amount: 100.0, preferUnits: true), "2 unidades (100g)")

        // Pão de forma -> 2 fatias = 50g
        let bread = makeFoodItem(name: "Pão de forma integral", cals: 247.0, prot: 9.4, carbs: 45.0, fat: 3.5)
        XCTAssertEqual(bread.formattedPortion(amount: 50.0, preferUnits: true), "2 fatias (50g)")
    }

    // MARK: - 11. Testar MealPlanStore.updateItemAmount com portionName explícito
    func testMealPlanStoreUpdateItemAmountWithExplicitPortionName() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_portion_\(UUID().uuidString).json")
        let store = MealPlanStore(storageURL: tempURL)

        let banana = makeFoodItem(name: "Banana prata crua", cals: 89.0, prot: 1.1, carbs: 22.8, fat: 0.3)
        let itemId = UUID()
        let item = PlannedMealItem(id: itemId, food: banana, amount: 70.0, unit: "g", calories: 62.0, proteinGrams: 0.8, carbsGrams: 16.0, fatGrams: 0.2, fiberGrams: 1.4)
        let mealId = UUID()
        let meal = makeMeal(id: mealId, mealType: .afternoonSnack, name: "Lanche", items: [item])
        let plan = makeTestPlan(meals: [meal])

        store.setActivePlan(plan)

        // Atualiza para 140g com porção "2 unidades"
        store.updateItemAmount(mealId: mealId, itemId: itemId, newAmount: 140.0, portionName: "2 unidades")

        let updatedItem = store.activePlan?.meals[0].items[0]
        XCTAssertEqual(updatedItem?.amount, 140.0)
        XCTAssertEqual(updatedItem?.portionName, "2 unidades")
        XCTAssertEqual(updatedItem?.calories ?? 0, 124.6, accuracy: 1.0)
    }
}
