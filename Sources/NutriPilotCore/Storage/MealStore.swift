import Foundation
import Observation

/// Totais consolidados de macronutrientes e calorias de um período ou refeição.
public struct DayNutritionTotals: Sendable, Equatable {
    public let calories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let fiberGrams: Double

    public init(
        calories: Double = 0.0,
        proteinGrams: Double = 0.0,
        carbsGrams: Double = 0.0,
        fatGrams: Double = 0.0,
        fiberGrams: Double = 0.0
    ) {
        self.calories = calories.rounded(to: 1)
        self.proteinGrams = proteinGrams.rounded(to: 1)
        self.carbsGrams = carbsGrams.rounded(to: 1)
        self.fatGrams = fatGrams.rounded(to: 1)
        self.fiberGrams = fiberGrams.rounded(to: 1)
    }
}

/// Modelo de refeição favorita/recorrente pré-montada para registro rápido.
public struct FavoriteMeal: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var defaultMealType: MealType
    public var items: [MealLogItem]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        defaultMealType: MealType,
        items: [MealLogItem],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.defaultMealType = defaultMealType
        self.items = items
        self.createdAt = createdAt
    }

    public var totalCalories: Double {
        items.reduce(0) { $0 + $1.calories }.rounded(to: 1)
    }
}

/// Gerenciador de refeições com persistência local JSON, agrupamento por MealType,
/// suporte a refeições favoritas e consolidação automática de macronutrientes do dia.
@Observable
public final class MealStore: @unchecked Sendable {
    public static let shared = MealStore()

    public private(set) var meals: [MealLog] = []
    public private(set) var favoriteMeals: [FavoriteMeal] = []

    private let fileManager = FileManager.default
    private let customStorageURL: URL?
    private let lock = NSRecursiveLock()

    public init(storageURL: URL? = nil) {
        self.customStorageURL = storageURL
        loadFromDisk()
    }

    private var storageURL: URL {
        if let custom = customStorageURL {
            return custom
        }
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("NutriPilot", isDirectory: true)

        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }

        return appSupportDir.appendingPathComponent("nutripilot_meals_v1.json")
    }

    // MARK: - Registro e Gerenciamento de Refeições

    @discardableResult
    public func addMeal(_ meal: MealLog) -> MealLog {
        lock.lock()
        defer { lock.unlock() }

        meals.append(meal)
        persistToDisk()
        return meal
    }

    public func updateMeal(_ meal: MealLog) {
        lock.lock()
        defer { lock.unlock() }

        if let index = meals.firstIndex(where: { $0.id == meal.id }) {
            meals[index] = meal
            persistToDisk()
        }
    }

    public func deleteMeal(id: UUID) {
        lock.lock()
        defer { lock.unlock() }

        meals.removeAll { $0.id == id }
        persistToDisk()
    }

    public func addItem(to mealId: UUID, item: MealLogItem) {
        lock.lock()
        defer { lock.unlock() }

        if let index = meals.firstIndex(where: { $0.id == mealId }) {
            meals[index].items.append(item)
            persistToDisk()
        }
    }

    public func removeItem(from mealId: UUID, itemId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        if let index = meals.firstIndex(where: { $0.id == mealId }) {
            meals[index].items.removeAll { $0.id == itemId }
            persistToDisk()
        }
    }

    public func clearAllMeals() {
        lock.lock()
        defer { lock.unlock() }

        meals.removeAll()
        persistToDisk()
    }

    // MARK: - Consultas por Data e Tipo

    /// Retorna as refeições registradas no dia do calendário informado.
    public func meals(for date: Date = Date()) -> [MealLog] {
        lock.lock()
        defer { lock.unlock() }

        let calendar = Calendar.current
        return meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    /// Retorna as refeições de um dia filtradas por um tipo específico (ex: Almoço).
    public func meals(for date: Date = Date(), type: MealType) -> [MealLog] {
        meals(for: date).filter { $0.mealType == type }
    }

    // MARK: - Cálculo de Totais Diários

    /// Consolida a soma de calorias, proteínas, carboidratos, gorduras e fibras do dia.
    public func dailyTotals(for date: Date = Date()) -> DayNutritionTotals {
        let dailyMeals = meals(for: date)

        var calories = 0.0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var fiber = 0.0

        for meal in dailyMeals {
            for item in meal.items {
                calories += item.calories
                protein += item.proteinGrams
                carbs += item.carbsGrams
                fat += item.fatGrams
                fiber += item.fiberGrams
            }
        }

        return DayNutritionTotals(
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            fiberGrams: fiber
        )
    }

    /// Calcula os totais de um tipo específico de refeição em determinado dia.
    public func mealTotals(for date: Date = Date(), type: MealType) -> DayNutritionTotals {
        let filteredMeals = meals(for: date, type: type)

        var calories = 0.0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var fiber = 0.0

        for meal in filteredMeals {
            for item in meal.items {
                calories += item.calories
                protein += item.proteinGrams
                carbs += item.carbsGrams
                fat += item.fatGrams
                fiber += item.fiberGrams
            }
        }

        return DayNutritionTotals(
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            fiberGrams: fiber
        )
    }

    // MARK: - Gerenciamento de Favoritos

    @discardableResult
    public func saveFavorite(name: String, defaultMealType: MealType, items: [MealLogItem]) -> FavoriteMeal {
        lock.lock()
        defer { lock.unlock() }

        let favorite = FavoriteMeal(
            name: name,
            defaultMealType: defaultMealType,
            items: items
        )
        favoriteMeals.append(favorite)
        persistToDisk()
        return favorite
    }

    @discardableResult
    public func saveMealAsFavorite(_ meal: MealLog, customName: String? = nil) -> FavoriteMeal {
        let name = customName ?? "\(meal.mealType.rawValue) habitual"
        return saveFavorite(name: name, defaultMealType: meal.mealType, items: meal.items)
    }

    public func removeFavorite(id: UUID) {
        lock.lock()
        defer { lock.unlock() }

        favoriteMeals.removeAll { $0.id == id }
        persistToDisk()
    }

    /// Registra uma nova refeição a partir de um modelo favorito.
    @discardableResult
    public func logMeal(
        from favorite: FavoriteMeal,
        date: Date = Date(),
        overrideMealType: MealType? = nil
    ) -> MealLog {
        let meal = MealLog(
            date: date,
            mealType: overrideMealType ?? favorite.defaultMealType,
            inputMethod: .favorite,
            rawInput: "Favorito: \(favorite.name)",
            items: favorite.items,
            confirmedByUser: true
        )
        return addMeal(meal)
    }

    // MARK: - Persistência JSON

    private func persistToDisk() {
        let payload = MealStoragePayload(meals: meals, favoriteMeals: favoriteMeals)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Erro ao persistir refeições no disco: \(error)")
        }
    }

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let payload = try JSONDecoder().decode(MealStoragePayload.self, from: data)
            self.meals = payload.meals
            self.favoriteMeals = payload.favoriteMeals
        } catch {
            print("Erro ao carregar refeições do disco: \(error)")
        }
    }
}

private struct MealStoragePayload: Codable {
    let meals: [MealLog]
    let favoriteMeals: [FavoriteMeal]
}
