import XCTest
@testable import NutriPilotCore

final class MealStoreTests: XCTestCase {

    var tempFileURL: URL!
    var store: MealStore!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("test_meals_\(UUID().uuidString).json")
        store = MealStore(storageURL: tempFileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    func testAddMealAndCalculateDailyTotals() {
        let today = Date()

        // Café da manhã: Pão francês (50g) + 2 ovos mexidos (100g)
        let breakfast = MealLog(
            date: today,
            mealType: .breakfast,
            items: [
                MealLogItem(name: "Pão francês", quantity: 50, calories: 150.0, proteinGrams: 4.0, carbsGrams: 29.35, fatGrams: 1.55, fiberGrams: 1.15),
                MealLogItem(name: "2 Ovos mexidos", quantity: 100, calories: 170.0, proteinGrams: 12.0, carbsGrams: 1.2, fatGrams: 12.5, fiberGrams: 0.0)
            ]
        )

        // Almoço: Arroz branco (150g) + Feijão carioca (130g) + Peito de frango (150g)
        let lunch = MealLog(
            date: today,
            mealType: .lunch,
            items: [
                MealLogItem(name: "Arroz branco", quantity: 150, calories: 192.0, proteinGrams: 3.75, carbsGrams: 42.15, fatGrams: 0.3, fiberGrams: 2.4),
                MealLogItem(name: "Feijão carioca", quantity: 130, calories: 98.8, proteinGrams: 6.24, carbsGrams: 17.68, fatGrams: 0.65, fiberGrams: 6.37),
                MealLogItem(name: "Frango grelhado", quantity: 150, calories: 244.5, proteinGrams: 47.25, carbsGrams: 0.0, fatGrams: 4.8, fiberGrams: 0.0)
            ]
        )

        store.addMeal(breakfast)
        store.addMeal(lunch)

        let totals = store.dailyTotals(for: today)
        // 150 + 170 + 192 + 98.8 + 244.5 = 855.3
        XCTAssertEqual(totals.calories, 855.3, accuracy: 0.5)
        // 4.0 + 12.0 + 3.75 + 6.24 + 47.25 = 73.24
        XCTAssertEqual(totals.proteinGrams, 73.2, accuracy: 0.5)
        // 29.35 + 1.2 + 42.15 + 17.68 + 0.0 = 90.38
        XCTAssertEqual(totals.carbsGrams, 90.4, accuracy: 0.5)
        // 1.55 + 12.5 + 0.3 + 0.65 + 4.8 = 19.8
        XCTAssertEqual(totals.fatGrams, 19.8, accuracy: 0.5)
        // 1.15 + 0.0 + 2.4 + 6.37 + 0.0 = 9.92
        XCTAssertEqual(totals.fiberGrams, 9.9, accuracy: 0.5)
    }

    func testMealTotalsByMealType() {
        let today = Date()

        let breakfast = MealLog(
            date: today,
            mealType: .breakfast,
            items: [
                MealLogItem(name: "Aveia em flocos", quantity: 40, calories: 157.6, proteinGrams: 5.56, carbsGrams: 26.64, fatGrams: 3.4, fiberGrams: 3.64),
                MealLogItem(name: "Banana prata", quantity: 70, calories: 68.6, proteinGrams: 0.91, carbsGrams: 18.2, fatGrams: 0.07, fiberGrams: 1.4)
            ]
        )

        let dinner = MealLog(
            date: today,
            mealType: .dinner,
            items: [
                MealLogItem(name: "Patinho bovino", quantity: 150, calories: 328.5, proteinGrams: 53.85, carbsGrams: 0.0, fatGrams: 10.95, fiberGrams: 0.0)
            ]
        )

        store.addMeal(breakfast)
        store.addMeal(dinner)

        let breakfastTotals = store.mealTotals(for: today, type: .breakfast)
        XCTAssertEqual(breakfastTotals.calories, 226.2, accuracy: 0.5)
        XCTAssertEqual(breakfastTotals.proteinGrams, 6.5, accuracy: 0.5)

        let dinnerTotals = store.mealTotals(for: today, type: .dinner)
        XCTAssertEqual(dinnerTotals.calories, 328.5, accuracy: 0.5)
        XCTAssertEqual(dinnerTotals.proteinGrams, 53.9, accuracy: 0.5)
    }

    func testAddAndRemoveItemsFromMeal() {
        let today = Date()
        let meal = MealLog(date: today, mealType: .morningSnack)
        store.addMeal(meal)

        let item1 = MealLogItem(name: "Maçã", quantity: 130, calories: 67.6, proteinGrams: 0.4, carbsGrams: 17.9, fatGrams: 0.3, fiberGrams: 3.1)
        store.addItem(to: meal.id, item: item1)

        let fetchedMeal = store.meals(for: today).first(where: { $0.id == meal.id })
        XCTAssertEqual(fetchedMeal?.items.count, 1)
        XCTAssertEqual(fetchedMeal?.totalCalories, 67.6)

        store.removeItem(from: meal.id, itemId: item1.id)
        let updatedMeal = store.meals(for: today).first(where: { $0.id == meal.id })
        XCTAssertEqual(updatedMeal?.items.count, 0)
    }

    func testFavoritesWorkflow() {
        let items = [
            MealLogItem(name: "Whey Protein", quantity: 30, calories: 120, proteinGrams: 24, carbsGrams: 1.8, fatGrams: 1.8, fiberGrams: 0),
            MealLogItem(name: "Banana", quantity: 100, calories: 98, proteinGrams: 1.3, carbsGrams: 26, fatGrams: 0.1, fiberGrams: 2)
        ]

        let favorite = store.saveFavorite(
            name: "Shake Pós-Treino",
            defaultMealType: .afternoonSnack,
            items: items
        )

        XCTAssertEqual(store.favoriteMeals.count, 1)
        XCTAssertEqual(store.favoriteMeals.first?.name, "Shake Pós-Treino")

        // Registra refeição a partir do favorito
        let loggedMeal = store.logMeal(from: favorite)
        XCTAssertEqual(loggedMeal.mealType, .afternoonSnack)
        XCTAssertEqual(loggedMeal.items.count, 2)
        XCTAssertEqual(loggedMeal.totalCalories, 218)

        // Remove favorito
        store.removeFavorite(id: favorite.id)
        XCTAssertEqual(store.favoriteMeals.count, 0)
    }

    func testPersistenceToDisk() {
        let today = Date()
        let meal = MealLog(
            date: today,
            mealType: .lunch,
            items: [MealLogItem(name: "Patinho", quantity: 100, calories: 219, proteinGrams: 35.9, carbsGrams: 0, fatGrams: 7.3, fiberGrams: 0)]
        )
        store.addMeal(meal)

        let reloadedStore = MealStore(storageURL: tempFileURL)
        XCTAssertEqual(reloadedStore.meals.count, 1)
        let totals = reloadedStore.dailyTotals(for: today)
        XCTAssertEqual(totals.calories, 219)
        XCTAssertEqual(totals.proteinGrams, 35.9)
    }
}
