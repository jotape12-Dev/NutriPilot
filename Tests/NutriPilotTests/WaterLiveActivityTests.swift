import XCTest
@testable import NutriPilotCore

final class WaterLiveActivityTests: XCTestCase {

    #if canImport(ActivityKit)
    func testWaterPacingActivityAttributesInitialization() {
        let attributes = WaterPacingActivityAttributes(
            targetWaterMl: 3200,
            startHour: 7,
            endHour: 23
        )
        XCTAssertEqual(attributes.targetWaterMl, 3200)
        XCTAssertEqual(attributes.startHour, 7)
        XCTAssertEqual(attributes.endHour, 23)
    }

    func testContentStateDirectInitializationAndCodable() throws {
        let date = Date()
        let state = WaterPacingActivityAttributes.ContentState(
            currentWaterMl: 1500,
            pacingStatus: "No Ritmo Ideal",
            intervalTargetMl: 400,
            hourlyRateMl: 200,
            lastUpdated: date,
            progressPercentage: 50.0
        )

        XCTAssertEqual(state.currentWaterMl, 1500)
        XCTAssertEqual(state.pacingStatus, "No Ritmo Ideal")
        XCTAssertEqual(state.intervalTargetMl, 400)
        XCTAssertEqual(state.hourlyRateMl, 200)
        XCTAssertEqual(state.progressPercentage, 50.0)

        // Validar Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WaterPacingActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.currentWaterMl, 1500)
        XCTAssertEqual(decoded.pacingStatus, "No Ritmo Ideal")
        XCTAssertEqual(decoded.intervalTargetMl, 400)
        XCTAssertEqual(decoded.hourlyRateMl, 200)
        XCTAssertEqual(decoded.progressPercentage, 50.0)
    }

    func testContentStateFromWaterPacingBreakdown() {
        let breakdown = WaterPacingBreakdown(
            targetWaterMl: 3000,
            startHour: 8,
            endHour: 22,
            intervalHours: 2,
            totalWindowHours: 14,
            healthyHourlyRateMl: 214.3,
            intervalTargetMl: 428.6,
            maxSafeHourlyRateMl: 800.0,
            currentConsumedMl: 1500,
            expectedConsumedMl: 1500,
            currentIntervalIndex: 4,
            totalIntervalsCount: 7,
            currentIntervalStartHour: 14,
            currentIntervalEndHour: 16,
            status: .onTrack,
            deltaMl: 0.0,
            advice: "Ritmo saudável"
        )

        let state = WaterPacingActivityAttributes.ContentState(
            currentWaterMl: 1500,
            breakdown: breakdown
        )

        XCTAssertEqual(state.currentWaterMl, 1500)
        XCTAssertEqual(state.pacingStatus, WaterPacingBreakdown.PacingStatus.onTrack.rawValue)
        XCTAssertEqual(state.intervalTargetMl, 428.6)
        XCTAssertEqual(state.hourlyRateMl, 214.3)
        XCTAssertEqual(state.progressPercentage, 50.0, accuracy: 0.1)
    }

    @MainActor
    func testWaterLiveActivityManagerLifecycle() {
        let manager = WaterLiveActivityManager.shared
        let config = WaterReminderConfig(startHour: 8, endHour: 22, intervalHours: 2, isEnabled: true)

        // Inicia a atividade
        manager.startLiveActivity(targetWaterMl: 2800, currentWaterMl: 700, config: config)
        XCTAssertTrue(manager.isActivityActive)

        // Atualiza a atividade
        let breakdown = WaterPacingBreakdown(
            targetWaterMl: 2800,
            startHour: 8,
            endHour: 22,
            intervalHours: 2,
            totalWindowHours: 14,
            healthyHourlyRateMl: 200.0,
            intervalTargetMl: 400.0,
            maxSafeHourlyRateMl: 800.0,
            currentConsumedMl: 1400,
            expectedConsumedMl: 1400,
            currentIntervalIndex: 4,
            totalIntervalsCount: 7,
            currentIntervalStartHour: 14,
            currentIntervalEndHour: 16,
            status: .ahead,
            deltaMl: 200.0,
            advice: "Adiantado"
        )

        manager.updateLiveActivity(currentWaterMl: 1400, breakdown: breakdown)

        #if !(os(iOS) || targetEnvironment(macCatalyst))
        XCTAssertEqual(manager.lastContentState?.currentWaterMl, 1400)
        XCTAssertEqual(manager.lastContentState?.pacingStatus, "Adiantado")
        XCTAssertEqual(manager.lastContentState?.progressPercentage ?? 0, 50.0, accuracy: 0.1)
        #endif

        // Encerra a atividade
        manager.endLiveActivity(immediate: true)
        XCTAssertFalse(manager.isActivityActive)
    }

    @MainActor
    func testWaterStoreTriggersLiveActivityUpdate() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_live_activity_\(UUID().uuidString).json")
        let store = WaterStore(storageURL: tempURL)
        let manager = WaterLiveActivityManager.shared

        // Ativa a Live Activity
        manager.startLiveActivity(targetWaterMl: 2000, currentWaterMl: 0)
        XCTAssertTrue(manager.isActivityActive)

        // Registra consumo de água
        store.addLog(amountMl: 500)

        // Aguarda execução assíncrona do Task @MainActor
        try? await Task.sleep(nanoseconds: 100_000_000)

        #if !(os(iOS) || targetEnvironment(macCatalyst))
        XCTAssertEqual(manager.lastContentState?.currentWaterMl, 500)
        #endif

        // Desfaz o último registro
        _ = store.undoLastLog()
        try? await Task.sleep(nanoseconds: 100_000_000)

        #if !(os(iOS) || targetEnvironment(macCatalyst))
        XCTAssertEqual(manager.lastContentState?.currentWaterMl, 0)
        #endif

        manager.endLiveActivity(immediate: true)
        try? FileManager.default.removeItem(at: tempURL)
    }
    #endif
}
