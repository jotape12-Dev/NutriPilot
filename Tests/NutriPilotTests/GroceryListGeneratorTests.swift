import XCTest
@testable import NutriPilotCore

final class GroceryListGeneratorTests: XCTestCase {

    func testGroceryListConsolidationAndCategorization() {
        let target = NutritionTarget(
            calories: 2000.0,
            proteinGrams: 160.0,
            carbsGrams: 200.0,
            fatGrams: 60.0,
            waterMl: 3000.0
        )

        let plan = MealPlanGenerator.generateDailyPlan(target: target)
        let groceryList = GroceryListGenerator.generateGroceryList(from: plan, numberOfDays: 7)

        XCTAssertEqual(groceryList.numberOfDays, 7)
        XCTAssertFalse(groceryList.items.isEmpty)

        // Verifica que todos os 4 departamentos estão presentes
        let produce = groceryList.items(for: .produce)
        let meat = groceryList.items(for: .meatAndEggs)
        let dairy = groceryList.items(for: .dairy)
        let grocery = groceryList.items(for: .grocery)

        XCTAssertFalse(produce.isEmpty)
        XCTAssertFalse(meat.isEmpty)
        XCTAssertFalse(dairy.isEmpty)
        XCTAssertFalse(grocery.isEmpty)

        // Verifica formatação legível (ex: > 1000g formata como kg)
        for item in groceryList.items {
            XCTAssertFalse(item.formattedQuantity.isEmpty)
            XCTAssertFalse(item.isChecked)
            if item.totalAmount >= 1000.0 && item.unit == "g" {
                XCTAssertTrue(item.formattedQuantity.contains("kg"))
            }
        }
    }
}
