import Foundation

/// Tipo de ação prescritiva gerada pelo motor de ajustes para equilibrar o plano alimentar.
public enum AdjustmentActionType: Codable, Sendable, Equatable {
    case addFood(mealId: UUID, food: FoodItem, amount: Double)
    case scaleFood(mealId: UUID, itemId: UUID, newAmount: Double, originalAmount: Double)
    case removeFood(mealId: UUID, itemId: UUID)
}

/// Sugestão clínica inteligente para calibrar o plano alimentar e atingir a conformidade ideal das metas.
public struct PlanAdjustmentSuggestion: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var explanation: String
    public var actionType: AdjustmentActionType
    public var macroImpact: MacroBreakdown
    public var badgeLabel: String
    public var buttonLabel: String

    public init(
        id: UUID = UUID(),
        title: String,
        explanation: String,
        actionType: AdjustmentActionType,
        macroImpact: MacroBreakdown,
        badgeLabel: String,
        buttonLabel: String
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.actionType = actionType
        self.macroImpact = macroImpact
        self.badgeLabel = badgeLabel
        self.buttonLabel = buttonLabel
    }
}

/// Motor de inteligência nutricional para geração de sugestões clínicas de ajuste e controle de porções.
public enum MealPlanAdjustmentEngine {

    /// Gera até 3 sugestões clínicas mais relevantes e de maior impacto fisiológico para o plano atual.
    public static func generateSuggestions(
        plan: DailyMealPlan,
        target: NutritionTarget,
        goal: NutritionGoal? = nil,
        currentWeightKg: Double? = nil
    ) -> [PlanAdjustmentSuggestion] {
        guard !plan.meals.isEmpty else { return [] }

        var suggestions: [PlanAdjustmentSuggestion] = []

        let proteinDelta = plan.totalProtein - target.proteinGrams
        let calorieDelta = plan.totalCalories - target.calories

        // MARK: - 1. Proteína Baixa (Déficit proteico > 15g)
        if proteinDelta < -15.0 {
            let targetMeal = plan.meals.first(where: {
                $0.mealType == .afternoonSnack || $0.mealType == .morningSnack
            }) ?? plan.meals.min(by: { $0.totalProtein < $1.totalProtein }) ?? plan.meals[0]

            let wheyFood = TBCAFoodDatabase.foods.first(where: {
                $0.name.localizedCaseInsensitiveContains("whey")
            }) ?? FoodItem(
                name: "Whey Protein Concentrado 80%",
                servingSize: 30.0,
                servingUnit: "g",
                calories: 120.0,
                proteinGrams: 24.0,
                carbsGrams: 2.0,
                fatGrams: 1.5,
                fiberGrams: 0.0
            )

            let wheyAmount = 30.0
            let calc = wheyFood.calculatedFor(amount: wheyAmount)
            let impact = MacroBreakdown(
                calories: calc.calories,
                proteinGrams: calc.protein,
                carbsGrams: calc.carbs,
                fatGrams: calc.fat,
                fiberGrams: calc.fiber
            )

            suggestions.append(PlanAdjustmentSuggestion(
                title: "Reforçar Proteína no \(targetMeal.name)",
                explanation: "Faltam \(abs(Int(proteinDelta)))g de proteína para sua meta diária de preservação muscular.",
                actionType: .addFood(mealId: targetMeal.id, food: wheyFood, amount: wheyAmount),
                macroImpact: impact,
                badgeLabel: "+\(Int(calc.protein))g Proteína",
                buttonLabel: "Adicionar ao \(targetMeal.name)"
            ))

            // Se almoço ou jantar já tiver peito de frango, sugere aumentar a porção
            for meal in plan.meals where meal.mealType == .lunch || meal.mealType == .dinner {
                if let chickenItem = meal.items.first(where: { $0.food.name.localizedCaseInsensitiveContains("frango") }) {
                    let additionalGrams = 50.0
                    let newAmount = chickenItem.amount + additionalGrams
                    let addCalc = chickenItem.food.calculatedFor(amount: additionalGrams)
                    let scaleImpact = MacroBreakdown(
                        calories: addCalc.calories,
                        proteinGrams: addCalc.protein,
                        carbsGrams: addCalc.carbs,
                        fatGrams: addCalc.fat,
                        fiberGrams: addCalc.fiber
                    )

                    suggestions.append(PlanAdjustmentSuggestion(
                        title: "Aumentar Frango no \(meal.name)",
                        explanation: "Aumentar 50g de frango adiciona \(Int(addCalc.protein))g de proteína de alto valor biológico.",
                        actionType: .scaleFood(mealId: meal.id, itemId: chickenItem.id, newAmount: newAmount, originalAmount: chickenItem.amount),
                        macroImpact: scaleImpact,
                        badgeLabel: "+\(Int(addCalc.protein))g Proteína",
                        buttonLabel: "Aumentar +50g Frango"
                    ))
                    break
                }
            }
        }

        // MARK: - 2. Gordura Baixa (< 35g ou < 0.5g/kg de peso corporal)
        let isFatCriticallyLow = plan.totalFat < 35.0 || (currentWeightKg != nil && currentWeightKg! > 0 && (plan.totalFat / currentWeightKg!) < 0.5)
        if isFatCriticallyLow {
            let targetMeal = plan.meals.first(where: {
                $0.mealType == .lunch || $0.mealType == .dinner
            }) ?? plan.meals[0]

            let azeiteFood = TBCAFoodDatabase.foods.first(where: {
                $0.name.localizedCaseInsensitiveContains("azeite")
            }) ?? FoodItem(
                name: "Azeite de oliva extra virgem",
                servingSize: 13.0,
                servingUnit: "ml",
                calories: 108.0,
                proteinGrams: 0.0,
                carbsGrams: 0.0,
                fatGrams: 12.0,
                fiberGrams: 0.0
            )

            let azeiteAmount = 10.0
            let calc = azeiteFood.calculatedFor(amount: azeiteAmount)
            let impact = MacroBreakdown(
                calories: calc.calories,
                proteinGrams: calc.protein,
                carbsGrams: calc.carbs,
                fatGrams: calc.fat,
                fiberGrams: calc.fiber
            )

            suggestions.append(PlanAdjustmentSuggestion(
                title: "Adicionar Azeite para Suporte Hormonal",
                explanation: "Gorduras totais estão baixas (\(Int(plan.totalFat))g). 10g de azeite asseguram síntese hormonal e absorção de vitaminas lipossolúveis.",
                actionType: .addFood(mealId: targetMeal.id, food: azeiteFood, amount: azeiteAmount),
                macroImpact: impact,
                badgeLabel: "+\(Int(calc.fat))g Gordura Boa",
                buttonLabel: "Adicionar Azeite ao \(targetMeal.name)"
            ))
        }

        // MARK: - 3. Déficit Excessivo (Calorias < 90% da meta ou delta < -250 kcal)
        if (plan.totalCalories / max(1.0, target.calories) < 0.90) || (calorieDelta < -250.0) {
            var scaledRice = false
            for meal in plan.meals where meal.mealType == .lunch || meal.mealType == .dinner {
                if let riceItem = meal.items.first(where: { $0.food.name.localizedCaseInsensitiveContains("arroz") }) {
                    let additionalGrams = 60.0
                    let newAmount = riceItem.amount + additionalGrams
                    let addCalc = riceItem.food.calculatedFor(amount: additionalGrams)
                    let scaleImpact = MacroBreakdown(
                        calories: addCalc.calories,
                        proteinGrams: addCalc.protein,
                        carbsGrams: addCalc.carbs,
                        fatGrams: addCalc.fat,
                        fiberGrams: addCalc.fiber
                    )

                    suggestions.append(PlanAdjustmentSuggestion(
                        title: "Aumentar Arroz para Déficit Seguro",
                        explanation: "O plano está \(abs(Int(calorieDelta))) kcal abaixo do ideal. Aumentar carboidratos preserva o metabolismo e a energia.",
                        actionType: .scaleFood(mealId: meal.id, itemId: riceItem.id, newAmount: newAmount, originalAmount: riceItem.amount),
                        macroImpact: scaleImpact,
                        badgeLabel: "+\(Int(addCalc.carbs))g Carbos",
                        buttonLabel: "Aumentar +60g Arroz"
                    ))
                    scaledRice = true
                    break
                }
            }

            if !scaledRice {
                let targetMeal = plan.meals.first(where: { $0.mealType == .lunch || $0.mealType == .dinner }) ?? plan.meals[0]
                let batataFood = TBCAFoodDatabase.foods.first(where: {
                    $0.name.localizedCaseInsensitiveContains("batata-doce")
                }) ?? FoodItem(
                    name: "Batata-doce cozida",
                    servingSize: 100.0,
                    servingUnit: "g",
                    calories: 77.0,
                    proteinGrams: 0.6,
                    carbsGrams: 18.4,
                    fatGrams: 0.1,
                    fiberGrams: 2.2
                )
                let amount = 100.0
                let calc = batataFood.calculatedFor(amount: amount)
                let impact = MacroBreakdown(
                    calories: calc.calories,
                    proteinGrams: calc.protein,
                    carbsGrams: calc.carbs,
                    fatGrams: calc.fat,
                    fiberGrams: calc.fiber
                )

                suggestions.append(PlanAdjustmentSuggestion(
                    title: "Adicionar Carboidrato Complexo",
                    explanation: "O plano está \(abs(Int(calorieDelta))) kcal abaixo do ideal. Adicione 100g de batata-doce para estabilizar o déficit.",
                    actionType: .addFood(mealId: targetMeal.id, food: batataFood, amount: amount),
                    macroImpact: impact,
                    badgeLabel: "+77 kcal",
                    buttonLabel: "Adicionar Batata-Doce"
                ))
            }
        }

        // MARK: - 4. Superávit Involuntário / Calorias Altas (> 105% em fatLoss ou delta > +150 kcal)
        let isCalorieSurplus = (goal == .fatLoss && plan.totalCalories / max(1.0, target.calories) > 1.05) || (calorieDelta > 150.0)
        if isCalorieSurplus {
            var reducedFatOrCarb = false

            // Procura azeite para reduzir
            for meal in plan.meals {
                if let azeiteItem = meal.items.first(where: {
                    $0.food.name.localizedCaseInsensitiveContains("azeite") && $0.amount >= 13.0
                }) {
                    let reduceGrams = 10.0
                    let newAmount = max(3.0, azeiteItem.amount - reduceGrams)
                    let redCalc = azeiteItem.food.calculatedFor(amount: reduceGrams)
                    let impact = MacroBreakdown(
                        calories: -redCalc.calories,
                        proteinGrams: -redCalc.protein,
                        carbsGrams: -redCalc.carbs,
                        fatGrams: -redCalc.fat,
                        fiberGrams: -redCalc.fiber
                    )

                    suggestions.append(PlanAdjustmentSuggestion(
                        title: "Reduzir Azeite de Oliva no \(meal.name)",
                        explanation: "Reduzir 10g de azeite economiza ~88 kcal sem diminuir volume ou saciedade, mantendo o déficit.",
                        actionType: .scaleFood(mealId: meal.id, itemId: azeiteItem.id, newAmount: newAmount, originalAmount: azeiteItem.amount),
                        macroImpact: impact,
                        badgeLabel: "-\(Int(redCalc.calories)) kcal",
                        buttonLabel: "Reduzir 10g Azeite"
                    ))
                    reducedFatOrCarb = true
                    break
                }
            }

            // Procura arroz para reduzir no jantar ou almoço
            if !reducedFatOrCarb {
                for meal in plan.meals.reversed() where meal.mealType == .dinner || meal.mealType == .lunch {
                    if let riceItem = meal.items.first(where: {
                        $0.food.name.localizedCaseInsensitiveContains("arroz") && $0.amount >= 100.0
                    }) {
                        let reduceGrams = 50.0
                        let newAmount = riceItem.amount - reduceGrams
                        let redCalc = riceItem.food.calculatedFor(amount: reduceGrams)
                        let impact = MacroBreakdown(
                            calories: -redCalc.calories,
                            proteinGrams: -redCalc.protein,
                            carbsGrams: -redCalc.carbs,
                            fatGrams: -redCalc.fat,
                            fiberGrams: -redCalc.fiber
                        )

                        suggestions.append(PlanAdjustmentSuggestion(
                            title: "Ajustar Porção de Arroz no \(meal.name)",
                            explanation: "Diminuir 50g de arroz economiza \(Int(redCalc.calories)) kcal preservando a adesão ao déficit.",
                            actionType: .scaleFood(mealId: meal.id, itemId: riceItem.id, newAmount: newAmount, originalAmount: riceItem.amount),
                            macroImpact: impact,
                            badgeLabel: "-\(Int(redCalc.calories)) kcal",
                            buttonLabel: "Reduzir 50g Arroz"
                        ))
                        reducedFatOrCarb = true
                        break
                    }
                }
            }
        }

        // Limita a até 3 sugestões de maior impacto clínico
        return Array(suggestions.prefix(3))
    }

    /// Aplica uma sugestão de ajuste diretamente sobre a estrutura de um DailyMealPlan, gerando um novo plano imutável.
    public static func apply(suggestion: PlanAdjustmentSuggestion, to plan: DailyMealPlan) -> DailyMealPlan {
        var updatedMeals = plan.meals

        switch suggestion.actionType {
        case .addFood(let mealId, let food, let amount):
            guard let mealIdx = updatedMeals.firstIndex(where: { $0.id == mealId }) else { return plan }
            let validAmount = max(1.0, amount.rounded(to: 1))
            let calc = food.calculatedFor(amount: validAmount)
            let item = PlannedMealItem(
                food: food,
                amount: validAmount,
                unit: food.servingUnit,
                portionName: nil,
                calories: calc.calories,
                proteinGrams: calc.protein,
                carbsGrams: calc.carbs,
                fatGrams: calc.fat,
                fiberGrams: calc.fiber
            )
            var items = updatedMeals[mealIdx].items
            items.append(item)
            let m = updatedMeals[mealIdx]
            updatedMeals[mealIdx] = PlannedMeal(
                id: m.id,
                mealType: m.mealType,
                name: m.name,
                suggestedTime: m.suggestedTime,
                targetCalories: m.targetCalories,
                items: items
            )

        case .scaleFood(let mealId, let itemId, let newAmount, _):
            guard let mealIdx = updatedMeals.firstIndex(where: { $0.id == mealId }) else { return plan }
            var items = updatedMeals[mealIdx].items
            guard let itemIdx = items.firstIndex(where: { $0.id == itemId }) else { return plan }
            let oldItem = items[itemIdx]
            let validAmount = max(1.0, newAmount.rounded(to: 1))
            let calc = oldItem.food.calculatedFor(amount: validAmount)
            items[itemIdx] = PlannedMealItem(
                id: oldItem.id,
                food: oldItem.food,
                amount: validAmount,
                unit: oldItem.unit,
                portionName: oldItem.portionName,
                calories: calc.calories,
                proteinGrams: calc.protein,
                carbsGrams: calc.carbs,
                fatGrams: calc.fat,
                fiberGrams: calc.fiber
            )
            let m = updatedMeals[mealIdx]
            updatedMeals[mealIdx] = PlannedMeal(
                id: m.id,
                mealType: m.mealType,
                name: m.name,
                suggestedTime: m.suggestedTime,
                targetCalories: m.targetCalories,
                items: items
            )

        case .removeFood(let mealId, let itemId):
            guard let mealIdx = updatedMeals.firstIndex(where: { $0.id == mealId }) else { return plan }
            var items = updatedMeals[mealIdx].items
            items.removeAll(where: { $0.id == itemId })
            let m = updatedMeals[mealIdx]
            updatedMeals[mealIdx] = PlannedMeal(
                id: m.id,
                mealType: m.mealType,
                name: m.name,
                suggestedTime: m.suggestedTime,
                targetCalories: m.targetCalories,
                items: items
            )
        }

        return DailyMealPlan(
            id: plan.id,
            createdAt: plan.createdAt,
            targetCalories: plan.targetCalories,
            targetProteinGrams: plan.targetProteinGrams,
            targetCarbsGrams: plan.targetCarbsGrams,
            targetFatGrams: plan.targetFatGrams,
            targetFiberGrams: plan.targetFiberGrams,
            meals: updatedMeals
        )
    }
}
