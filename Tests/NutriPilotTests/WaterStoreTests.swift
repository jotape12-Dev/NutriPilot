import XCTest
@testable import NutriPilotCore

final class WaterStoreTests: XCTestCase {

    var tempFileURL: URL!
    var store: WaterStore!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("test_water_\(UUID().uuidString).json")
        store = WaterStore(storageURL: tempFileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    func testAddAndCalculateDailyTotal() {
        let now = Date()
        store.addLog(amountMl: 300, date: now)
        store.addLog(amountMl: 500, date: now)

        let total = store.totalWaterMl(for: now)
        XCTAssertEqual(total, 800)

        let progress = store.progress(for: now, targetWaterMl: 2000)
        XCTAssertEqual(progress, 0.4, accuracy: 0.001)
    }

    func testUndoLastLog() {
        let now = Date()
        store.addLog(amountMl: 250, date: now)
        store.addLog(amountMl: 350, date: now)
        XCTAssertEqual(store.totalWaterMl(for: now), 600)

        let removed = store.undoLastLog()
        XCTAssertEqual(removed?.amountMl, 350)
        XCTAssertEqual(store.totalWaterMl(for: now), 250)
    }

    func testDateFiltering() {
        let calendar = Calendar.current
        let today = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            XCTFail("Falha ao criar data de ontem")
            return
        }

        store.addLog(amountMl: 400, date: yesterday)
        store.addLog(amountMl: 600, date: today)

        XCTAssertEqual(store.totalWaterMl(for: yesterday), 400)
        XCTAssertEqual(store.totalWaterMl(for: today), 600)
    }

    func testNutriumReminderRuleOutsideWindow() {
        let calendar = Calendar.current
        // 06:30 da manhã (fora da janela 08:00 - 22:00)
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 6
        components.minute = 30
        let earlyMorning = calendar.date(from: components)!

        let status = store.reminderStatus(at: earlyMorning, targetWaterMl: 2800)
        XCTAssertFalse(store.shouldSendReminder(at: earlyMorning, targetWaterMl: 2800))
        if case .outsideWindow = status {
            // Sucesso esperado
        } else {
            XCTFail("Deveria retornar outsideWindow, retornou: \(status)")
        }
    }

    func testNutriumReminderRulePacingInsideWindow() {
        let calendar = Calendar.current
        // 15:00 da tarde: 7 horas transcorridas de uma janela de 14 horas (50% do dia útil)
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 15
        components.minute = 0
        let midDay = calendar.date(from: components)!

        let target = 2800.0
        let expected = store.expectedWaterMl(at: midDay, targetWaterMl: target)
        XCTAssertEqual(expected, 1400.0) // 50% de 2800ml

        // Cenário A: Usuário bebeu apenas 500ml (abaixo dos 1400ml esperados)
        store.addLog(amountMl: 500, date: midDay)
        let statusNeeded = store.reminderStatus(at: midDay, targetWaterMl: target)
        XCTAssertTrue(store.shouldSendReminder(at: midDay, targetWaterMl: target))
        if case .reminderNeeded(let consumed, let exp, let deficit) = statusNeeded {
            XCTAssertEqual(consumed, 500)
            XCTAssertEqual(exp, 1400)
            XCTAssertEqual(deficit, 900)
        } else {
            XCTFail("Esperava reminderNeeded, recebeu: \(statusNeeded)")
        }

        // Cenário B: Usuário bebe mais 1000ml (total 1500ml >= 1400ml)
        store.addLog(amountMl: 1000, date: midDay)
        let statusOnTrack = store.reminderStatus(at: midDay, targetWaterMl: target)
        XCTAssertFalse(store.shouldSendReminder(at: midDay, targetWaterMl: target))
        if case .onTrack(let consumed, _) = statusOnTrack {
            XCTAssertEqual(consumed, 1500)
        } else {
            XCTFail("Esperava onTrack, recebeu: \(statusOnTrack)")
        }
    }

    func testNutriumReminderTargetAchieved() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        let noon = calendar.date(from: components)!

        let target = 2000.0
        store.addLog(amountMl: 2200, date: noon)

        let status = store.reminderStatus(at: noon, targetWaterMl: target)
        XCTAssertFalse(store.shouldSendReminder(at: noon, targetWaterMl: target))
        if case .targetAchieved = status {
            // Sucesso esperado
        } else {
            XCTFail("Esperava targetAchieved, recebeu: \(status)")
        }
    }

    func testPersistenceToDisk() {
        let now = Date()
        store.addLog(amountMl: 750, date: now)

        // Cria nova instância apontando para o mesmo arquivo em disco
        let reloadedStore = WaterStore(storageURL: tempFileURL)
        XCTAssertEqual(reloadedStore.logs.count, 1)
        XCTAssertEqual(reloadedStore.totalWaterMl(for: now), 750)
    }
}
