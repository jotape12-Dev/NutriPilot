import XCTest
@testable import NutriPilotCore

final class FoodSubstitutionEngineTests: XCTestCase {

    let searchEngine = FoodSearchEngine.shared

    func testCarbohydrateSubstitutionPreservesAnchorMacro() {
        guard let rice = searchEngine.search(query: "Arroz branco cozido").first,
              let sweetPotato = searchEngine.search(query: "Batata doce cozida").first else {
            XCTFail("Alimentos não encontrados")
            return
        }

        // 150g de arroz branco cozido (28.1g carbo por 100g -> 42.15g carbo)
        guard let sub = FoodSubstitutionEngine.substitute(
            originalFood: rice,
            originalAmount: 150.0,
            substituteFood: sweetPotato
        ) else {
            XCTFail("Falha na substituição")
            return
        }

        XCTAssertEqual(sub.group, .carbohydrates)
        XCTAssertEqual(sub.anchorMacroGrams, 42.2, accuracy: 0.5)

        // Batata doce tem 18.4g carbo / 100g -> ~229.1g
        XCTAssertEqual(sub.equivalentAmount, 229.1, accuracy: 1.0)

        // Valida que a quantidade calculada de batata doce entrega exatamente os 42.2g de carbo
        let potatoMacros = sweetPotato.calculatedFor(amount: sub.equivalentAmount)
        XCTAssertEqual(potatoMacros.carbs, 42.2, accuracy: 0.5)
    }

    func testProteinSubstitutionPreservesAnchorMacro() {
        guard let chicken = searchEngine.search(query: "Peito de frango grelhado").first,
              let beef = searchEngine.search(query: "Patinho bovino grelhado").first else {
            XCTFail("Alimentos proteicos não encontrados")
            return
        }

        // 150g de frango grelhado (31.5g proteina por 100g -> 47.25g proteina)
        guard let sub = FoodSubstitutionEngine.substitute(
            originalFood: chicken,
            originalAmount: 150.0,
            substituteFood: beef
        ) else {
            XCTFail("Falha na substituição proteica")
            return
        }

        XCTAssertEqual(sub.group, .proteins)
        XCTAssertEqual(sub.anchorMacroGrams, 47.2, accuracy: 0.5)

        // Patinho tem 35.9g proteina / 100g -> ~131.6g
        XCTAssertEqual(sub.equivalentAmount, 131.6, accuracy: 1.0)

        // Valida que o patinho entrega a mesma proteína do frango
        let beefMacros = beef.calculatedFor(amount: sub.equivalentAmount)
        XCTAssertEqual(beefMacros.protein, 47.2, accuracy: 0.5)
    }

    func testFatSubstitutionPreservesAnchorMacro() {
        guard let oliveOil = searchEngine.search(query: "Azeite de oliva").first,
              let peanutButter = searchEngine.search(query: "Pasta de amendoim").first else {
            XCTFail("Alimentos lipídicos não encontrados")
            return
        }

        // 13g de azeite (100% gordura = 13g gordura)
        guard let sub = FoodSubstitutionEngine.substitute(
            originalFood: oliveOil,
            originalAmount: 13.0,
            substituteFood: peanutButter
        ) else {
            XCTFail("Falha na substituição de gordura")
            return
        }

        XCTAssertEqual(sub.group, .fats)
        XCTAssertEqual(sub.anchorMacroGrams, 13.0, accuracy: 0.5)

        // Pasta de amendoim tem 50g gordura / 100g -> 26.0g
        XCTAssertEqual(sub.equivalentAmount, 26.0, accuracy: 0.5)
        let peanutMacros = peanutButter.calculatedFor(amount: sub.equivalentAmount)
        XCTAssertEqual(peanutMacros.fat, 13.0, accuracy: 0.5)
    }

    func testAvailableSubstitutesListing() {
        guard let rice = searchEngine.search(query: "Arroz branco").first else {
            XCTFail("Arroz não encontrado")
            return
        }

        let substitutes = FoodSubstitutionEngine.availableSubstitutes(for: rice, amount: 150.0)
        XCTAssertFalse(substitutes.isEmpty)

        let names = substitutes.map { $0.substituteFood.name }
        XCTAssertTrue(names.contains(where: { $0.contains("Batata doce") }))
        XCTAssertTrue(names.contains(where: { $0.contains("Mandioca") }))
        XCTAssertTrue(names.contains(where: { $0.contains("Aveia") }))
    }
}
