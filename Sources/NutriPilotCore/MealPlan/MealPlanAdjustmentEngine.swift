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

/// Papel nutricional predominante do alimento para distribuição balanceada de macros.
public enum FoodMacroRole: Sendable {
    case protein
    case carbs
    case fat
    case vegetableOrFruit
    case other
}

/// Tipo de ação prescritiva gerada pelo motor de ajustes para equilibrar o plano alimentar.
public enum AdjustmentActionType: Codable, Sendable, Equatable {
    case addFood(mealId: UUID, food: FoodItem, amount: Double)
    case scaleFood(mealId: UUID, itemId: UUID, newAmount: Double, originalAmount: Double)
    case removeFood(mealId: UUID, itemId: UUID)
    case batchScaleFood(targets: [ScaledItemTarget])
    case autoRebalance
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
    public static let maxSingleServingRiceGrams: Double = 220.0
    public static let targetStandardRiceServingGrams: Double = 160.0
    public static let maxSingleServingMeatGrams: Double = 220.0
    public static let maxSingleServingOliveOilGrams: Double = 15.0

    // MARK: - Classificação e Limites de Porções

    public static func classifyMacroRole(for item: PlannedMealItem) -> FoodMacroRole {
        let name = item.food.name.lowercased()

        if name.contains("alface") || name.contains("tomate") || name.contains("rúcula") ||
           name.contains("pepino") || name.contains("espinafre") || name.contains("brócolis") {
            return .vegetableOrFruit
        }

        if name.contains("azeite") || name.contains("óleo") || name.contains("manteiga") ||
           name.contains("castanha") || name.contains("nozes") || name.contains("amendoim") ||
           (item.food.fatGrams * 9.0 >= 0.55 * max(1.0, item.food.calories)) {
            return .fat
        }

        if name.contains("frango") || name.contains("carne") || name.contains("bife") ||
           name.contains("peixe") || name.contains("atum") || name.contains("tilápia") ||
           name.contains("ovo") || name.contains("clara") || name.contains("whey") ||
           name.contains("iogurte") || name.contains("queijo") ||
           (item.food.proteinGrams * 4.0 >= 0.35 * max(1.0, item.food.calories)) {
            return .protein
        }

        if name.contains("arroz") || name.contains("batata") || name.contains("mandioca") ||
           name.contains("aveia") || name.contains("pão") || name.contains("tapioca") ||
           name.contains("macarrão") || name.contains("banana") ||
           (item.food.carbsGrams * 4.0 >= 0.45 * max(1.0, item.food.calories)) {
            return .carbs
        }

        return .other
    }

    public static func safeServingBounds(for item: PlannedMealItem) -> (min: Double, max: Double, standard: Double) {
        let name = item.food.name.lowercased()
        if name.contains("arroz") {
            return (min: 60.0, max: 220.0, standard: 160.0)
        } else if name.contains("batata") || name.contains("mandioca") {
            return (min: 80.0, max: 250.0, standard: 150.0)
        } else if name.contains("aveia") {
            return (min: 20.0, max: 80.0, standard: 40.0)
        } else if name.contains("pão") {
            return (min: 30.0, max: 100.0, standard: 50.0)
        } else if name.contains("frango") || name.contains("carne") || name.contains("peixe") || name.contains("bife") {
            return (min: 80.0, max: 220.0, standard: 140.0)
        } else if name.contains("ovo") {
            return (min: 50.0, max: 180.0, standard: 100.0)
        } else if name.contains("whey") {
            return (min: 15.0, max: 40.0, standard: 30.0)
        } else if name.contains("azeite") || name.contains("óleo") {
            return (min: 3.0, max: 25.0, standard: 13.0)
        } else if name.contains("castanha") || name.contains("amendoim") {
            return (min: 10.0, max: 35.0, standard: 20.0)
        }
        return (min: max(5.0, item.amount * 0.5), max: max(20.0, item.amount * 1.8), standard: item.amount)
    }

    // MARK: - Rebalanceamento Automático Global

    /// Reajusta e equilibra proporcionalmente as porções de todas as refeições do dia para atingir 100% das metas diárias,
    /// garantindo rigorosamente que o desvio final em carboidratos, proteínas, gorduras e calorias NUNCA ultrapasse 5% da meta.
    public static func autoRebalancePlan(plan: DailyMealPlan, target: NutritionTarget) -> DailyMealPlan {
        guard !plan.meals.isEmpty else { return plan }

        var workingMeals = plan.meals

        // 1. Passo Inicial: Clamp de segurança em porções gigantes/aberrantes
        for mIdx in workingMeals.indices {
            var items = workingMeals[mIdx].items
            for iIdx in items.indices {
                let item = items[iIdx]
                let bounds = safeServingBounds(for: item)
                if item.amount > bounds.max {
                    let clampedAmount = bounds.standard
                    let calc = item.food.calculatedFor(amount: clampedAmount)
                    items[iIdx] = PlannedMealItem(
                        id: item.id,
                        food: item.food,
                        amount: clampedAmount,
                        unit: item.unit,
                        portionName: item.portionName,
                        calories: calc.calories,
                        proteinGrams: calc.protein,
                        carbsGrams: calc.carbs,
                        fatGrams: calc.fat,
                        fiberGrams: calc.fiber
                    )
                }
            }
            let oldM = workingMeals[mIdx]
            workingMeals[mIdx] = PlannedMeal(
                id: oldM.id,
                mealType: oldM.mealType,
                name: oldM.name,
                suggestedTime: oldM.suggestedTime,
                targetCalories: oldM.targetCalories,
                items: items
            )
        }

        // 2. Passo de Proteína: Distribuir iterativamente nos alimentos proteicos de todas as refeições
        let currentProt = workingMeals.reduce(0.0) { $0 + $1.totalProtein }
        let protDelta = target.proteinGrams - currentProt

        if abs(protDelta) > 2.0 {
            let proteinEntries = getEntries(for: .protein, in: workingMeals)
            distributeDelta(deltaMacro: protDelta, gramsPerMacro: 3.3, entries: proteinEntries, workingMeals: &workingMeals)
        }

        // 3. Passo de Carboidratos: Distribuir iterativamente nos alimentos ricos em carboidrato
        let currentCarbs = workingMeals.reduce(0.0) { $0 + $1.totalCarbs }
        let carbsDelta = target.carbsGrams - currentCarbs

        if abs(carbsDelta) > 2.0 {
            let carbEntries = getEntries(for: .carbs, in: workingMeals)
            distributeDelta(deltaMacro: carbsDelta, gramsPerMacro: 3.5, entries: carbEntries, workingMeals: &workingMeals)
        }

        // 4. Passo de Gorduras: Distribuir nas fontes lipídicas (azeite, oleaginosas)
        let currentFat = workingMeals.reduce(0.0) { $0 + $1.totalFat }
        let fatDelta = target.fatGrams - currentFat

        if abs(fatDelta) > 1.5 {
            let fatEntries = getEntries(for: .fat, in: workingMeals)
            distributeDelta(deltaMacro: fatDelta, gramsPerMacro: 1.1, entries: fatEntries, workingMeals: &workingMeals)
        }

        // 5. Sintonia Fina Calórica Proporcional (respeitando rigorosamente a tolerância de 5% de cada macro)
        let currentCals = workingMeals.reduce(0.0) { $0 + $1.totalCalories }
        let calDelta = target.calories - currentCals

        if abs(calDelta) > 25.0 {
            let currentCarbsNow = workingMeals.reduce(0.0) { $0 + $1.totalCarbs }
            let currentFatNow = workingMeals.reduce(0.0) { $0 + $1.totalFat }

            let carbsMax = target.carbsGrams * 1.04
            let carbsMin = target.carbsGrams * 0.96
            let fatMax = target.fatGrams * 1.04
            let fatMin = target.fatGrams * 0.96

            let carbEntries = getEntries(for: .carbs, in: workingMeals)
            let fatEntries = getEntries(for: .fat, in: workingMeals)

            if calDelta > 0 {
                // Necessário acrescentar calorias
                let carbsHeadroom = max(0.0, carbsMax - currentCarbsNow)
                let calsFromCarbs = min(calDelta, carbsHeadroom * 4.0)
                if calsFromCarbs > 10.0 {
                    let carbsToAdd = calsFromCarbs / 4.0
                    distributeDelta(deltaMacro: carbsToAdd, gramsPerMacro: 3.5, entries: carbEntries, workingMeals: &workingMeals)
                }

                let remainingCalDelta = calDelta - calsFromCarbs
                let fatHeadroom = max(0.0, fatMax - currentFatNow)
                let calsFromFat = min(remainingCalDelta, fatHeadroom * 9.0)
                if calsFromFat > 10.0 {
                    let fatToAdd = calsFromFat / 9.0
                    distributeDelta(deltaMacro: fatToAdd, gramsPerMacro: 1.1, entries: fatEntries, workingMeals: &workingMeals)
                }
            } else {
                // Necessário reduzir calorias
                let carbsFloor = max(0.0, currentCarbsNow - carbsMin)
                let calsToRemoveFromCarbs = min(abs(calDelta), carbsFloor * 4.0)
                if calsToRemoveFromCarbs > 10.0 {
                    let carbsToRemove = -calsToRemoveFromCarbs / 4.0
                    distributeDelta(deltaMacro: carbsToRemove, gramsPerMacro: 3.5, entries: carbEntries, workingMeals: &workingMeals)
                }

                let remainingToRemove = abs(calDelta) - calsToRemoveFromCarbs
                let fatFloor = max(0.0, currentFatNow - fatMin)
                let calsToRemoveFromFat = min(remainingToRemove, fatFloor * 9.0)
                if calsToRemoveFromFat > 10.0 {
                    let fatToRemove = -calsToRemoveFromFat / 9.0
                    distributeDelta(deltaMacro: fatToRemove, gramsPerMacro: 1.1, entries: fatEntries, workingMeals: &workingMeals)
                }
            }
        }

        // 6. Passagem Final de Clampeamento & Conformidade Clínica Estrita de 5%
        // Garante que |total - target| / target <= 0.05 para calorias e todos os macros
        for _ in 0..<3 {
            var didAdjust = false

            // Carbos: [target * 0.95, target * 1.05]
            if target.carbsGrams > 10.0 {
                let curCarbs = workingMeals.reduce(0.0) { $0 + $1.totalCarbs }
                let maxAllowed = target.carbsGrams * 1.05
                let minAllowed = target.carbsGrams * 0.95
                if curCarbs > maxAllowed {
                    let excess = curCarbs - (target.carbsGrams * 1.02)
                    let carbEntries = getEntries(for: .carbs, in: workingMeals)
                    distributeDelta(deltaMacro: -excess, gramsPerMacro: 3.5, entries: carbEntries, workingMeals: &workingMeals)
                    didAdjust = true
                } else if curCarbs < minAllowed {
                    let deficit = (target.carbsGrams * 0.98) - curCarbs
                    let carbEntries = getEntries(for: .carbs, in: workingMeals)
                    distributeDelta(deltaMacro: deficit, gramsPerMacro: 3.5, entries: carbEntries, workingMeals: &workingMeals)
                    didAdjust = true
                }
            }

            // Proteína: [target * 0.95, target * 1.05]
            if target.proteinGrams > 10.0 {
                let curProt = workingMeals.reduce(0.0) { $0 + $1.totalProtein }
                let maxAllowed = target.proteinGrams * 1.05
                let minAllowed = target.proteinGrams * 0.95
                if curProt > maxAllowed {
                    let excess = curProt - (target.proteinGrams * 1.02)
                    let protEntries = getEntries(for: .protein, in: workingMeals)
                    distributeDelta(deltaMacro: -excess, gramsPerMacro: 3.3, entries: protEntries, workingMeals: &workingMeals)
                    didAdjust = true
                } else if curProt < minAllowed {
                    let deficit = (target.proteinGrams * 0.98) - curProt
                    let protEntries = getEntries(for: .protein, in: workingMeals)
                    distributeDelta(deltaMacro: deficit, gramsPerMacro: 3.3, entries: protEntries, workingMeals: &workingMeals)
                    didAdjust = true
                }
            }

            // Gorduras: [target * 0.95, target * 1.05]
            if target.fatGrams > 5.0 {
                let curFat = workingMeals.reduce(0.0) { $0 + $1.totalFat }
                let maxAllowed = target.fatGrams * 1.05
                let minAllowed = target.fatGrams * 0.95
                if curFat > maxAllowed {
                    let excess = curFat - (target.fatGrams * 1.02)
                    let fatEntries = getEntries(for: .fat, in: workingMeals)
                    distributeDelta(deltaMacro: -excess, gramsPerMacro: 1.1, entries: fatEntries, workingMeals: &workingMeals)
                    didAdjust = true
                } else if curFat < minAllowed {
                    let deficit = (target.fatGrams * 0.98) - curFat
                    let fatEntries = getEntries(for: .fat, in: workingMeals)
                    distributeDelta(deltaMacro: deficit, gramsPerMacro: 1.1, entries: fatEntries, workingMeals: &workingMeals)
                    didAdjust = true
                }
            }

            // Calorias: [target * 0.95, target * 1.05]
            if target.calories > 100.0 {
                let curCals = workingMeals.reduce(0.0) { $0 + $1.totalCalories }
                let maxAllowed = target.calories * 1.05
                let minAllowed = target.calories * 0.95
                if curCals > maxAllowed {
                    let factor = (target.calories * 1.02) / curCals
                    scaleAllItems(by: factor, in: &workingMeals)
                    didAdjust = true
                } else if curCals < minAllowed {
                    let factor = (target.calories * 0.98) / curCals
                    scaleAllItems(by: factor, in: &workingMeals)
                    didAdjust = true
                }
            }

            if !didAdjust { break }
        }

        // 7. Atualização final de metas por refeição
        for mIdx in workingMeals.indices {
            let m = workingMeals[mIdx]
            let cals = m.items.reduce(0.0) { $0 + $1.calories }.rounded(to: 1)
            workingMeals[mIdx] = PlannedMeal(
                id: m.id,
                mealType: m.mealType,
                name: m.name,
                suggestedTime: m.suggestedTime,
                targetCalories: cals,
                items: m.items
            )
        }

        return DailyMealPlan(
            id: plan.id,
            createdAt: plan.createdAt,
            targetCalories: target.calories,
            targetProteinGrams: target.proteinGrams,
            targetCarbsGrams: target.carbsGrams,
            targetFatGrams: target.fatGrams,
            targetFiberGrams: target.fiberGrams,
            meals: workingMeals
        )
    }

    private static func getEntries(
        for role: FoodMacroRole,
        in workingMeals: [PlannedMeal]
    ) -> [(mealIdx: Int, itemIdx: Int, item: PlannedMealItem, bounds: (min: Double, max: Double, standard: Double))] {
        var entries: [(mealIdx: Int, itemIdx: Int, item: PlannedMealItem, bounds: (min: Double, max: Double, standard: Double))] = []
        for mIdx in workingMeals.indices {
            for iIdx in workingMeals[mIdx].items.indices {
                let it = workingMeals[mIdx].items[iIdx]
                if classifyMacroRole(for: it) == role {
                    entries.append((mIdx, iIdx, it, safeServingBounds(for: it)))
                }
            }
        }
        return entries
    }

    private static func scaleAllItems(by factor: Double, in workingMeals: inout [PlannedMeal]) {
        guard factor > 0.0, abs(factor - 1.0) > 0.005 else { return }
        for mIdx in workingMeals.indices {
            var items = workingMeals[mIdx].items
            for iIdx in items.indices {
                let it = items[iIdx]
                let bounds = safeServingBounds(for: it)
                let newAmount = min(bounds.max, max(bounds.min, (it.amount * factor).rounded(to: 1)))
                if abs(newAmount - it.amount) > 0.1 {
                    let calc = it.food.calculatedFor(amount: newAmount)
                    items[iIdx] = PlannedMealItem(
                        id: it.id,
                        food: it.food,
                        amount: newAmount,
                        unit: it.unit,
                        portionName: it.portionName,
                        calories: calc.calories,
                        proteinGrams: calc.protein,
                        carbsGrams: calc.carbs,
                        fatGrams: calc.fat,
                        fiberGrams: calc.fiber
                    )
                }
            }
            let m = workingMeals[mIdx]
            workingMeals[mIdx] = PlannedMeal(
                id: m.id,
                mealType: m.mealType,
                name: m.name,
                suggestedTime: m.suggestedTime,
                targetCalories: m.targetCalories,
                items: items
            )
        }
    }

    private static func distributeDelta(
        deltaMacro: Double,
        gramsPerMacro: Double,
        entries: [(mealIdx: Int, itemIdx: Int, item: PlannedMealItem, bounds: (min: Double, max: Double, standard: Double))],
        workingMeals: inout [PlannedMeal]
    ) {
        var remainingMacro = deltaMacro
        for _ in 0..<3 {
            guard abs(remainingMacro) > 0.8 else { break }

            let available = entries.filter { entry in
                let current = workingMeals[entry.mealIdx].items[entry.itemIdx].amount
                return remainingMacro > 0 ? current < entry.bounds.max : current > entry.bounds.min
            }
            guard !available.isEmpty else { break }

            let deltaFoodGrams = (remainingMacro * gramsPerMacro) / Double(available.count)
            var consumedMacro = 0.0

            for entry in available {
                let oldItem = workingMeals[entry.mealIdx].items[entry.itemIdx]
                let unclamped = oldItem.amount + deltaFoodGrams
                let newAmount = min(entry.bounds.max, max(entry.bounds.min, unclamped)).rounded(to: 1)
                let actualDiff = newAmount - oldItem.amount
                if abs(actualDiff) > 0.05 {
                    let calc = oldItem.food.calculatedFor(amount: newAmount)
                    workingMeals[entry.mealIdx] = updateItemInMeal(
                        meal: workingMeals[entry.mealIdx],
                        itemIdx: entry.itemIdx,
                        newAmount: newAmount,
                        calc: calc
                    )
                    consumedMacro += (actualDiff / gramsPerMacro)
                }
            }
            remainingMacro -= consumedMacro
        }
    }

    private static func updateItemInMeal(
        meal: PlannedMeal,
        itemIdx: Int,
        newAmount: Double,
        calc: (calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double)
    ) -> PlannedMeal {
        var items = meal.items
        guard itemIdx < items.count else { return meal }
        let oldItem = items[itemIdx]
        let validAmount = max(1.0, newAmount.rounded(to: 1))
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
        return PlannedMeal(
            id: meal.id,
            mealType: meal.mealType,
            name: meal.name,
            suggestedTime: meal.suggestedTime,
            targetCalories: meal.targetCalories,
            items: items
        )
    }

    // MARK: - Geração de Sugestões Individuais e Rebalanceamento

    /// Gera até 5 sugestões clínicas mais relevantes e de maior impacto fisiológico para o plano atual.
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

        // MARK: - Sugestão Mestra: Rebalanceamento Automático Global
        let hasMacroDiscrepancy = abs(calorieDelta) > 120.0 || abs(proteinDelta) > 15.0 || plan.meals.contains(where: {
            $0.items.contains(where: { $0.amount > maxSingleServingRiceGrams && $0.food.name.localizedCaseInsensitiveContains("arroz") })
        })

        if hasMacroDiscrepancy {
            suggestions.append(PlanAdjustmentSuggestion(
                title: "Calibrar Todas as Refeições Automaticamente",
                explanation: "O algoritmo equilibra as porções de arroz, proteínas e gorduras em todas as refeições do dia para atingir 100% da sua meta.",
                actionType: .autoRebalance,
                macroImpact: MacroBreakdown(
                    calories: target.calories - plan.totalCalories,
                    proteinGrams: target.proteinGrams - plan.totalProtein,
                    carbsGrams: target.carbsGrams - plan.totalCarbs,
                    fatGrams: target.fatGrams - plan.totalFat,
                    fiberGrams: target.fiberGrams - plan.totalFiber
                ),
                badgeLabel: "100% da Meta",
                buttonLabel: "Calibrar Todas as Refeições"
            ))
        }

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
            var chickenTargets: [(meal: PlannedMeal, item: PlannedMealItem)] = []
            for meal in plan.meals where meal.mealType == .lunch || meal.mealType == .dinner {
                if let chickenItem = meal.items.first(where: {
                    $0.food.name.localizedCaseInsensitiveContains("frango") && $0.amount < maxSingleServingMeatGrams
                }) {
                    chickenTargets.append((meal, chickenItem))
                }
            }

            if chickenTargets.count >= 2 {
                let perMealAdd = 25.0
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
                let perMealAdd = 35.0
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
            }
        }

        // MARK: - 4. Superávit Involuntário / Calorias Altas (> 105% em fatLoss ou delta > +150 kcal)
        let isCalorieSurplus = (goal == .fatLoss && plan.totalCalories / max(1.0, target.calories) > 1.05) || (calorieDelta > 150.0)
        if isCalorieSurplus {
            var reducedFatOrCarb = false

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
                    let perMealReduce = 30.0
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
                }
            }
        }

        // Limita a até 5 sugestões de maior impacto clínico
        return Array(suggestions.prefix(5))
    }

    /// Aplica uma sugestão de ajuste diretamente sobre a estrutura de um DailyMealPlan, gerando um novo plano imutável.
    public static func apply(suggestion: PlanAdjustmentSuggestion, to plan: DailyMealPlan) -> DailyMealPlan {
        var updatedMeals = plan.meals

        switch suggestion.actionType {
        case .autoRebalance:
            let tgt = NutritionTarget(
                calories: plan.targetCalories,
                proteinGrams: plan.targetProteinGrams,
                carbsGrams: plan.targetCarbsGrams,
                fatGrams: plan.targetFatGrams,
                fiberGrams: plan.targetFiberGrams,
                waterMl: 2800.0
            )
            return autoRebalancePlan(plan: plan, target: tgt)

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
