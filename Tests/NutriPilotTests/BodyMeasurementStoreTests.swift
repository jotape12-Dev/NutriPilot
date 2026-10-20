import XCTest
@testable import NutriPilotCore

final class BodyMeasurementStoreTests: XCTestCase {

    var tempFileURL: URL!
    var store: BodyMeasurementStore!
    let calendar = Calendar.current
    let today = Date()

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("test_measurements_\(UUID().uuidString).json")
        store = BodyMeasurementStore(storageURL: tempFileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    func testQuickDailyWeightLogging() {
        // Registra peso inicial do dia
        store.logWeight(kg: 78.5, date: today)
        XCTAssertEqual(store.measurements.count, 1)
        XCTAssertEqual(store.latestMeasurement?.weightKg, 78.5)

        // Se registrar novamente no mesmo dia (sem circunferências ou dobras), atualiza o registro
        store.logWeight(kg: 78.2, date: today)
        XCTAssertEqual(store.measurements.count, 1)
        XCTAssertEqual(store.latestMeasurement?.weightKg, 78.2)

        // Registra em dia anterior
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            XCTFail("Erro ao calcular data de ontem")
            return
        }
        store.logWeight(kg: 78.7, date: yesterday)
        XCTAssertEqual(store.measurements.count, 2)
        XCTAssertEqual(store.sortedMeasurements.first?.weightKg, 78.7)
        XCTAssertEqual(store.latestMeasurement?.weightKg, 78.2)
    }

    func testFullAnthropometricAndBIAMeasurement() {
        let folds = SkinfoldMeasurements(
            chestMm: 12.0,
            abdominalMm: 20.0,
            middleAxillaryMm: 14.0,
            subscapularMm: 16.0,
            suprailiacMm: 18.0,
            thighMm: 20.0,
            tricepsMm: 12.0
        )

        let measurement = BodyMeasurement(
            measuredAt: today,
            weightKg: 81.0,
            waistCm: 84.0,
            hipCm: 99.0,
            chestCm: 102.0,
            leftArmRelaxedCm: 36.5,
            rightArmRelaxedCm: 37.0,
            leftThighCm: 58.0,
            rightThighCm: 58.5,
            bodyFatPercent: 15.5,
            waterPercent: 61.2,
            visceralFatLevel: 5,
            muscularMassKg: 38.4,
            skinfolds: folds,
            source: .clinicalAssessment,
            isReference: true
        )

        store.addMeasurement(measurement)

        XCTAssertEqual(store.measurements.count, 1)
        let saved = store.latestMeasurement
        XCTAssertEqual(saved?.weightKg, 81.0)
        XCTAssertEqual(saved?.waistCm, 84.0)
        XCTAssertEqual(saved?.hipCm, 99.0)
        XCTAssertEqual(saved?.waterPercent, 61.2)
        XCTAssertEqual(saved?.visceralFatLevel, 5)
        XCTAssertEqual(saved?.skinfolds?.sumOf7Folds, 112.0)
        XCTAssertTrue(saved?.isReference ?? false)
        XCTAssertEqual(store.referenceMeasurement?.id, saved?.id)
    }

    func testTrendAndVelocityIntegration() {
        // Simula 10 dias de pesagem decrescente (80.0kg -> 79.0kg)
        for day in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -9 + day, to: today)!
            let weight = 80.0 - (Double(day) * 0.1)
            store.logWeight(kg: weight, date: date)
        }

        XCTAssertEqual(store.weightHistory.count, 10)

        // Tendência calculada por EWMA deve estar próxima do valor recente
        let trend = store.currentTrendWeight(spanDays: 7)
        XCTAssertNotNil(trend)
        XCTAssertLessThan(trend ?? 0, 79.5)
        XCTAssertGreaterThan(trend ?? 0, 78.9)

        // Ritmo semanal esperado: ~ -0.7 kg/semana (0.1kg/dia * 7)
        let velocity = store.weeklyVelocity(daysWindow: 14)
        XCTAssertNotNil(velocity)
        XCTAssertEqual(velocity ?? 0, -0.7, accuracy: 0.1)

        // Projeção para meta de 77kg
        let projection = store.projectTarget(targetWeightKg: 77.0)
        if case .progressing = projection.status {
            XCTAssertNotNil(projection.projectedDate)
        } else {
            XCTFail("Esperava status .progressing na projeção")
        }
    }

    func testPersistenceToDisk() {
        store.logWeight(kg: 74.5, date: today)

        // Recarrega de uma nova instância
        let reloaded = BodyMeasurementStore(storageURL: tempFileURL)
        XCTAssertEqual(reloaded.measurements.count, 1)
        XCTAssertEqual(reloaded.latestMeasurement?.weightKg, 74.5)
    }
}
