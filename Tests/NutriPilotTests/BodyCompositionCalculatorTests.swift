import XCTest
@testable import NutriPilotCore

final class BodyCompositionCalculatorTests: XCTestCase {

    func testJacksonPollock7FoldsMale() {
        let folds = SkinfoldMeasurements(
            chestMm: 10.0,
            abdominalMm: 18.0,
            middleAxillaryMm: 12.0,
            subscapularMm: 15.0,
            suprailiacMm: 14.0,
            thighMm: 16.0,
            tricepsMm: 10.0
        )
        // Soma = 95 mm
        XCTAssertEqual(folds.sumOf7Folds, 95.0)

        guard let result = BodyCompositionCalculator.calculate7Folds(
            skinfolds: folds,
            weightKg: 80.0,
            ageYears: 25.0,
            sex: .male
        ) else {
            XCTFail("Falha ao calcular composição corporal masculina 7 dobras")
            return
        }

        // Densidade teórica: ~1.068 g/cm³
        XCTAssertEqual(result.bodyDensity, 1.0684, accuracy: 0.005)
        // Gordura teórica por Siri: ~13.3%
        XCTAssertEqual(result.bodyFatPercent, 13.3, accuracy: 0.5)

        // Fracionamento de massa (80kg com ~13.3% de gordura)
        // Massa Gorda: ~10.6 kg | Massa Magra: ~69.4 kg
        XCTAssertEqual(result.fatMassKg, 10.6, accuracy: 0.5)
        XCTAssertEqual(result.leanMassKg, 69.4, accuracy: 0.5)
        XCTAssertGreaterThan(result.muscleMassKg, 30.0)
        XCTAssertGreaterThan(result.boneMassKg, 10.0)
        XCTAssertGreaterThan(result.residualMassKg, 15.0)
    }

    func testJacksonPollock7FoldsFemale() {
        let folds = SkinfoldMeasurements(
            chestMm: 12.0,
            abdominalMm: 22.0,
            middleAxillaryMm: 14.0,
            subscapularMm: 16.0,
            suprailiacMm: 20.0,
            thighMm: 24.0,
            tricepsMm: 18.0
        )
        // Soma = 126 mm
        XCTAssertEqual(folds.sumOf7Folds, 126.0)

        guard let result = BodyCompositionCalculator.calculate7Folds(
            skinfolds: folds,
            weightKg: 60.0,
            ageYears: 28.0,
            sex: .female
        ) else {
            XCTFail("Falha ao calcular composição corporal feminina 7 dobras")
            return
        }

        // %Gordura feminina deve ficar em faixa fisiológica típica (22-24%)
        XCTAssertGreaterThan(result.bodyFatPercent, 20.0)
        XCTAssertLessThan(result.bodyFatPercent, 26.0)
        XCTAssertEqual(result.fatMassKg + result.leanMassKg, 60.0, accuracy: 0.1)
    }

    func testJacksonPollock3FoldsMale() {
        // Homens: Peitoral + Abdominal + Coxa
        let folds = SkinfoldMeasurements(
            chestMm: 12.0,
            abdominalMm: 20.0,
            thighMm: 18.0
        )
        XCTAssertEqual(folds.sumOf3FoldsMale, 50.0)

        guard let result = BodyCompositionCalculator.calculate3Folds(
            skinfolds: folds,
            weightKg: 82.0,
            ageYears: 30.0,
            sex: .male
        ) else {
            XCTFail("Falha ao calcular 3 dobras masculino")
            return
        }

        XCTAssertGreaterThan(result.bodyFatPercent, 12.0)
        XCTAssertLessThan(result.bodyFatPercent, 18.0)
        XCTAssertEqual(result.protocolUsed, "Jackson & Pollock 3 Dobras")
    }

    func testJacksonPollock3FoldsFemale() {
        // Mulheres: Tríceps + Suprailíaca + Coxa
        let folds = SkinfoldMeasurements(
            suprailiacMm: 18.0,
            thighMm: 22.0,
            tricepsMm: 16.0
        )
        XCTAssertEqual(folds.sumOf3FoldsFemale, 56.0)

        guard let result = BodyCompositionCalculator.calculate3Folds(
            skinfolds: folds,
            weightKg: 58.0,
            ageYears: 26.0,
            sex: .female
        ) else {
            XCTFail("Falha ao calcular 3 dobras feminino")
            return
        }

        XCTAssertGreaterThan(result.bodyFatPercent, 19.0)
        XCTAssertLessThan(result.bodyFatPercent, 25.0)
        XCTAssertEqual(result.protocolUsed, "Jackson & Pollock 3 Dobras")
    }

    func testSiriEquationPrecision() {
        // Densidade corporal 1.065 g/cm³ -> ((4.95 / 1.065) - 4.5) * 100 = 14.788%
        let bf = BodyCompositionCalculator.siriEquation(bodyDensity: 1.065)
        XCTAssertEqual(bf, 14.8, accuracy: 0.1)

        // Limites fisiológicos
        let bfExtremeHigh = BodyCompositionCalculator.siriEquation(bodyDensity: 0.90)
        XCTAssertEqual(bfExtremeHigh, 65.0) // Clamped

        let bfExtremeLow = BodyCompositionCalculator.siriEquation(bodyDensity: 1.20)
        XCTAssertEqual(bfExtremeLow, 3.0) // Clamped
    }
}
