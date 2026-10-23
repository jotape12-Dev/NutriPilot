import XCTest
#if canImport(PDFKit)
import PDFKit
#endif
@testable import NutriPilotCore

final class MealPlanImportEngineTests: XCTestCase {

    func testImportFullStructuredBrazilianDiet() {
        let dietText = """
        Prescrição Nutricional - Dra. Juliana Silva (CRN-3 48192)
        Objetivo: Recomposição Corporal

        1ª Refeição - Café da Manhã (07:30)
        - 2 ovos mexidos
        - 2 fatias de pão integral
        - 1 banana prata

        2ª Refeição - Almoço (12:30)
        - 150g de filé de frango grelhado
        - 150g de arroz branco
        - 1 concha de feijão carioca

        3ª Refeição - Lanche da Tarde (16:30)
        - 1 maçã
        - 30g de aveia em flocos

        4ª Refeição - Jantar (20:00)
        - 150g de patinho
        - 150g de arroz
        """

        let plan = MealPlanImportEngine.importPlan(text: dietText, title: "Dieta da Nutri")

        XCTAssertEqual(plan.meals.count, 4)

        // 1. Café da Manhã
        let breakfast = plan.meals[0]
        XCTAssertEqual(breakfast.mealType, .breakfast)
        XCTAssertEqual(breakfast.suggestedTime, "07:30")
        XCTAssertFalse(breakfast.items.isEmpty)
        XCTAssertGreaterThan(breakfast.totalCalories, 200.0)

        // 2. Almoço
        let lunch = plan.meals[1]
        XCTAssertEqual(lunch.mealType, .lunch)
        XCTAssertEqual(lunch.suggestedTime, "12:30")
        XCTAssertEqual(lunch.items.count, 3) // Frango, Arroz, Feijão
        XCTAssertGreaterThan(lunch.totalProtein, 35.0)

        // 3. Lanche da Tarde
        let snack = plan.meals[2]
        XCTAssertEqual(snack.mealType, .afternoonSnack)
        XCTAssertEqual(snack.suggestedTime, "16:30")
        XCTAssertFalse(snack.items.isEmpty)

        // 4. Jantar
        let dinner = plan.meals[3]
        XCTAssertEqual(dinner.mealType, .dinner)
        XCTAssertEqual(dinner.suggestedTime, "20:00")
        XCTAssertFalse(dinner.items.isEmpty)

        // Totais consolidados da dieta
        XCTAssertGreaterThan(plan.totalCalories, 1000.0)
        XCTAssertGreaterThan(plan.totalProtein, 80.0)
        XCTAssertGreaterThan(plan.totalCarbs, 100.0)
    }

    func testImportDietWithColacaoAndCeia() {
        let dietText = """
        Café da Manhã:
        2 ovos mexidos

        Colação:
        1 banana

        Almoço:
        200g de frango e 150g de arroz

        Lanche:
        30g de aveia

        Jantar:
        150g de frango

        Ceia:
        2 ovos cozidos
        """

        let plan = MealPlanImportEngine.importPlan(text: dietText)

        XCTAssertEqual(plan.meals.count, 6)
        XCTAssertEqual(plan.meals[0].mealType, .breakfast)
        XCTAssertEqual(plan.meals[1].mealType, .morningSnack)
        XCTAssertEqual(plan.meals[2].mealType, .lunch)
        XCTAssertEqual(plan.meals[3].mealType, .afternoonSnack)
        XCTAssertEqual(plan.meals[4].mealType, .dinner)
        XCTAssertEqual(plan.meals[5].mealType, .supper)
    }

    func testImportUnlabeledRawTextCreatesDefaultMeal() {
        let rawInput = "2 filés de frango grelhado, 4 colheres de arroz e 1 concha de feijão carioca"
        let plan = MealPlanImportEngine.importPlan(text: rawInput)

        XCTAssertEqual(plan.meals.count, 1)
        let meal = plan.meals[0]
        XCTAssertEqual(meal.mealType, .lunch)
        XCTAssertEqual(meal.name, "Refeição Principal")
        XCTAssertEqual(meal.items.count, 3)
        XCTAssertGreaterThan(meal.totalCalories, 400.0)
    }

    func testImportEmptyTextReturnsEmptyPlan() {
        let plan = MealPlanImportEngine.importPlan(text: "")
        XCTAssertEqual(plan.meals.count, 0)
        XCTAssertEqual(plan.targetCalories, 0)
    }

    func testImportCorruptedPDFDataReturnsEmptyPlan() {
        let emptyData = Data()
        let plan = MealPlanImportEngine.importPlan(pdfData: emptyData)
        XCTAssertEqual(plan.meals.count, 0)
    }

    func testMealPlanStoreIntegrationWithImportedPlan() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = MealPlanStore(storageURL: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let diet = """
        Almoço:
        150g de patinho e 150g de arroz

        Jantar:
        150g de frango e 150g de arroz
        """

        let importedPlan = MealPlanImportEngine.importPlan(text: diet)
        store.setActivePlan(importedPlan)

        XCTAssertNotNil(store.activePlan)
        XCTAssertEqual(store.activePlan?.meals.count, 2)
        XCTAssertNotNil(store.groceryList)
        XCTAssertFalse(store.groceryList?.items.isEmpty ?? true)
    }

    func testImportRealBrazilianClinicalDietPDF() {
        let path = "/Users/jotape/Downloads/plano_alimentar_sem_whey.pdf"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return
        }

        let plan = MealPlanImportEngine.importPlan(pdfData: data)
        XCTAssertEqual(plan.meals.count, 5)
        XCTAssertGreaterThan(plan.targetCalories, 2400.0)
        XCTAssertLessThan(plan.targetCalories, 2550.0)
        XCTAssertEqual(plan.meals[0].name, "Café da Manhã")
        XCTAssertEqual(plan.meals[0].suggestedTime, "08:00")
        XCTAssertEqual(plan.meals[1].name, "Almoço")
        XCTAssertEqual(plan.meals[1].suggestedTime, "12:30")
        XCTAssertEqual(plan.meals[3].name, "Pré-Treino")
        XCTAssertEqual(plan.meals[3].suggestedTime, "19:00")
        XCTAssertEqual(plan.meals[4].name, "Jantar")
        XCTAssertEqual(plan.meals[4].suggestedTime, "21:00")
    }

    func testImportPreservesHouseholdPortionNamesAndCalculatesWeights() {
        let dietText = """
        Café da Manhã:
        - 2 unidades de banana prata
        - 2 ovos mexidos
        - 2 fatias de pão integral
        """

        let plan = MealPlanImportEngine.importPlan(text: dietText, title: "Café Teste")
        XCTAssertEqual(plan.meals.count, 1)
        let items = plan.meals[0].items
        XCTAssertEqual(items.count, 3)

        // Banana: 2 unidades -> portionName "2 unidades", amount 140g (70g * 2)
        let bananaItem = items.first(where: { $0.food.name.localizedCaseInsensitiveContains("banana") })
        XCTAssertNotNil(bananaItem)
        XCTAssertEqual(bananaItem?.portionName, "2 unidades")
        XCTAssertEqual(bananaItem?.amount ?? 0, 140.0, accuracy: 1.0)

        // Ovos: 2 ovos mexidos -> portionName "2 ovos", amount 100g (50g * 2)
        let eggItem = items.first(where: { $0.food.name.localizedCaseInsensitiveContains("ovo") })
        XCTAssertNotNil(eggItem)
        XCTAssertEqual(eggItem?.portionName, "2 ovos")
        XCTAssertEqual(eggItem?.amount ?? 0, 100.0, accuracy: 1.0)

        // Pão: 2 fatias -> portionName "2 fatias", amount 50g (25g * 2)
        let breadItem = items.first(where: { $0.food.name.localizedCaseInsensitiveContains("pão") })
        XCTAssertNotNil(breadItem)
        XCTAssertEqual(breadItem?.portionName, "2 fatias")
        XCTAssertEqual(breadItem?.amount ?? 0, 50.0, accuracy: 1.0)
    }
}
