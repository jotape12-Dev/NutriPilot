import Foundation
import Observation

/// Configuração da janela diária de lembretes de hidratação inspirada na REA do Nutrium.
public struct WaterReminderConfig: Codable, Sendable, Equatable {
    public var startHour: Int // Padrão 8 (08:00)
    public var endHour: Int   // Padrão 22 (22:00)
    public var isEnabled: Bool

    public init(
        startHour: Int = 8,
        endHour: Int = 22,
        isEnabled: Bool = true
    ) {
        self.startHour = startHour
        self.endHour = endHour
        self.isEnabled = isEnabled
    }
}

/// Diagnóstico de status de hidratação e disparo de notificações inteligentes.
public enum WaterReminderStatus: Equatable, Sendable {
    case disabled
    case outsideWindow(reason: String)
    case targetAchieved(totalConsumed: Double, target: Double)
    case onTrack(totalConsumed: Double, expected: Double)
    case reminderNeeded(totalConsumed: Double, expected: Double, deficit: Double)
}

/// Gerenciador de hidratação com persistência local JSON, histórico com data/hora,
/// progresso contra metas diárias e regra de lembrete com pacing horário (Nutrium REA).
@Observable
public final class WaterStore: @unchecked Sendable {
    public static let shared = WaterStore()

    public private(set) var logs: [WaterLog] = []
    public var reminderConfig: WaterReminderConfig = WaterReminderConfig()

    private let fileManager = FileManager.default
    private let customStorageURL: URL?
    private let lock = NSRecursiveLock()

    public init(storageURL: URL? = nil) {
        self.customStorageURL = storageURL
        loadFromDisk()
    }

    private var storageURL: URL {
        if let custom = customStorageURL {
            return custom
        }
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("NutriPilot", isDirectory: true)

        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }

        return appSupportDir.appendingPathComponent("nutripilot_water_v1.json")
    }

    // MARK: - Adição e Remoção de Registros

    @discardableResult
    public func addLog(amountMl: Double, date: Date = Date(), loggedAt: Date = Date()) -> WaterLog {
        lock.lock()
        defer { lock.unlock() }

        let newLog = WaterLog(
            id: UUID(),
            date: date,
            amountMl: amountMl,
            loggedAt: loggedAt
        )
        logs.append(newLog)
        persistToDisk()
        return newLog
    }

    public func removeLog(id: UUID) {
        lock.lock()
        defer { lock.unlock() }

        logs.removeAll { $0.id == id }
        persistToDisk()
    }

    @discardableResult
    public func undoLastLog() -> WaterLog? {
        lock.lock()
        defer { lock.unlock() }

        guard !logs.isEmpty else { return nil }
        let removed = logs.removeLast()
        persistToDisk()
        return removed
    }

    public func clearLogs() {
        lock.lock()
        defer { lock.unlock() }

        logs.removeAll()
        persistToDisk()
    }

    // MARK: - Consultas Diárias

    /// Retorna todos os registros pertencentes ao mesmo dia do calendário informado.
    public func logs(for date: Date = Date()) -> [WaterLog] {
        lock.lock()
        defer { lock.unlock() }

        let calendar = Calendar.current
        return logs.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    /// Calcula o volume total de água (em ml) consumido no dia especificado.
    public func totalWaterMl(for date: Date = Date()) -> Double {
        logs(for: date).reduce(0) { $0 + $1.amountMl }
    }

    /// Calcula a fração de progresso em relação à meta (ex: 0.75 para 75% da meta).
    public func progress(for date: Date = Date(), targetWaterMl: Double) -> Double {
        guard targetWaterMl > 0 else { return 0.0 }
        let total = totalWaterMl(for: date)
        return total / targetWaterMl
    }

    // MARK: - Regra de Lembretes Diários (Nutrium REA)

    /// Verifica se o horário fornecido está contido na janela de lembretes configurada (ex: 08:00 - 22:00).
    public func isWithinNotificationWindow(at date: Date = Date(), config: WaterReminderConfig? = nil) -> Bool {
        let activeConfig = config ?? self.reminderConfig
        guard activeConfig.isEnabled else { return false }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        let timeInHours = Double(hour) + (Double(minute) / 60.0)
        return timeInHours >= Double(activeConfig.startHour) && timeInHours < Double(activeConfig.endHour)
    }

    /// Calcula o volume esperado de água acumulada até determinado horário do dia com base no pacing linear da janela útil.
    public func expectedWaterMl(at date: Date = Date(), targetWaterMl: Double, config: WaterReminderConfig? = nil) -> Double {
        let activeConfig = config ?? self.reminderConfig
        guard targetWaterMl > 0 else { return 0 }

        let totalWindowHours = Double(activeConfig.endHour - activeConfig.startHour)
        guard totalWindowHours > 0 else { return 0 }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentTimeInHours = Double(hour) + (Double(minute) / 60.0)

        if currentTimeInHours < Double(activeConfig.startHour) {
            return 0.0
        } else if currentTimeInHours >= Double(activeConfig.endHour) {
            return targetWaterMl
        } else {
            let elapsedHours = currentTimeInHours - Double(activeConfig.startHour)
            let paceRatio = elapsedHours / totalWindowHours
            return (targetWaterMl * paceRatio).rounded(to: 1)
        }
    }

    /// Avalia o status de hidratação para decidir se um lembrete deve ser enviado.
    public func reminderStatus(at date: Date = Date(), targetWaterMl: Double, config: WaterReminderConfig? = nil) -> WaterReminderStatus {
        let activeConfig = config ?? self.reminderConfig
        guard activeConfig.isEnabled else {
            return .disabled
        }

        let consumed = totalWaterMl(for: date)

        // Se já atingiu a meta total do dia, não notifica
        if consumed >= targetWaterMl {
            return .targetAchieved(totalConsumed: consumed, target: targetWaterMl)
        }

        // Se está fora da janela de horário estipulada (08:00 às 22:00)
        guard isWithinNotificationWindow(at: date, config: activeConfig) else {
            return .outsideWindow(reason: "Fora da janela de lembretes (\(activeConfig.startHour):00 às \(activeConfig.endHour):00)")
        }

        let expected = expectedWaterMl(at: date, targetWaterMl: targetWaterMl, config: activeConfig)
        if consumed < expected {
            let deficit = (expected - consumed).rounded(to: 1)
            return .reminderNeeded(totalConsumed: consumed, expected: expected, deficit: deficit)
        } else {
            return .onTrack(totalConsumed: consumed, expected: expected)
        }
    }

    /// Atalho booleano para os agendadores de notificação do iOS.
    public func shouldSendReminder(at date: Date = Date(), targetWaterMl: Double, config: WaterReminderConfig? = nil) -> Bool {
        if case .reminderNeeded = reminderStatus(at: date, targetWaterMl: targetWaterMl, config: config) {
            return true
        }
        return false
    }

    // MARK: - Persistência JSON

    private func persistToDisk() {
        let payload = WaterStoragePayload(logs: logs, reminderConfig: reminderConfig)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Erro ao persistir registros de água: \(error)")
        }
    }

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let payload = try JSONDecoder().decode(WaterStoragePayload.self, from: data)
            self.logs = payload.logs
            self.reminderConfig = payload.reminderConfig
        } catch {
            print("Erro ao carregar registros de água: \(error)")
        }
    }
}

private struct WaterStoragePayload: Codable {
    let logs: [WaterLog]
    let reminderConfig: WaterReminderConfig
}
