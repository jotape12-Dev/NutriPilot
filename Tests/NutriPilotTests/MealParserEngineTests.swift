import XCTest
@testable import NutriPilotCore

final class MealParserEngineTests: XCTestCase {

    var parser: MealParserEngine!

    override func setUp() {
        super.setUp()
        parser = MealParserEngine.shared
    }

    func testClassicBrazilianMealParsing() {
        let input = "2 filés de frango grelhado, 4 colheres de arroz e 1 concha de feijão carioca"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 3)
        XCTAssertEqual(parsed.overallConfidence, .high)

        // Item 1: Frango grelhado (2 filés médios = 200g)
        let frango = parsed.items[0]
        XCTAssertTrue(frango.food?.name.contains("frango grelhado") ?? false)
        XCTAssertEqual(frango.detectedQuantity, 2.0)
        XCTAssertEqual(frango.calculatedWeightGrams, 200.0)
        XCTAssertEqual(frango.macros.calories, 326.0)
        XCTAssertEqual(frango.macros.proteinGrams, 63.0)

        // Item 2: Arroz branco (4 colheres de sopa cheias = 100g)
        let arroz = parsed.items[1]
        XCTAssertTrue(arroz.food?.name.contains("Arroz branco") ?? false)
        XCTAssertEqual(arroz.detectedQuantity, 4.0)
        XCTAssertEqual(arroz.calculatedWeightGrams, 100.0)
        XCTAssertEqual(arroz.macros.calories, 128.0)

        // Item 3: Feijão carioca (1 concha média = 130g)
        let feijao = parsed.items[2]
        XCTAssertTrue(feijao.food?.name.contains("Feijão carioca") ?? false)
        XCTAssertEqual(feijao.detectedQuantity, 1.0)
        XCTAssertEqual(feijao.calculatedWeightGrams, 130.0)
        XCTAssertEqual(feijao.macros.calories, 98.8)

        // Totais consolidados da refeição
        XCTAssertEqual(parsed.totalCalories, 552.8, accuracy: 1.0)
        XCTAssertGreaterThan(parsed.totalProteinGrams, 70.0)
    }

    func testMetricGramsParsing() {
        let input = "200g de patinho e 150g de arroz"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 2)

        let patinho = parsed.items[0]
        XCTAssertTrue(patinho.food?.name.contains("Patinho") ?? false)
        XCTAssertEqual(patinho.calculatedWeightGrams, 200.0)
        XCTAssertEqual(patinho.macros.calories, 438.0)
        XCTAssertEqual(patinho.macros.proteinGrams, 71.8)

        let arroz = parsed.items[1]
        XCTAssertTrue(arroz.food?.name.contains("Arroz") ?? false)
        XCTAssertEqual(arroz.calculatedWeightGrams, 150.0)
        XCTAssertEqual(arroz.macros.calories, 192.0)
    }

    func testBananaAndOatsParsing() {
        let input = "1 banana e 30g de aveia"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 2)

        let banana = parsed.items[0]
        XCTAssertTrue(banana.food?.name.contains("Banana") ?? false)
        XCTAssertEqual(banana.calculatedWeightGrams, 70.0) // 1 unidade média de banana prata

        let aveia = parsed.items[1]
        XCTAssertTrue(aveia.food?.name.contains("Aveia") ?? false)
        XCTAssertEqual(aveia.calculatedWeightGrams, 30.0)
        XCTAssertEqual(aveia.macros.carbsGrams, 20.0)
    }

    func testFractionsAndScoopParsing() {
        let input = "1/2 abacate e 1 scoop de whey"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 2)

        let abacate = parsed.items[0]
        XCTAssertTrue(abacate.food?.name.contains("Abacate") ?? false)
        XCTAssertEqual(abacate.detectedQuantity, 0.5)
        XCTAssertEqual(abacate.calculatedWeightGrams, 100.0) // 0.5 de 200g ou 1 metade

        let whey = parsed.items[1]
        XCTAssertTrue(whey.food?.name.contains("Whey") ?? false)
        XCTAssertEqual(whey.calculatedWeightGrams, 30.0) // 1 dosador padrão
        XCTAssertEqual(whey.macros.proteinGrams, 24.0)
    }

    func testSpelledOutNumbersInPortuguese() {
        let input = "duas fatias de pão de forma integral com dois ovos mexidos"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 2)

        let pao = parsed.items[0]
        XCTAssertTrue(pao.food?.name.contains("Pão de forma integral") ?? false)
        XCTAssertEqual(pao.detectedQuantity, 2.0)
        XCTAssertEqual(pao.calculatedWeightGrams, 50.0) // 2 fatias de 25g

        let ovos = parsed.items[1]
        XCTAssertTrue(ovos.food?.name.contains("Ovo de galinha mexido") ?? false)
        XCTAssertEqual(ovos.detectedQuantity, 2.0)
        XCTAssertEqual(ovos.calculatedWeightGrams, 100.0) // 2x 50g
    }

    func testMeioMeiaModifiers() {
        let input = "meia banana e uma colher de pasta de amendoim"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 2)

        let banana = parsed.items[0]
        XCTAssertEqual(banana.detectedQuantity, 0.5)
        XCTAssertEqual(banana.calculatedWeightGrams, 35.0) // metade de 70g

        let pasta = parsed.items[1]
        XCTAssertTrue(pasta.food?.name.contains("amendoim") ?? false)
        XCTAssertEqual(pasta.detectedQuantity, 1.0)
        XCTAssertEqual(pasta.calculatedWeightGrams, 20.0) // 1 colher de sopa
    }

    func testMultilineAndPlusSeparator() {
        let input = """
        1 bife de patinho + 200ml de leite desnatado
        1 maçã com casca
        """
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 3)

        // Verifica que "maçã com casca" não foi quebrada no "com"
        let maca = parsed.items[2]
        XCTAssertTrue(maca.food?.name.contains("Maçã") ?? false)
        XCTAssertEqual(maca.calculatedWeightGrams, 130.0)
    }

    func testSuffixQuantities() {
        let input = "frango grelhado 150g e arroz 4 colheres"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 2)

        let frango = parsed.items[0]
        XCTAssertTrue(frango.food?.name.contains("frango grelhado") ?? false)
        XCTAssertEqual(frango.calculatedWeightGrams, 150.0)

        let arroz = parsed.items[1]
        XCTAssertTrue(arroz.food?.name.contains("Arroz") ?? false)
        XCTAssertEqual(arroz.calculatedWeightGrams, 100.0)
    }

    func testLowConfidenceForUnknownFood() {
        let input = "100g de comidaesquisitaalienigena123"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 1)
        XCTAssertEqual(parsed.overallConfidence, .low)
        XCTAssertNil(parsed.items[0].food)
        XCTAssertEqual(parsed.items[0].confidence, .low)
    }

    func testConversionToMealLog() {
        let input = "1 tapioca com 2 ovos mexidos"
        let parsed = parser.parse(text: input)

        let mealLog = parsed.toMealLog(mealType: .breakfast)
        XCTAssertEqual(mealLog.mealType, .breakfast)
        XCTAssertEqual(mealLog.inputMethod, .quickText)
        XCTAssertEqual(mealLog.items.count, 2)
        XCTAssertGreaterThan(mealLog.totalCalories, 200)
    }

    func testCompositeSpelledNumbersAndLiquidMeasures() {
        let input = "uma e meia banana, 2 copos de leite integral e 1 colher de sobremesa de azeite"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 3)

        // Item 1: 1.5 banana (1.5 * 70g = 105g)
        let banana = parsed.items[0]
        XCTAssertEqual(banana.detectedQuantity, 1.5)
        XCTAssertEqual(banana.calculatedWeightGrams, 105.0)

        // Item 2: 2 copos de leite integral (2 * 190ml = 380ml)
        let leite = parsed.items[1]
        XCTAssertTrue(leite.food?.name.contains("Leite") ?? false)
        XCTAssertEqual(leite.detectedQuantity, 2.0)
        XCTAssertEqual(leite.calculatedWeightGrams, 380.0)

        // Item 3: 1 colher de sobremesa de azeite (5ml)
        let azeite = parsed.items[2]
        XCTAssertTrue(azeite.food?.name.contains("Azeite") ?? false)
        XCTAssertEqual(azeite.calculatedWeightGrams, 5.0)
        XCTAssertEqual(azeite.macros.fatGrams, 5.0)
    }

    func testKilogramsAndLitersConversion() {
        let input = "1.5kg de peito de frango e 1l de leite desnatado"
        let parsed = parser.parse(text: input)

        XCTAssertEqual(parsed.items.count, 2)

        let frango = parsed.items[0]
        XCTAssertEqual(frango.calculatedWeightGrams, 1500.0)

        let leite = parsed.items[1]
        XCTAssertEqual(leite.calculatedWeightGrams, 1000.0)
    }

    func testEmptyAndWhitespaceInput() {
        let parsedEmpty = parser.parse(text: "")
        XCTAssertEqual(parsedEmpty.items.count, 0)
        XCTAssertEqual(parsedEmpty.overallConfidence, .low)

        let parsedSpaces = parser.parse(text: "   \n  \t ")
        XCTAssertEqual(parsedSpaces.items.count, 0)
        XCTAssertEqual(parsedSpaces.overallConfidence, .low)
    }
}
