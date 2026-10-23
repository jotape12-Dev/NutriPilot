import Foundation
import Observation

/// Configuração da janela diária de lembretes de hidratação inspirada na REA do Nutrium.
public struct WaterReminderConfig: Codable, Sendable, Equatable {
    public var startHour: Int // Padrão 8 (08:00)
    public var endHour: Int   // Padrão 22 (22:00)
    public var intervalHours: Int // Padrão 2 (intervalos a cada 2 horas)
    public var isEnabled: Bool

    public init(
        startHour: Int = 8,
        endHour: Int = 22,
        intervalHours: Int = 2,
        isEnabled: Bool = true
    ) {
        self.startHour = startHour
        self.endHour = endHour
        self.intervalHours = intervalHours
        self.isEnabled = isEnabled
    }
}

/// Decomposição detalhada do ritmo fisiológico saudável de hidratação ao longo do dia.
public struct WaterPacingBreakdown: Sendable, Equatable, Codable {
    public let targetWaterMl: Double
    public let startHour: Int
    public let endHour: Int
    public let intervalHours: Int
    public let totalWindowHours: Int
    public let healthyHourlyRateMl: Double
    public let intervalTargetMl: Double
    public let maxSafeHourlyRateMl: Double
    public let currentConsumedMl: Double
    public let expectedConsumedMl: Double
    public let currentIntervalIndex: Int
    public let totalIntervalsCount: Int
    public let currentIntervalStartHour: Int
    public let currentIntervalEndHour: Int
    public let status: PacingStatus
    public let deltaMl: Double
    public let advice: String

    public enum PacingStatus: String, Sendable, Equatable, Codable {
        case onTrack = "No Ritmo Ideal"
        case ahead = "Adiantado"
        case behind = "Atrasado"
        case targetAchieved = "Meta Atingida"
        case outsideWindow = "Fora da Janela Ativa"
    }

    public init(
        targetWaterMl: Double,
        startHour: Int,
        endHour: Int,
        intervalHours: Int,
        totalWindowHours: Int,
        healthyHourlyRateMl: Double,
        intervalTargetMl: Double,
        maxSafeHourlyRateMl: Double,
        currentConsumedMl: Double,
        expectedConsumedMl: Double,
        currentIntervalIndex: Int,
        totalIntervalsCount: Int,
        currentIntervalStartHour: Int,
        currentIntervalEndHour: Int,
        status: PacingStatus,
        deltaMl: Double,
        advice: String
    ) {
        self.targetWaterMl = targetWaterMl
        self.startHour = startHour
        self.endHour = endHour
        self.intervalHours = intervalHours
        self.totalWindowHours = totalWindowHours
        self.healthyHourlyRateMl = healthyHourlyRateMl
        self.intervalTargetMl = intervalTargetMl
        self.maxSafeHourlyRateMl = maxSafeHourlyRateMl
        self.currentConsumedMl = currentConsumedMl
        self.expectedConsumedMl = expectedConsumedMl
        self.currentIntervalIndex = currentIntervalIndex
        self.totalIntervalsCount = totalIntervalsCount
        self.currentIntervalStartHour = currentIntervalStartHour
        self.currentIntervalEndHour = currentIntervalEndHour
        self.status = status
        self.deltaMl = deltaMl
        self.advice = advice
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

    /// Atalho conveniente para adicionar volume de água no dia atual.
    @discardableResult
    public func addWater(amount: Double) -> WaterLog {
        addLog(amountMl: amount)
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

    /// Atalho para volume total de água do dia especificado.
    public func totalWater(for date: Date = Date()) -> Double {
        totalWaterMl(for: date)
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

    /// Atualiza as configurações de lembretes e ritmo diário de hidratação.
    public func updateReminderConfig(startHour: Int? = nil, endHour: Int? = nil, intervalHours: Int? = nil, isEnabled: Bool? = nil) {
        lock.lock()
        defer { lock.unlock() }

        if let s = startHour { reminderConfig.startHour = s }
        if let e = endHour { reminderConfig.endHour = e }
        if let i = intervalHours { reminderConfig.intervalHours = i }
        if let en = isEnabled { reminderConfig.isEnabled = en }
        persistToDisk()
    }

    /// Calcula a análise aprofundada de ritmo fisiológico saudável para o dia e intervalo atual.
    public func pacingBreakdown(at date: Date = Date(), targetWaterMl: Double, config: WaterReminderConfig? = nil) -> WaterPacingBreakdown {
        let activeConfig = config ?? self.reminderConfig
        let windowHours = max(1, activeConfig.endHour - activeConfig.startHour)
        let intervalHours = max(1, activeConfig.intervalHours)
        let totalIntervals = max(1, windowHours / intervalHours)
        let hourlyRate = (targetWaterMl / Double(windowHours)).rounded(to: 1)
        let intervalTarget = (hourlyRate * Double(intervalHours)).rounded(to: 1)
        let maxSafeHourlyRate: Double = 800.0 // Limite de filtração renal seguro

        let consumed = totalWaterMl(for: date)
        let expected = expectedWaterMl(at: date, targetWaterMl: targetWaterMl, config: activeConfig)
        let delta = (consumed - expected).rounded(to: 1)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentTime = Double(hour) + (Double(minute) / 60.0)

        let currentIntervalIdx: Int
        let intervalStart: Int
        let intervalEnd: Int

        if currentTime < Double(activeConfig.startHour) {
            currentIntervalIdx = 1
            intervalStart = activeConfig.startHour
            intervalEnd = min(activeConfig.endHour, activeConfig.startHour + intervalHours)
        } else if currentTime >= Double(activeConfig.endHour) {
            currentIntervalIdx = totalIntervals
            intervalStart = max(activeConfig.startHour, activeConfig.endHour - intervalHours)
            intervalEnd = activeConfig.endHour
        } else {
            let elapsed = currentTime - Double(activeConfig.startHour)
            let idx = Int(elapsed / Double(intervalHours)) + 1
            currentIntervalIdx = min(totalIntervals, max(1, idx))
            intervalStart = activeConfig.startHour + ((currentIntervalIdx - 1) * intervalHours)
            intervalEnd = min(activeConfig.endHour, intervalStart + intervalHours)
        }

        let status: WaterPacingBreakdown.PacingStatus
        let advice: String

        if consumed >= targetWaterMl {
            status = .targetAchieved
            advice = "Meta diária de hidratação concluída! Mantenha apenas goles moderados."
        } else if !isWithinNotificationWindow(at: date, config: activeConfig) {
            status = .outsideWindow
            advice = "Janela de vigília em repouso (\(activeConfig.startHour):00 às \(activeConfig.endHour):00). Evite grandes volumes de água antes de dormir."
        } else if delta < -80 {
            status = .behind
            advice = "Abaixo do ritmo (- \(Int(abs(delta))) ml). Beba um copo de água (~250ml) para manter o equilíbrio celular."
        } else if delta > 80 {
            status = .ahead
            advice = "Excelente ritmo! Você está +\(Int(delta)) ml à frente do esperado para este horário."
        } else {
            status = .onTrack
            advice = "Ritmo saudável perfeito! Taxa fisiológica estável em ~\(Int(hourlyRate)) ml/h."
        }

        return WaterPacingBreakdown(
            targetWaterMl: targetWaterMl,
            startHour: activeConfig.startHour,
            endHour: activeConfig.endHour,
            intervalHours: intervalHours,
            totalWindowHours: windowHours,
            healthyHourlyRateMl: hourlyRate,
            intervalTargetMl: intervalTarget,
            maxSafeHourlyRateMl: maxSafeHourlyRate,
            currentConsumedMl: consumed,
            expectedConsumedMl: expected,
            currentIntervalIndex: currentIntervalIdx,
            totalIntervalsCount: totalIntervals,
            currentIntervalStartHour: intervalStart,
            currentIntervalEndHour: intervalEnd,
            status: status,
            deltaMl: delta,
            advice: advice
        )
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
