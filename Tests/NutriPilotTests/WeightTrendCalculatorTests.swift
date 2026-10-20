import XCTest
@testable import NutriPilotCore

final class WeightTrendCalculatorTests: XCTestCase {

    let calendar = Calendar.current
    let baseDate = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 8))!

    func testEWMASmoothingFiltersSpikes() {
        // Sequência de 5 dias com peso estável em 75kg e um pico de água/sódio de 77.5kg no dia 3
        var points: [WeightDataPoint] = []
        let weights = [75.0, 75.0, 77.5, 75.0, 75.0]

        for (i, w) in weights.enumerated() {
            let d = calendar.date(byAdding: .day, value: i, to: baseDate)!
            points.append(WeightDataPoint(date: d, weightKg: w))
        }

        let ewma7 = WeightTrendCalculator.calculateEWMA(measurements: points, spanDays: 7)
        XCTAssertEqual(ewma7.count, 5)

        // No dia do pico (dia 3), o peso real foi 77.5kg, mas o peso de tendência deve amortecer esse ruído
        let spikePoint = ewma7[2]
        XCTAssertEqual(spikePoint.actualWeightKg, 77.5)
        XCTAssertLessThan(spikePoint.trendWeightKg, 76.0) // Amortecido significativamente
        XCTAssertGreaterThan(spikePoint.trendWeightKg, 75.0)

        // No dia seguinte, a tendência volta a se aproximar dos 75kg
        let afterSpike = ewma7[3]
        XCTAssertLessThan(afterSpike.trendWeightKg, spikePoint.trendWeightKg)
    }

    func testWeeklyVelocityCalculation() {
        // Usuário perdendo exatamente 0.5 kg por semana durante 14 dias (1 kg total)
        var points: [WeightDataPoint] = []
        for day in 0...14 {
            let d = calendar.date(byAdding: .day, value: day, to: baseDate)!
            let w = 80.0 - (Double(day) * (1.0 / 14.0)) // 80.0 -> 79.0 em 14 dias (-0.5 kg/semana)
            points.append(WeightDataPoint(date: d, weightKg: w))
        }

        let endDate = calendar.date(byAdding: .day, value: 14, to: baseDate)!
        let velocity = WeightTrendCalculator.calculateWeeklyVelocity(
            measurements: points,
            daysWindow: 14,
            referenceDate: endDate
        )

        XCTAssertNotNil(velocity)
        XCTAssertEqual(velocity ?? 0, -0.5, accuracy: 0.05)
    }

    func testNutriumWeightPredictionProgressing() {
        // Usuário atual em 80kg descendo a -0.5 kg/semana com meta de 75kg (faltam 5kg -> 10 semanas)
        var points: [WeightDataPoint] = []
        for day in 0...14 {
            let d = calendar.date(byAdding: .day, value: day, to: baseDate)!
            let w = 81.0 - (Double(day) * (1.0 / 14.0))
            points.append(WeightDataPoint(date: d, weightKg: w))
        }

        let refDate = calendar.date(byAdding: .day, value: 14, to: baseDate)!
        let prediction = WeightTrendCalculator.projectTargetDate(
            measurements: points,
            targetWeightKg: 75.0,
            referenceDate: refDate,
            daysWindow: 14
        )

        if case .progressing(let projectedDate, let weeksRemaining) = prediction.status {
            XCTAssertEqual(weeksRemaining, 10.0, accuracy: 1.0)
            let daysUntilProjected = calendar.dateComponents([.day], from: refDate, to: projectedDate).day ?? 0
            XCTAssertEqual(daysUntilProjected, 70, accuracy: 7)
        } else {
            XCTFail("Esperava status .progressing, obteve: \(prediction.status)")
        }

        // Ritmo diário deve equivaler a ~ -550 kcal/dia de déficit (-0.5 kg/sem * 7700 / 7)
        XCTAssertEqual(prediction.estimatedDailyCaloricImbalance, -550.0, accuracy: 50.0)
    }

    func testNutriumWeightPredictionPlateau() {
        // Usuário com peso absolutamente estável (80.0 kg todos os dias)
        var points: [WeightDataPoint] = []
        for day in 0...14 {
            let d = calendar.date(byAdding: .day, value: day, to: baseDate)!
            points.append(WeightDataPoint(date: d, weightKg: 80.0))
        }

        let refDate = calendar.date(byAdding: .day, value: 14, to: baseDate)!
        let prediction = WeightTrendCalculator.projectTargetDate(
            measurements: points,
            targetWeightKg: 72.0,
            referenceDate: refDate,
            daysWindow: 14
        )

        if case .plateau = prediction.status {
            // Sucesso esperado
        } else {
            XCTFail("Esperava status .plateau, obteve: \(prediction.status)")
        }
    }

    func testNutriumWeightPredictionDiverging() {
        // Meta é 70kg, mas o usuário está subindo de 78 para 80kg
        var points: [WeightDataPoint] = []
        for day in 0...14 {
            let d = calendar.date(byAdding: .day, value: day, to: baseDate)!
            let w = 78.0 + (Double(day) * (2.0 / 14.0))
            points.append(WeightDataPoint(date: d, weightKg: w))
        }

        let refDate = calendar.date(byAdding: .day, value: 14, to: baseDate)!
        let prediction = WeightTrendCalculator.projectTargetDate(
            measurements: points,
            targetWeightKg: 70.0,
            referenceDate: refDate,
            daysWindow: 14
        )

        if case .diverging = prediction.status {
            // Sucesso esperado
        } else {
            XCTFail("Esperava status .diverging, obteve: \(prediction.status)")
        }
    }

    func testNutriumWeightPredictionTargetAchieved() {
        let points = [
            WeightDataPoint(date: baseDate, weightKg: 70.05)
        ]

        let prediction = WeightTrendCalculator.projectTargetDate(
            measurements: points,
            targetWeightKg: 70.0,
            referenceDate: baseDate
        )

        XCTAssertEqual(prediction.status, .targetAchieved)
    }
}
