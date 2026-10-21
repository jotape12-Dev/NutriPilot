import Foundation

/// Item individual planejado para uma refeição do cardápio.
public struct PlannedMealItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let food: FoodItem
    public let amount: Double
    public let unit: String
    public let portionName: String?
    public let calories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let fiberGrams: Double

    public init(
        id: UUID = UUID(),
        food: FoodItem,
        amount: Double,
        unit: String,
        portionName: String? = nil,
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double
    ) {
        self.id = id
        self.food = food
        self.amount = amount.rounded(to: 1)
        self.unit = unit
        self.portionName = portionName
        self.calories = calories.rounded(to: 1)
        self.proteinGrams = proteinGrams.rounded(to: 1)
        self.carbsGrams = carbsGrams.rounded(to: 1)
        self.fatGrams = fatGrams.rounded(to: 1)
        self.fiberGrams = fiberGrams.rounded(to: 1)
    }
}

/// Refeição completa estruturada no cardápio diário.
public struct PlannedMeal: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let mealType: MealType
    public let name: String
    public let suggestedTime: String
    public let targetCalories: Double
    public let items: [PlannedMealItem]

    public init(
        id: UUID = UUID(),
        mealType: MealType,
        name: String,
        suggestedTime: String,
        targetCalories: Double,
        items: [PlannedMealItem]
    ) {
        self.id = id
        self.mealType = mealType
        self.name = name
        self.suggestedTime = suggestedTime
        self.targetCalories = targetCalories.rounded(to: 1)
        self.items = items
    }

    public var totalCalories: Double { items.reduce(0) { $0 + $1.calories }.rounded(to: 1) }
    public var totalProtein: Double { items.reduce(0) { $0 + $1.proteinGrams }.rounded(to: 1) }
    public var totalCarbs: Double { items.reduce(0) { $0 + $1.carbsGrams }.rounded(to: 1) }
    public var totalFat: Double { items.reduce(0) { $0 + $1.fatGrams }.rounded(to: 1) }
    public var totalFiber: Double { items.reduce(0) { $0 + $1.fiberGrams }.rounded(to: 1) }
}

/// Cardápio diário completo com refeições estruturadas.
public typealias MealPlan = DailyMealPlan

/// Cardápio diário completo com 4 refeições proporcionais (25%, 35%, 15%, 25%).
public struct DailyMealPlan: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let targetCalories: Double
    public let targetProteinGrams: Double
    public let targetCarbsGrams: Double
    public let targetFatGrams: Double
    public let targetFiberGrams: Double
    public let meals: [PlannedMeal]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        target: NutritionTarget,
        meals: [PlannedMeal]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.targetCalories = target.calories.rounded(to: 1)
        self.targetProteinGrams = target.proteinGrams.rounded(to: 1)
        self.targetCarbsGrams = target.carbsGrams.rounded(to: 1)
        self.targetFatGrams = target.fatGrams.rounded(to: 1)
        self.targetFiberGrams = target.fiberGrams.rounded(to: 1)
        self.meals = meals
    }

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        targetCalories: Double,
        targetProteinGrams: Double,
        targetCarbsGrams: Double,
        targetFatGrams: Double,
        targetFiberGrams: Double,
        meals: [PlannedMeal]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.targetCalories = targetCalories.rounded(to: 1)
        self.targetProteinGrams = targetProteinGrams.rounded(to: 1)
        self.targetCarbsGrams = targetCarbsGrams.rounded(to: 1)
        self.targetFatGrams = targetFatGrams.rounded(to: 1)
        self.targetFiberGrams = targetFiberGrams.rounded(to: 1)
        self.meals = meals
    }

    public var totalCalories: Double { meals.reduce(0) { $0 + $1.totalCalories }.rounded(to: 1) }
    public var totalProtein: Double { meals.reduce(0) { $0 + $1.totalProtein }.rounded(to: 1) }
    public var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs }.rounded(to: 1) }
    public var totalFat: Double { meals.reduce(0) { $0 + $1.totalFat }.rounded(to: 1) }
    public var totalFiber: Double { meals.reduce(0) { $0 + $1.totalFiber }.rounded(to: 1) }
}

/// Gerador inteligente de cardápio diário baseado na TBCA e em proporções nutricionais científicas.
/// Distribuição: Café da Manhã (25%), Almoço (35%), Lanche da Tarde (15%) e Jantar (25%).
public enum MealPlanGenerator {

    public static let breakfastRatio = 0.25
    public static let lunchRatio = 0.35
    public static let afternoonSnackRatio = 0.15
    public static let dinnerRatio = 0.25

    /// Gera um plano alimentar diário completo e coerente respeitando as metas do usuário.
    public static func generateDailyPlan(
        target: NutritionTarget,
        foods: [FoodItem] = TBCAFoodDatabase.foods
    ) -> DailyMealPlan {
        let breakfast = generateBreakfast(target: target, foods: foods)
        let lunch = generateLunch(target: target, foods: foods)
        let snack = generateAfternoonSnack(target: target, foods: foods)
        let dinner = generateDinner(target: target, foods: foods)

        return DailyMealPlan(
            target: target,
            meals: [breakfast, lunch, snack, dinner]
        )
    }

    // MARK: - Café da Manhã (25%)

    private static func generateBreakfast(target: NutritionTarget, foods: [FoodItem]) -> PlannedMeal {
        let mealCalories = target.calories * breakfastRatio
        let mealProtein = target.proteinGrams * breakfastRatio
        let mealCarbs = target.carbsGrams * breakfastRatio

        var items: [PlannedMealItem] = []

        // Pão francês ou de forma
        if let bread = foods.first(where: { $0.name.contains("Pão francês") }) {
            let breadGrams = min(100.0, max(50.0, (mealCarbs * 0.6 / 0.587))) // ~50g a 100g
            items.append(createPlannedItem(food: bread, amount: breadGrams, portionName: "Unidade"))
        }

        // Ovos mexidos
        if let eggs = foods.first(where: { $0.name.contains("Ovo de galinha mexido") }) {
            let eggsGrams = min(200.0, max(100.0, (mealProtein * 0.85 / 0.12))) // ~2 a 3 ovos
            items.append(createPlannedItem(food: eggs, amount: eggsGrams, portionName: "Porção"))
        }

        // Fruta: Banana prata
        if let banana = foods.first(where: { $0.name.contains("Banana prata") }) {
            items.append(createPlannedItem(food: banana, amount: 70.0, portionName: "Unidade média"))
        }

        // Café preto
        if let coffee = foods.first(where: { $0.name.contains("Café preto") }) {
            items.append(createPlannedItem(food: coffee, amount: 150.0, portionName: "Xícara de chá"))
        }

        return PlannedMeal(
            mealType: .breakfast,
            name: "Café da Manhã Nutritivo",
            suggestedTime: "08:00",
            targetCalories: mealCalories,
            items: items
        )
    }

    // MARK: - Almoço (35%)

    private static func generateLunch(target: NutritionTarget, foods: [FoodItem]) -> PlannedMeal {
        let mealCalories = target.calories * lunchRatio
        let mealProtein = target.proteinGrams * lunchRatio
        let mealCarbs = target.carbsGrams * lunchRatio

        var items: [PlannedMealItem] = []

        // Arroz branco
        if let rice = foods.first(where: { $0.name.contains("Arroz branco") }) {
            let riceGrams = min(250.0, max(100.0, (mealCarbs * 0.5 / 0.281)))
            items.append(createPlannedItem(food: rice, amount: riceGrams, portionName: "Colher de sopa cheia"))
        }

        // Feijão carioca
        if let beans = foods.first(where: { $0.name.contains("Feijão carioca") }) {
            items.append(createPlannedItem(food: beans, amount: 130.0, portionName: "Concha média"))
        }

        // Peito de frango grelhado
        if let chicken = foods.first(where: { $0.name.contains("Peito de frango grelhado") }) {
            let chickenGrams = min(250.0, max(120.0, (mealProtein * 0.85 / 0.315)))
            items.append(createPlannedItem(food: chicken, amount: chickenGrams, portionName: "Filé"))
        }

        // Salada: Tomate e Alface
        if let tomato = foods.first(where: { $0.name.contains("Tomate") }) {
            items.append(createPlannedItem(food: tomato, amount: 100.0, portionName: "Unidade média"))
        }
        if let lettuce = foods.first(where: { $0.name.contains("Alface") }) {
            items.append(createPlannedItem(food: lettuce, amount: 30.0, portionName: "Folhas"))
        }

        // Azeite de oliva
        if let oliveOil = foods.first(where: { $0.name.contains("Azeite") }) {
            items.append(createPlannedItem(food: oliveOil, amount: 10.0, portionName: "Colher de sobremesa"))
        }

        return PlannedMeal(
            mealType: .lunch,
            name: "Almoço Balanceado",
            suggestedTime: "12:30",
            targetCalories: mealCalories,
            items: items
        )
    }

    // MARK: - Lanche da Tarde (15%)

    private static func generateAfternoonSnack(target: NutritionTarget, foods: [FoodItem]) -> PlannedMeal {
        let mealCalories = target.calories * afternoonSnackRatio
        var items: [PlannedMealItem] = []

        // Iogurte natural
        if let yogurt = foods.first(where: { $0.name.contains("Iogurte natural") }) {
            items.append(createPlannedItem(food: yogurt, amount: 160.0, portionName: "Pote individual"))
        }

        // Aveia em flocos
        if let oats = foods.first(where: { $0.name.contains("Aveia") }) {
            items.append(createPlannedItem(food: oats, amount: 30.0, portionName: "2 colheres de sopa"))
        }

        // Fruta: Maçã
        if let apple = foods.first(where: { $0.name.contains("Maçã") }) {
            items.append(createPlannedItem(food: apple, amount: 130.0, portionName: "Unidade média"))
        }

        return PlannedMeal(
            mealType: .afternoonSnack,
            name: "Lanche Prático",
            suggestedTime: "16:30",
            targetCalories: mealCalories,
            items: items
        )
    }

    // MARK: - Jantar (25%)

    private static func generateDinner(target: NutritionTarget, foods: [FoodItem]) -> PlannedMeal {
        let mealCalories = target.calories * dinnerRatio
        let mealProtein = target.proteinGrams * dinnerRatio
        let mealCarbs = target.carbsGrams * dinnerRatio

        var items: [PlannedMealItem] = []

        // Batata doce cozida
        if let potato = foods.first(where: { $0.name.contains("Batata doce") }) {
            let potatoGrams = min(200.0, max(80.0, (mealCarbs * 0.55 / 0.184)))
            items.append(createPlannedItem(food: potato, amount: potatoGrams, portionName: "Fatias"))
        }

        // Patinho bovino grelhado
        if let beef = foods.first(where: { $0.name.contains("Patinho") }) {
            let beefGrams = min(250.0, max(120.0, (mealProtein * 0.85 / 0.359)))
            items.append(createPlannedItem(food: beef, amount: beefGrams, portionName: "Bife"))
        }

        // Brócolis cozido
        if let broccoli = foods.first(where: { $0.name.contains("Brócolis") }) {
            items.append(createPlannedItem(food: broccoli, amount: 100.0, portionName: "Xícara de chá"))
        }

        // Azeite de oliva
        if let oliveOil = foods.first(where: { $0.name.contains("Azeite") }) {
            items.append(createPlannedItem(food: oliveOil, amount: 5.0, portionName: "Colher de sobremesa"))
        }

        return PlannedMeal(
            mealType: .dinner,
            name: "Jantar Leve & Rico em Proteína",
            suggestedTime: "20:00",
            targetCalories: mealCalories,
            items: items
        )
    }

    private static func createPlannedItem(food: FoodItem, amount: Double, portionName: String?) -> PlannedMealItem {
        let macros = food.calculatedFor(amount: amount)
        return PlannedMealItem(
            food: food,
            amount: amount,
            unit: food.servingUnit,
            portionName: portionName,
            calories: macros.calories,
            proteinGrams: macros.protein,
            carbsGrams: macros.carbs,
            fatGrams: macros.fat,
            fiberGrams: macros.fiber
        )
    }
}
