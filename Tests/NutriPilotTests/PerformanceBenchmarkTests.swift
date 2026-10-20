import XCTest
@testable import NutriPilotCore

final class PerformanceBenchmarkTests: XCTestCase {

    /// Valida o critério de produto: Parsing de refeição complexa com MealParserEngine em menos de 100ms
    /// (Requisito de SLA da interface do app: < 10s).
    func testComplexMealParsingBenchmarkUnder100ms() {
        let complexMealInput = "2 filés de frango grelhado, 4 colheres de arroz branco, 1 concha de feijão carioca e 1 banana"

        // Aquecimento prévio (warm-up do banco de sementes e regex)
        _ = MealParserEngine.shared.parseMeal(text: complexMealInput)

        let iterations = 10
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            let parsed = MealParserEngine.shared.parseMeal(text: complexMealInput)
            XCTAssertEqual(parsed.items.count, 4)
            XCTAssertGreaterThan(parsed.totalCalories, 400.0)
        }
        let totalTime = CFAbsoluteTimeGetCurrent() - start
        let avgTimeMs = (totalTime / Double(iterations)) * 1000.0

        print("⚡ [Benchmark] MealParserEngine média: \(String(format: "%.2f", avgTimeMs))ms por parsing complexo (SLA limite: 100ms)")
        XCTAssertLessThan(avgTimeMs, 100.0, "Parsing de refeição complexa excedeu 100ms: \(avgTimeMs)ms")
    }

    /// Valida o critério de produto: Registro e consulta de hidratação em menos de 5ms
    /// (Requisito de SLA da interface do app: < 2s).
    func testHydrationLoggingAndQueryBenchmarkUnder5ms() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("bench_water_\(UUID().uuidString).json")
        let store = WaterStore(storageURL: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Aquecimento
        store.addWater(amount: 250.0)
        _ = store.totalWater()

        let iterations = 25
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            store.addWater(amount: 250.0)
            let total = store.totalWater()
            let progress = store.progress(targetWaterMl: 3000.0)
            XCTAssertGreaterThan(total, 0.0)
            XCTAssertGreaterThan(progress, 0.0)
        }
        let totalTime = CFAbsoluteTimeGetCurrent() - start
        let avgTimeMs = (totalTime / Double(iterations)) * 1000.0

        print("⚡ [Benchmark] WaterStore log + query média: \(String(format: "%.2f", avgTimeMs))ms por operação (SLA limite: 5ms)")
        XCTAssertLessThan(avgTimeMs, 5.0, "Registro e consulta de hidratação excedeu 5ms: \(avgTimeMs)ms")
    }

    /// Valida o critério de produto: Cálculo de tendência EWMA e composição Pollock em menos de 10ms.
    func testEWMATrendAndPollockCompositionBenchmarkUnder10ms() {
        let calendar = Calendar.current
        let today = Date()

        // Massa de teste: 90 dias de pesagens diárias contínuas com ruído
        var weightHistory: [WeightDataPoint] = []
        for day in 0..<90 {
            let date = calendar.date(byAdding: .day, value: -day, to: today)!
            let oscillation = Double((day * 3) % 7) * 0.15
            let weight = 82.0 + (Double(day) * 0.03) + oscillation
            weightHistory.append(WeightDataPoint(date: date, weightKg: weight))
        }
        weightHistory.sort { $0.date < $1.date }

        let skinfolds = SkinfoldMeasurements(
            chestMm: 12.0,
            abdominalMm: 22.0,
            middleAxillaryMm: 14.0,
            subscapularMm: 16.0,
            suprailiacMm: 18.0,
            thighMm: 20.0,
            tricepsMm: 13.0
        )

        let iterations = 20
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            // 1. EWMA smoothing em série temporal de 90 pontos
            let ewmaSeries = WeightTrendCalculator.calculateEWMA(measurements: weightHistory, spanDays: 7)

            // 2. Velocidade semanal
            let velocity = WeightTrendCalculator.calculateWeeklyVelocity(measurements: weightHistory, daysWindow: 14)

            // 3. Projeção de meta corporal
            let projection = WeightTrendCalculator.projectTargetDate(measurements: weightHistory, targetWeightKg: 78.0)

            // 4. Jackson & Pollock 7 Dobras + Siri + Fracionamento em 4 massas
            let pollock = BodyCompositionCalculator.calculate7Folds(
                skinfolds: skinfolds,
                weightKg: 82.0,
                ageYears: 29.0,
                sex: .male
            )

            XCTAssertEqual(ewmaSeries.count, 90)
            XCTAssertNotNil(velocity)
            XCTAssertNotNil(projection)
            XCTAssertNotNil(pollock)
        }
        let totalTime = CFAbsoluteTimeGetCurrent() - start
        let avgTimeMs = (totalTime / Double(iterations)) * 1000.0

        print("⚡ [Benchmark] EWMA + Pollock média: \(String(format: "%.2f", avgTimeMs))ms por ciclo completo (SLA limite: 10ms)")
        XCTAssertLessThan(avgTimeMs, 10.0, "Cálculo EWMA e Pollock excedeu 10ms: \(avgTimeMs)ms")
    }
}
