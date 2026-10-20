import XCTest
@testable import NutriPilotCore

final class FoodSearchEngineTests: XCTestCase {

    var engine: FoodSearchEngine!

    override func setUp() {
        super.setUp()
        engine = FoodSearchEngine.shared
    }

    func testTBCADatabaseContainsCommonFoods() {
        XCTAssertGreaterThan(TBCAFoodDatabase.foods.count, 20)

        let names = TBCAFoodDatabase.foods.map(\.name)
        XCTAssertTrue(names.contains(where: { $0.contains("Arroz branco") }))
        XCTAssertTrue(names.contains(where: { $0.contains("Feijão carioca") }))
        XCTAssertTrue(names.contains(where: { $0.contains("frango grelhado") }))
        XCTAssertTrue(names.contains(where: { $0.contains("Ovo de galinha") }))
        XCTAssertTrue(names.contains(where: { $0.contains("Banana") }))
        XCTAssertTrue(names.contains(where: { $0.contains("Aveia") }))
        XCTAssertTrue(names.contains(where: { $0.contains("Pão francês") }))
        XCTAssertTrue(names.contains(where: { $0.contains("Patinho") }))
    }

    func testDiacriticAndCaseInsensitiveSearch() {
        // "pao" sem acento deve encontrar alimentos com pão (incluindo "Pão francês")
        let paoResults = engine.search(query: "pao")
        XCTAssertFalse(paoResults.isEmpty)
        XCTAssertTrue(paoResults.contains(where: { $0.name == "Pão francês" }))

        // "pao frances" sem acento deve trazer "Pão francês" em primeiro
        let paoFrancesResults = engine.search(query: "pao frances")
        XCTAssertEqual(paoFrancesResults.first?.name, "Pão francês")

        // "PÃO FRANCÊS" em caixa alta com acento
        let paoUpperResults = engine.search(query: "PÃO FRANCÊS")
        XCTAssertEqual(paoUpperResults.first?.name, "Pão francês")

        // "feijao" sem til encontra "Feijão"
        let feijaoResults = engine.search(query: "feijao")
        XCTAssertFalse(feijaoResults.isEmpty)
        XCTAssertTrue(feijaoResults.contains(where: { $0.name.contains("Feijão carioca") }))

        // "maca" sem cedilha encontra "Maçã"
        let macaResults = engine.search(query: "maca")
        XCTAssertFalse(macaResults.isEmpty)
        XCTAssertTrue(macaResults.first?.name.contains("Maçã") ?? false)

        // "FRANGO" encontra "Peito de frango"
        let frangoResults = engine.search(query: "FRANGO")
        XCTAssertFalse(frangoResults.isEmpty)
        XCTAssertTrue(frangoResults.contains(where: { $0.name.contains("Peito de frango grelhado") }))
    }

    func testMultiTokenSearch() {
        let results = engine.search(query: "arroz branco")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.name, "Arroz branco cozido")
    }

    func testMacroCalculationByAmount() {
        guard let arroz = engine.search(query: "Arroz branco cozido").first else {
            XCTFail("Arroz branco cozido não encontrado")
            return
        }

        // 100g = 128 cal, 2.5g prot, 28.1g carb, 0.2g fat, 1.6g fib
        let macros100 = engine.calculateMacros(for: arroz, amount: 100.0)
        XCTAssertEqual(macros100.calories, 128.0)
        XCTAssertEqual(macros100.proteinGrams, 2.5)
        XCTAssertEqual(macros100.carbsGrams, 28.1)
        XCTAssertEqual(macros100.fatGrams, 0.2)
        XCTAssertEqual(macros100.fiberGrams, 1.6)

        // 200g = dobro
        let macros200 = engine.calculateMacros(for: arroz, amount: 200.0)
        XCTAssertEqual(macros200.calories, 256.0)
        XCTAssertEqual(macros200.proteinGrams, 5.0)
        XCTAssertEqual(macros200.carbsGrams, 56.2)
        XCTAssertEqual(macros200.fatGrams, 0.4)
        XCTAssertEqual(macros200.fiberGrams, 3.2)
    }

    func testMacroCalculationByPortion() {
        guard let arroz = engine.search(query: "Arroz branco cozido").first,
              let portion = arroz.portions.first(where: { $0.name == "Escumadeira cheia" }) else {
            XCTFail("Porção de arroz não encontrada")
            return
        }

        // 1 escumadeira cheia = 100g
        XCTAssertEqual(portion.gramWeight, 100.0)
        let macrosPortion = engine.calculateMacros(for: arroz, portion: portion, quantity: 1.0)
        XCTAssertEqual(macrosPortion.calories, 128.0)

        // 2 escumadeiras = 200g
        let macrosDouble = engine.calculateMacros(for: arroz, portion: portion, quantity: 2.0)
        XCTAssertEqual(macrosDouble.calories, 256.0)
    }

    func testCreateMealLogItemFromPortion() {
        guard let frango = engine.search(query: "Peito de frango grelhado").first,
              let fileMedio = frango.portions.first(where: { $0.name == "Filé médio" }) else {
            XCTFail("Filé de frango não encontrado")
            return
        }

        let mealItem = engine.createMealLogItem(from: frango, portion: fileMedio, quantity: 1.0)
        XCTAssertEqual(mealItem.foodId, frango.id)
        XCTAssertEqual(mealItem.quantity, 100.0)
        XCTAssertEqual(mealItem.calories, 163.0)
        XCTAssertEqual(mealItem.proteinGrams, 31.5)
        XCTAssertTrue(mealItem.name.contains("Filé médio"))
    }
}
