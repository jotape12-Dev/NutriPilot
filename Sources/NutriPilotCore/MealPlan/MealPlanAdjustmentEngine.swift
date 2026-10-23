import Foundation

/// Alvo individual de redimensionamento de porção em lote para distribuição multi-refeição.
public struct ScaledItemTarget: Codable, Sendable, Equatable {
    public let mealId: UUID
    public let itemId: UUID
    public let newAmount: Double
    public let originalAmount: Double

    public init(mealId: UUID, itemId: UUID, newAmount: Double, originalAmount: Double) {
        self.mealId = mealId
        self.itemId = itemId
        self.newAmount = newAmount
        self.originalAmount = originalAmount
    }
}

/// Tipo de ação prescritiva gerada pelo motor de ajustes para equilibrar o plano alimentar.
public enum AdjustmentActionType: Codable, Sendable, Equatable {
    case addFood(mealId: UUID, food: FoodItem, amount: Double)
    case scaleFood(mealId: UUID, itemId: UUID, newAmount: Double, originalAmount: Double)
    case removeFood(mealId: UUID, itemId: UUID)
    case batchScaleFood(targets: [ScaledItemTarget])
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

    // Limites fisiológicos e clínicos de segurança para porções individuais por refeição
    public static let maxSingleServingRiceGrams: Double = 250.0
    public static let targetStandardRiceServingGrams: Double = 180.0
    public static let maxSingleServingMeatGrams: Double = 250.0
    public static let maxSingleServingOliveOilGrams: Double = 20.0

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

        // MARK: - 0. Detecção Prioritária de Refeição Hipercalórica / Porção Aberrante (Safety Cap)
        for meal in plan.meals {
            if let overloadedRice = meal.items.first(where: {
                $0.food.name.localizedCaseInsensitiveContains("arroz") && $0.amount > maxSingleServingRiceGrams
            }) {
                let otherMeal = plan.meals.first(where: {
                    $0.id != meal.id && ($0.mealType == .dinner || $0.mealType == .lunch)
                })

                if let otherMeal = otherMeal,
                   let otherRice = otherMeal.items.first(where: { $0.food.name.localizedCaseInsensitiveContains("arroz") }),
                   otherRice.amount < 200.0 {
                    // Redistribui o excesso entre o almoço e jantar
                    let newCurrentAmount = targetStandardRiceServingGrams
                    let neededForOther = min(targetStandardRiceServingGrams, otherRice.amount + 60.0)

                    let targets = [
                        ScaledItemTarget(mealId: meal.id, itemId: overloadedRice.id, newAmount: newCurrentAmount, originalAmount: overloadedRice.amount),
                        ScaledItemTarget(mealId: otherMeal.id, itemId: otherRice.id, newAmount: neededForOther, originalAmount: otherRice.amount)
                    ]

                    let deltaCurrent = newCurrentAmount - overloadedRice.amount
                    let deltaOther = neededForOther - otherRice.amount
                    let c1 = overloadedRice.food.calculatedFor(amount: abs(deltaCurrent))
                    let c2 = otherRice.food.calculatedFor(amount: abs(deltaOther))

                    let netCalories = (deltaCurrent < 0 ? -c1.calories : c1.calories) + (deltaOther < 0 ? -c2.calories : c2.calories)
                    let netProtein = (deltaCurrent < 0 ? -c1.protein : c1.protein) + (deltaOther < 0 ? -c2.protein : c2.protein)
                    let netCarbs = (deltaCurrent < 0 ? -c1.carbs : c1.carbs) + (deltaOther < 0 ? -c2.carbs : c2.carbs)
                    let netFat = (deltaCurrent < 0 ? -c1.fat : c1.fat) + (deltaOther < 0 ? -c2.fat : c2.fat)
                    let netFiber = (deltaCurrent < 0 ? -c1.fiber : c1.fiber) + (deltaOther < 0 ? -c2.fiber : c2.fiber)

                    let impact = MacroBreakdown(
                        calories: netCalories,
                        proteinGrams: netProtein,
                        carbsGrams: netCarbs,
                        fatGrams: netFat,
                        fiberGrams: netFiber
                    )

                    suggestions.append(PlanAdjustmentSuggestion(
                        title: "Redistribuir Arroz entre Almoço e Jantar",
                        explanation: "A porção de \(Int(overloadedRice.amount))g no \(meal.name) excede a capacidade digestiva. Equilibrar em \(Int(newCurrentAmount))g no almoço e \(Int(neededForOther))g no jantar normaliza as calorias.",
                        actionType: .batchScaleFood(targets: targets),
                        macroImpact: impact,
                        badgeLabel: "Rebalancear Refeições",
                        buttonLabel: "Redistribuir Arroz no Dia"
                    ))
                } else {
                    // Normalização direta para 180g
                    let newAmount = targetStandardRiceServingGrams
                    let diff = overloadedRice.amount - newAmount
                    let diffCalc = overloadedRice.food.calculatedFor(amount: diff)
                    let impact = MacroBreakdown(
                        calories: -diffCalc.calories,
                        proteinGrams: -diffCalc.protein,
                        carbsGrams: -diffCalc.carbs,
                        fatGrams: -diffCalc.fat,
                        fiberGrams: -diffCalc.fiber
                    )

                    suggestions.append(PlanAdjustmentSuggestion(
                        title: "Normalizar Arroz do \(meal.name)",
                        explanation: "A porção de \(Int(overloadedRice.amount))g de arroz no \(meal.name) está excessiva. Reduzir para \(Int(newAmount))g normaliza as calorias do plano.",
                        actionType: .scaleFood(mealId: meal.id, itemId: overloadedRice.id, newAmount: newAmount, originalAmount: overloadedRice.amount),
                        macroImpact: impact,
                        badgeLabel: "-\(Int(diffCalc.calories)) kcal",
                        buttonLabel: "Normalizar para \(Int(newAmount))g"
                    ))
                }
                break
            }
        }

        // MARK: - 1. Proteína Baixa (Déficit proteico > 15g)
        if proteinDelta < -15.0 {
            // Verifica se tanto almoço quanto jantar possuem frango para distribuição multi-refeição
            var chickenTargets: [(meal: PlannedMeal, item: PlannedMealItem)] = []
            for meal in plan.meals where meal.mealType == .lunch || meal.mealType == .dinner {
                if let chickenItem = meal.items.first(where: {
                    $0.food.name.localizedCaseInsensitiveContains("frango") && $0.amount < maxSingleServingMeatGrams
                }) {
                    chickenTargets.append((meal, chickenItem))
                }
            }

            if chickenTargets.count >= 2 {
                let perMealAdd = 25.0 // +25g no almoço e +25g no jantar = +50g frango (~16g proteína)
                var scaleTargets: [ScaledItemTarget] = []
                var totalImpact = MacroBreakdown(calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0, fiberGrams: 0)

                for (m, item) in chickenTargets {
                    let newAmount = min(maxSingleServingMeatGrams, item.amount + perMealAdd)
                    scaleTargets.append(ScaledItemTarget(mealId: m.id, itemId: item.id, newAmount: newAmount, originalAmount: item.amount))
                    let calc = item.food.calculatedFor(amount: newAmount - item.amount)
                    totalImpact = MacroBreakdown(
                        calories: totalImpact.calories + calc.calories,
                        proteinGrams: totalImpact.proteinGrams + calc.protein,
                        carbsGrams: totalImpact.carbsGrams + calc.carbs,
                        fatGrams: totalImpact.fatGrams + calc.fat,
                        fiberGrams: totalImpact.fiberGrams + calc.fiber
                    )
                }

                suggestions.append(PlanAdjustmentSuggestion(
                    title: "Distribuir Frango no Almoço e Jantar",
                    explanation: "Aumentar +25g de frango no almoço e +25g no jantar fraciona a proteína ao longo do dia para máxima absorção.",
                    actionType: .batchScaleFood(targets: scaleTargets),
                    macroImpact: totalImpact,
                    badgeLabel: "+\(Int(totalImpact.proteinGrams))g Proteína (2 Refeições)",
                    buttonLabel: "Distribuir (+25g / +25g)"
                ))
            } else if let (singleMeal, chickenItem) = chickenTargets.first {
                let additionalGrams = 40.0
                let newAmount = min(maxSingleServingMeatGrams, chickenItem.amount + additionalGrams)
                let addCalc = chickenItem.food.calculatedFor(amount: newAmount - chickenItem.amount)
                let scaleImpact = MacroBreakdown(
                    calories: addCalc.calories,
                    proteinGrams: addCalc.protein,
                    carbsGrams: addCalc.carbs,
                    fatGrams: addCalc.fat,
                    fiberGrams: addCalc.fiber
                )

                suggestions.append(PlanAdjustmentSuggestion(
                    title: "Aumentar Frango no \(singleMeal.name)",
                    explanation: "Aumentar \(Int(newAmount - chickenItem.amount))g de frango adiciona \(Int(addCalc.protein))g de proteína de alto valor biológico.",
                    actionType: .scaleFood(mealId: singleMeal.id, itemId: chickenItem.id, newAmount: newAmount, originalAmount: chickenItem.amount),
                    macroImpact: scaleImpact,
                    badgeLabel: "+\(Int(addCalc.protein))g Proteína",
                    buttonLabel: "Aumentar +\(Int(newAmount - chickenItem.amount))g Frango"
                ))
            }

            // Sugestão alternativa de Whey Protein no lanche
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
                title: "Reforçar Proteína com Whey no \(targetMeal.name)",
                explanation: "Faltam \(abs(Int(proteinDelta)))g de proteína para sua meta diária de preservação muscular.",
                actionType: .addFood(mealId: targetMeal.id, food: wheyFood, amount: wheyAmount),
                macroImpact: impact,
                badgeLabel: "+\(Int(calc.protein))g Proteína",
                buttonLabel: "Adicionar Whey ao \(targetMeal.name)"
            ))
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

        // MARK: - 3. Déficit Excessivo (Calorias < 90% da meta ou delta < -250 kcal) - Distribuição Multi-Refeição
        if (plan.totalCalories / max(1.0, target.calories) < 0.90) || (calorieDelta < -250.0) {
            var riceTargets: [(meal: PlannedMeal, item: PlannedMealItem)] = []
            for meal in plan.meals where meal.mealType == .lunch || meal.mealType == .dinner {
                if let riceItem = meal.items.first(where: {
                    $0.food.name.localizedCaseInsensitiveContains("arroz") && $0.amount < maxSingleServingRiceGrams
                }) {
                    riceTargets.append((meal, riceItem))
                }
            }

            if riceTargets.count >= 2 {
                // Distribui igualmente entre Almoço e Jantar para não sobrecarregar nenhuma refeição
                let perMealAdd = 35.0 // +35g no almoço e +35g no jantar = +70g total (~91 kcal, 20g carbos)
                var scaleTargets: [ScaledItemTarget] = []
                var totalImpact = MacroBreakdown(calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0, fiberGrams: 0)

                for (m, item) in riceTargets {
                    let newAmount = min(maxSingleServingRiceGrams, item.amount + perMealAdd)
                    scaleTargets.append(ScaledItemTarget(mealId: m.id, itemId: item.id, newAmount: newAmount, originalAmount: item.amount))
                    let calc = item.food.calculatedFor(amount: newAmount - item.amount)
                    totalImpact = MacroBreakdown(
                        calories: totalImpact.calories + calc.calories,
                        proteinGrams: totalImpact.proteinGrams + calc.protein,
                        carbsGrams: totalImpact.carbsGrams + calc.carbs,
                        fatGrams: totalImpact.fatGrams + calc.fat,
                        fiberGrams: totalImpact.fiberGrams + calc.fiber
                    )
                }

                suggestions.append(PlanAdjustmentSuggestion(
                    title: "Distribuir Arroz no Almoço e Jantar",
                    explanation: "O plano está \(abs(Int(calorieDelta))) kcal abaixo do ideal. Adicionar +35g de arroz no almoço e +35g no jantar distribui a energia sem sobrecarregar um único prato.",
                    actionType: .batchScaleFood(targets: scaleTargets),
                    macroImpact: totalImpact,
                    badgeLabel: "+\(Int(totalImpact.carbsGrams))g Carbos (2 Refeições)",
                    buttonLabel: "Distribuir (+35g / +35g)"
                ))
            } else if let (singleMeal, riceItem) = riceTargets.first {
                let remainingRoom = max(0.0, maxSingleServingRiceGrams - riceItem.amount)
                let additionalGrams = min(40.0, remainingRoom)

                if additionalGrams >= 15.0 {
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
                        title: "Aumentar Arroz no \(singleMeal.name)",
                        explanation: "O plano está \(abs(Int(calorieDelta))) kcal abaixo do ideal. Aumentar +\(Int(additionalGrams))g de arroz no \(singleMeal.name) preserva o metabolismo.",
                        actionType: .scaleFood(mealId: singleMeal.id, itemId: riceItem.id, newAmount: newAmount, originalAmount: riceItem.amount),
                        macroImpact: scaleImpact,
                        badgeLabel: "+\(Int(addCalc.carbs))g Carbos",
                        buttonLabel: "Aumentar +\(Int(additionalGrams))g Arroz"
                    ))
                }
            } else {
                // Nenhuma refeição com arroz disponível abaixo do teto: adiciona carboidrato moderado em outra refeição
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
                    title: "Adicionar Batata-Doce no \(targetMeal.name)",
                    explanation: "O plano está \(abs(Int(calorieDelta))) kcal abaixo do ideal. Adicione 100g de batata-doce para estabilizar o déficit sem sobrecarregar as porções.",
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

            // Procura arroz para reduzir distribuído entre almoço e jantar
            if !reducedFatOrCarb {
                var eligibleRiceToReduce: [(meal: PlannedMeal, item: PlannedMealItem)] = []
                for meal in plan.meals where meal.mealType == .lunch || meal.mealType == .dinner {
                    if let riceItem = meal.items.first(where: {
                        $0.food.name.localizedCaseInsensitiveContains("arroz") && $0.amount >= 100.0
                    }) {
                        eligibleRiceToReduce.append((meal, riceItem))
                    }
                }

                if eligibleRiceToReduce.count >= 2 {
                    let perMealReduce = 30.0 // -30g no almoço e -30g no jantar
                    var scaleTargets: [ScaledItemTarget] = []
                    var totalImpact = MacroBreakdown(calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0, fiberGrams: 0)

                    for (m, item) in eligibleRiceToReduce {
                        let newAmount = max(60.0, item.amount - perMealReduce)
                        let diff = item.amount - newAmount
                        scaleTargets.append(ScaledItemTarget(mealId: m.id, itemId: item.id, newAmount: newAmount, originalAmount: item.amount))
                        let calc = item.food.calculatedFor(amount: diff)
                        totalImpact = MacroBreakdown(
                            calories: totalImpact.calories - calc.calories,
                            proteinGrams: totalImpact.proteinGrams - calc.protein,
                            carbsGrams: totalImpact.carbsGrams - calc.carbs,
                            fatGrams: totalImpact.fatGrams - calc.fat,
                            fiberGrams: totalImpact.fiberGrams - calc.fiber
                        )
                    }

                    suggestions.append(PlanAdjustmentSuggestion(
                        title: "Distribuir Redução de Arroz no Almoço e Jantar",
                        explanation: "Reduzir 30g de arroz no almoço e 30g no jantar economiza \(abs(Int(totalImpact.calories))) kcal sem deixar nenhuma refeição vazia.",
                        actionType: .batchScaleFood(targets: scaleTargets),
                        macroImpact: totalImpact,
                        badgeLabel: "\(Int(totalImpact.calories)) kcal (2 Refeições)",
                        buttonLabel: "Reduzir (-30g / -30g)"
                    ))
                } else if let (singleMeal, riceItem) = eligibleRiceToReduce.first {
                    let reduceGrams = 40.0
                    let newAmount = max(60.0, riceItem.amount - reduceGrams)
                    let redCalc = riceItem.food.calculatedFor(amount: reduceGrams)
                    let impact = MacroBreakdown(
                        calories: -redCalc.calories,
                        proteinGrams: -redCalc.protein,
                        carbsGrams: -redCalc.carbs,
                        fatGrams: -redCalc.fat,
                        fiberGrams: -redCalc.fiber
                    )

                    suggestions.append(PlanAdjustmentSuggestion(
                        title: "Ajustar Porção de Arroz no \(singleMeal.name)",
                        explanation: "Diminuir 40g de arroz economiza \(Int(redCalc.calories)) kcal preservando a adesão ao déficit.",
                        actionType: .scaleFood(mealId: singleMeal.id, itemId: riceItem.id, newAmount: newAmount, originalAmount: riceItem.amount),
                        macroImpact: impact,
                        badgeLabel: "-\(Int(redCalc.calories)) kcal",
                        buttonLabel: "Reduzir 40g Arroz"
                    ))
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
                portionName: nil, // Limpa o rótulo singular fixo antigo para não dizer "Colher de sopa cheia (790g)"
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

        case .batchScaleFood(let targets):
            for target in targets {
                guard let mealIdx = updatedMeals.firstIndex(where: { $0.id == target.mealId }) else { continue }
                var items = updatedMeals[mealIdx].items
                guard let itemIdx = items.firstIndex(where: { $0.id == target.itemId }) else { continue }
                let oldItem = items[itemIdx]
                let validAmount = max(1.0, target.newAmount.rounded(to: 1))
                let calc = oldItem.food.calculatedFor(amount: validAmount)
                items[itemIdx] = PlannedMealItem(
                    id: oldItem.id,
                    food: oldItem.food,
                    amount: validAmount,
                    unit: oldItem.unit,
                    portionName: nil,
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
            }
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
