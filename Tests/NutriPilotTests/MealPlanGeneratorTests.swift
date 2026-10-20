import XCTest
@testable import NutriPilotCore

final class MealPlanGeneratorTests: XCTestCase {

    func testDailyMealPlanProportionalDistribution() {
        let target = NutritionTarget(
            calories: 2000.0,
            proteinGrams: 160.0,
            carbsGrams: 200.0,
            fatGrams: 60.0,
            fiberGrams: 30.0,
            waterMl: 3000.0
        )

        let plan = MealPlanGenerator.generateDailyPlan(target: target)

        XCTAssertEqual(plan.meals.count, 4)

        // 1. Café da Manhã (25%) -> 500 kcal
        let breakfast = plan.meals[0]
        XCTAssertEqual(breakfast.mealType, .breakfast)
        XCTAssertEqual(breakfast.targetCalories, 500.0, accuracy: 1.0)
        XCTAssertFalse(breakfast.items.isEmpty)

        // 2. Almoço (35%) -> 700 kcal
        let lunch = plan.meals[1]
        XCTAssertEqual(lunch.mealType, .lunch)
        XCTAssertEqual(lunch.targetCalories, 700.0, accuracy: 1.0)
        XCTAssertFalse(lunch.items.isEmpty)

        // 3. Lanche da Tarde (15%) -> 300 kcal
        let snack = plan.meals[2]
        XCTAssertEqual(snack.mealType, .afternoonSnack)
        XCTAssertEqual(snack.targetCalories, 300.0, accuracy: 1.0)
        XCTAssertFalse(snack.items.isEmpty)

        // 4. Jantar (25%) -> 500 kcal
        let dinner = plan.meals[3]
        XCTAssertEqual(dinner.mealType, .dinner)
        XCTAssertEqual(dinner.targetCalories, 500.0, accuracy: 1.0)
        XCTAssertFalse(dinner.items.isEmpty)

        // Total do cardápio deve se aproximar da meta estipulada
        XCTAssertGreaterThan(plan.totalCalories, 1700.0)
        XCTAssertLessThan(plan.totalCalories, 2300.0)
        XCTAssertGreaterThan(plan.totalProtein, 130.0)
    }
}
