import Foundation
import Observation

/// Gerenciador de histórico antropométrico, pesagens diárias e avaliações de composição corporal
/// com persistência local em disco JSON e integração ao motor preditivo de tendência.
@Observable
public final class BodyMeasurementStore: @unchecked Sendable {
    public static let shared = BodyMeasurementStore()

    public private(set) var measurements: [BodyMeasurement] = []

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

        return appSupportDir.appendingPathComponent("nutripilot_body_measurements_v1.json")
    }

    // MARK: - Adição e Edição de Medições

    /// Registro rápido de pesagem diária. Se já houver registro no mesmo dia com medição puramente de peso,
    /// atualiza o valor existente; caso contrário, adiciona nova medição.
    @discardableResult
    public func logWeight(
        kg: Double,
        date: Date = Date(),
        source: MeasurementSource = .manual
    ) -> BodyMeasurement {
        lock.lock()
        defer { lock.unlock() }

        let calendar = Calendar.current
        if let index = measurements.firstIndex(where: {
            calendar.isDate($0.measuredAt, inSameDayAs: date) &&
            $0.skinfolds == nil &&
            $0.waistCm == nil &&
            $0.hipCm == nil
        }) {
            measurements[index].weightKg = kg
            measurements[index].measuredAt = date
            measurements[index].source = source
            persistToDisk()
            return measurements[index]
        } else {
            let newMeasurement = BodyMeasurement(
                measuredAt: date,
                weightKg: kg,
                source: source
            )
            measurements.append(newMeasurement)
            persistToDisk()
            return newMeasurement
        }
    }

    /// Adiciona uma avaliação antropométrica completa (circunferências, dobras ou bioimpedância).
    @discardableResult
    public func addMeasurement(_ measurement: BodyMeasurement) -> BodyMeasurement {
        lock.lock()
        defer { lock.unlock() }

        measurements.append(measurement)
        persistToDisk()
        return measurement
    }

    public func deleteMeasurement(id: UUID) {
        lock.lock()
        defer { lock.unlock() }

        measurements.removeAll { $0.id == id }
        persistToDisk()
    }

    public func clearMeasurements() {
        lock.lock()
        defer { lock.unlock() }

        measurements.removeAll()
        persistToDisk()
    }

    // MARK: - Consultas Antropométricas

    /// Medições organizadas em ordem cronológica crescente.
    public var sortedMeasurements: [BodyMeasurement] {
        lock.lock()
        defer { lock.unlock() }

        return measurements.sorted { $0.measuredAt < $1.measuredAt }
    }

    /// Última medição registrada.
    public var latestMeasurement: BodyMeasurement? {
        sortedMeasurements.last
    }

    /// Medição marcada como referência inicial do acompanhamento.
    public var referenceMeasurement: BodyMeasurement? {
        lock.lock()
        defer { lock.unlock() }

        return measurements.first(where: { $0.isReference }) ?? measurements.first
    }

    /// Busca medição registrada em uma data específica (mesmo dia civil).
    public func measurement(for date: Date) -> BodyMeasurement? {
        lock.lock()
        defer { lock.unlock() }

        let calendar = Calendar.current
        return measurements.first { calendar.isDate($0.measuredAt, inSameDayAs: date) }
    }

    /// Série temporal de pesagens brutas para cálculos matemáticos.
    public var weightHistory: [WeightDataPoint] {
        sortedMeasurements.map { WeightDataPoint(date: $0.measuredAt, weightKg: $0.weightKg) }
    }

    // MARK: - Tendência e Predição (Nutrium Style)

    /// Calcula o peso de tendência atual baseado em EWMA (padrão 7 dias para filtrar oscilações de água).
    public func currentTrendWeight(spanDays: Int = 7) -> Double? {
        WeightTrendCalculator.currentTrendWeight(measurements: weightHistory, spanDays: spanDays)
    }

    /// Série temporal suavizada de peso de tendência por EWMA.
    public func weightTrendSeries(spanDays: Int = 7) -> [WeightTrendDataPoint] {
        WeightTrendCalculator.calculateEWMA(measurements: weightHistory, spanDays: spanDays)
    }

    /// Velocidade semanal real de peso (kg/semana) nos últimos `daysWindow` dias.
    public func weeklyVelocity(daysWindow: Int = 14, referenceDate: Date = Date()) -> Double? {
        WeightTrendCalculator.calculateWeeklyVelocity(
            measurements: weightHistory,
            daysWindow: daysWindow,
            referenceDate: referenceDate
        )
    }

    /// Projeção de data para alcance da meta de peso (WeightPrediction Nutrium).
    public func projectTarget(
        targetWeightKg: Double,
        plannedDailyDeficitKcal: Double? = nil,
        referenceDate: Date = Date(),
        daysWindow: Int = 14
    ) -> WeightPredictionResult {
        WeightTrendCalculator.projectTargetDate(
            measurements: weightHistory,
            targetWeightKg: targetWeightKg,
            plannedDailyDeficitKcal: plannedDailyDeficitKcal,
            referenceDate: referenceDate,
            daysWindow: daysWindow
        )
    }

    // MARK: - Persistência JSON

    private func persistToDisk() {
        let payload = BodyMeasurementStoragePayload(measurements: measurements)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Erro ao persistir medições corporais no disco: \(error)")
        }
    }

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let payload = try JSONDecoder().decode(BodyMeasurementStoragePayload.self, from: data)
            self.measurements = payload.measurements
        } catch {
            print("Erro ao carregar medições corporais do disco: \(error)")
        }
    }
}

private struct BodyMeasurementStoragePayload: Codable {
    let measurements: [BodyMeasurement]
}
