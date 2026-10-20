import XCTest
@testable import NutriPilotCore

final class MealPlanStoreTests: XCTestCase {

    var tempFileURL: URL!
    var store: MealPlanStore!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("test_meal_plan_\(UUID().uuidString).json")
        store = MealPlanStore(storageURL: tempFileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    func testGenerateAndPersistPlanAndGroceryList() {
        let target = NutritionTarget(
            calories: 2200.0,
            proteinGrams: 170.0,
            carbsGrams: 220.0,
            fatGrams: 65.0,
            waterMl: 3200.0
        )

        let plan = store.generateAndSetActivePlan(target: target)
        XCTAssertEqual(store.activePlan?.id, plan.id)
        XCTAssertNotNil(store.groceryList)
        XCTAssertFalse(store.groceryList?.items.isEmpty ?? true)

        // Alterna item da lista de compras
        guard let firstItem = store.groceryList?.items.first else {
            XCTFail("Lista de compras vazia")
            return
        }
        XCTAssertFalse(firstItem.isChecked)

        store.toggleGroceryItem(id: firstItem.id)
        XCTAssertTrue(store.groceryList?.items.first?.isChecked ?? false)

        // Recarrega em nova instância para validar persistência atômica em disco
        let reloadedStore = MealPlanStore(storageURL: tempFileURL)
        XCTAssertEqual(reloadedStore.activePlan?.id, plan.id)
        XCTAssertEqual(reloadedStore.activePlan?.meals.count, 4)
        XCTAssertEqual(reloadedStore.groceryList?.items.count, store.groceryList?.items.count)
        XCTAssertTrue(reloadedStore.groceryList?.items.first?.isChecked ?? false)
    }
}
