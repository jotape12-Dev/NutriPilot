import Foundation

/// Ponto de dado de pesagem diária.
public struct WeightDataPoint: Sendable, Equatable {
    public let date: Date
    public let weightKg: Double

    public init(date: Date, weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }
}

/// Ponto de dado com peso real e peso de tendência suavizado por EWMA.
public struct WeightTrendDataPoint: Sendable, Equatable {
    public let date: Date
    public let actualWeightKg: Double
    public let trendWeightKg: Double

    public init(date: Date, actualWeightKg: Double, trendWeightKg: Double) {
        self.date = date
        self.actualWeightKg = actualWeightKg
        self.trendWeightKg = trendWeightKg.rounded(to: 2)
    }
}

/// Diagnóstico e status da previsão de alcance de meta corporal (Nutrium WeightPrediction).
public enum WeightPredictionStatus: Sendable, Equatable {
    case targetAchieved
    case progressing(projectedDate: Date, weeksRemaining: Double)
    case plateau(reason: String)
    case diverging(reason: String)
    case insufficientData(reason: String)
}

/// Resultado detalhado da projeção de peso e balanço calórico.
public struct WeightPredictionResult: Sendable, Equatable {
    public let currentTrendWeightKg: Double
    public let targetWeightKg: Double
    public let weeklyRateKg: Double
    public let estimatedDailyCaloricImbalance: Double
    public let projectedDate: Date?
    public let status: WeightPredictionStatus

    public init(
        currentTrendWeightKg: Double,
        targetWeightKg: Double,
        weeklyRateKg: Double,
        estimatedDailyCaloricImbalance: Double,
        projectedDate: Date?,
        status: WeightPredictionStatus
    ) {
        self.currentTrendWeightKg = currentTrendWeightKg.rounded(to: 2)
        self.targetWeightKg = targetWeightKg.rounded(to: 2)
        self.weeklyRateKg = weeklyRateKg.rounded(to: 2)
        self.estimatedDailyCaloricImbalance = estimatedDailyCaloricImbalance.rounded(to: 1)
        self.projectedDate = projectedDate
        self.status = status
    }
}

/// Motor matemático para filtragem de ruído diário de peso (EWMA), taxa de velocidade semanal
/// e previsão preditiva de alcance de meta corporal inspirada na engenharia reversa do Nutrium.
public enum WeightTrendCalculator {

    /// Constante aproximada de energia por kg de tecido corporal (7700 kcal / kg de gordura/tecido magro misto).
    public static let kcalPerKgTissue: Double = 7700.0

    // MARK: - Média Móvel Exponencial (EWMA)

    /// Calcula a série temporal suavizada por Média Móvel Exponencial (EWMA).
    /// Suporta períodos típicos: 7 dias (curto prazo), 30 dias (médio prazo) e 90 dias (longo prazo).
    public static func calculateEWMA(
        measurements: [WeightDataPoint],
        spanDays: Int = 7
    ) -> [WeightTrendDataPoint] {
        guard !measurements.isEmpty else { return [] }

        // Ordena cronologicamente
        let sorted = measurements.sorted { $0.date < $1.date }

        let n = max(1, Double(spanDays))
        let alpha = 2.0 / (n + 1.0)

        var result: [WeightTrendDataPoint] = []
        var currentEMA = sorted[0].weightKg

        for point in sorted {
            currentEMA = (alpha * point.weightKg) + ((1.0 - alpha) * currentEMA)
            result.append(
                WeightTrendDataPoint(
                    date: point.date,
                    actualWeightKg: point.weightKg,
                    trendWeightKg: currentEMA
                )
            )
        }

        return result
    }

    /// Retorna o peso de tendência atual mais recente baseado em EWMA.
    public static func currentTrendWeight(
        measurements: [WeightDataPoint],
        spanDays: Int = 7
    ) -> Double? {
        calculateEWMA(measurements: measurements, spanDays: spanDays).last?.trendWeightKg
    }

    // MARK: - Velocidade Semanal de Peso (Delta kg/semana)

    /// Calcula a taxa de variação de peso por semana (kg/semana) nos últimos `daysWindow` dias.
    /// Utiliza regressão linear sobre a série para evitar distorções de dias atípicos de sódio/água.
    public static func calculateWeeklyVelocity(
        measurements: [WeightDataPoint],
        daysWindow: Int = 14,
        referenceDate: Date = Date()
    ) -> Double? {
        guard measurements.count >= 2 else { return nil }

        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -daysWindow, to: referenceDate) else {
            return nil
        }

        let recentPoints = measurements
            .filter { $0.date >= cutoffDate && $0.date <= referenceDate }
            .sorted { $0.date < $1.date }

        let recentDistinctDays = Set(recentPoints.map { calendar.startOfDay(for: $0.date) })
        if recentDistinctDays.count >= 2 {
            // Regressão Linear Simples: y = peso, x = dias a partir do ponto inicial
            let t0 = recentPoints[0].date
            var sumX: Double = 0
            var sumY: Double = 0
            var sumXY: Double = 0
            var sumX2: Double = 0
            let n = Double(recentPoints.count)

            for p in recentPoints {
                let days = max(0.0, p.date.timeIntervalSince(t0) / 86400.0)
                sumX += days
                sumY += p.weightKg
                sumXY += (days * p.weightKg)
                sumX2 += (days * days)
            }

            let denominator = (n * sumX2) - (sumX * sumX)
            if abs(denominator) > 0.0001 {
                let slopePerDay = ((n * sumXY) - (sumX * sumY)) / denominator
                let weeklyRate = slopePerDay * 7.0
                return weeklyRate.rounded(to: 2)
            }
        }

        // Se na janela não houver 2 dias distintos, verifica no histórico total se há ao menos 2 pesagens em dias distintos
        let sortedAll = measurements.sorted { $0.date < $1.date }
        let allDistinctDays = Set(sortedAll.map { calendar.startOfDay(for: $0.date) })
        guard allDistinctDays.count >= 2, let last = sortedAll.last else { return nil }

        guard let prev = sortedAll.reversed().first(where: { !calendar.isDate($0.date, inSameDayAs: last.date) }) else {
            return nil
        }
        let dayDiff = Double(abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: prev.date), to: calendar.startOfDay(for: last.date)).day ?? 0))
        guard dayDiff >= 1.0 else { return nil }
        let delta = last.weightKg - prev.weightKg
        return ((delta / dayDiff) * 7.0).rounded(to: 2)
    }

    // MARK: - Projeção de Alcance de Meta (Nutrium WeightPrediction)

    /// Projeta a data em que o usuário atingirá sua meta de peso com base no ritmo real recente (estilo Nutrium REA)
    /// ou em um déficit calórico planejado.
    public static func projectTargetDate(
        measurements: [WeightDataPoint],
        targetWeightKg: Double,
        plannedDailyDeficitKcal: Double? = nil,
        referenceDate: Date = Date(),
        daysWindow: Int = 14
    ) -> WeightPredictionResult {
        guard let currentTrend = currentTrendWeight(measurements: measurements, spanDays: 7) else {
            return WeightPredictionResult(
                currentTrendWeightKg: 0,
                targetWeightKg: targetWeightKg,
                weeklyRateKg: 0,
                estimatedDailyCaloricImbalance: 0,
                projectedDate: nil,
                status: .insufficientData(reason: "Nenhuma pesagem registrada.")
            )
        }

        let deltaToTarget = targetWeightKg - currentTrend

        // Meta já alcançada (tolerância de 0.15 kg)
        if abs(deltaToTarget) <= 0.15 {
            return WeightPredictionResult(
                currentTrendWeightKg: currentTrend,
                targetWeightKg: targetWeightKg,
                weeklyRateKg: 0,
                estimatedDailyCaloricImbalance: 0,
                projectedDate: referenceDate,
                status: .targetAchieved
            )
        }

        // Ritmo observado nos últimos dias
        let observedVelocity = calculateWeeklyVelocity(
            measurements: measurements,
            daysWindow: daysWindow,
            referenceDate: referenceDate
        )

        // Ritmo teórico planejado se informado
        let theoreticalVelocity: Double?
        if let deficit = plannedDailyDeficitKcal, abs(deficit) > 0 {
            // Deficit positivo indica perda de peso (velocity negativa)
            theoreticalVelocity = -((deficit * 7.0) / kcalPerKgTissue)
        } else {
            theoreticalVelocity = nil
        }

        // Adota o ritmo observado real; se indisponível, usa o teórico. Se nenhum for calculável, dados insuficientes.
        guard let effectiveVelocity = observedVelocity ?? theoreticalVelocity else {
            return WeightPredictionResult(
                currentTrendWeightKg: currentTrend,
                targetWeightKg: targetWeightKg,
                weeklyRateKg: 0,
                estimatedDailyCaloricImbalance: 0,
                projectedDate: nil,
                status: .insufficientData(reason: "Necessário ao menos 2 pesagens em dias distintos para projetar a velocidade.")
            )
        }
        let estimatedDailyCalories = (effectiveVelocity * kcalPerKgTissue) / 7.0

        // Se ritmo semanal for praticamente nulo (platô)
        if abs(effectiveVelocity) < 0.05 {
            return WeightPredictionResult(
                currentTrendWeightKg: currentTrend,
                targetWeightKg: targetWeightKg,
                weeklyRateKg: effectiveVelocity,
                estimatedDailyCaloricImbalance: estimatedDailyCalories,
                projectedDate: nil,
                status: .plateau(reason: "Peso estável nos últimos 14 dias (variação < 50g/semana).")
            )
        }

        // Validação da direção:
        // Se a meta é perder peso (deltaToTarget < 0), o ritmo DEVE ser negativo.
        // Se a meta é ganhar peso (deltaToTarget > 0), o ritmo DEVE ser positivo.
        let isMovingTowardsTarget = (deltaToTarget < 0 && effectiveVelocity < 0) || (deltaToTarget > 0 && effectiveVelocity > 0)

        guard isMovingTowardsTarget else {
            let reason = deltaToTarget < 0
                ? "Meta é emagrecimento, mas o peso de tendência está subindo (\(effectiveVelocity) kg/sem)."
                : "Meta é ganho de massa, mas o peso de tendência está caindo (\(effectiveVelocity) kg/sem)."

            return WeightPredictionResult(
                currentTrendWeightKg: currentTrend,
                targetWeightKg: targetWeightKg,
                weeklyRateKg: effectiveVelocity,
                estimatedDailyCaloricImbalance: estimatedDailyCalories,
                projectedDate: nil,
                status: .diverging(reason: reason)
            )
        }

        // Cálculo de tempo restante
        let weeksRemaining = abs(deltaToTarget / effectiveVelocity)
        let daysRemaining = Int(round(weeksRemaining * 7.0))

        let calendar = Calendar.current
        let projected = calendar.date(byAdding: .day, value: daysRemaining, to: referenceDate)

        return WeightPredictionResult(
            currentTrendWeightKg: currentTrend,
            targetWeightKg: targetWeightKg,
            weeklyRateKg: effectiveVelocity,
            estimatedDailyCaloricImbalance: estimatedDailyCalories,
            projectedDate: projected,
            status: .progressing(
                projectedDate: projected ?? referenceDate,
                weeksRemaining: weeksRemaining.rounded(to: 1)
            )
        )
    }
}
