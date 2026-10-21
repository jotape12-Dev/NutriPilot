import Foundation

/// Nível de conformidade nutricional de uma métrica ou do plano alimentar como um todo.
public enum ComplianceLevel: String, Codable, Sendable {
    case optimal = "Ideal"
    case acceptable = "Aceitável"
    case below = "Abaixo da Meta"
    case above = "Acima da Meta"
    case critical = "Discrepância Crítica"
}

/// Nível de severidade de alertas gerados na avaliação clínica.
public enum AlertSeverity: String, Codable, Sendable {
    case info = "Informação"
    case warning = "Atenção"
    case danger = "Crítico"
}

/// Detalhes de conformidade para uma métrica nutricional específica (ex: Calorias, Proteínas).
public struct MetricCompliance: Codable, Sendable, Equatable {
    public var name: String
    public var target: Double
    public var planned: Double
    public var delta: Double
    public var percentage: Double
    public var unit: String
    public var level: ComplianceLevel
    public var formattedDelta: String

    public init(
        name: String,
        target: Double,
        planned: Double,
        unit: String,
        level: ComplianceLevel
    ) {
        self.name = name
        self.target = target.rounded(to: 1)
        self.planned = planned.rounded(to: 1)
        let diff = (planned - target).rounded(to: 1)
        self.delta = diff
        self.percentage = ((planned / max(1.0, target)) * 100.0).rounded(to: 1)
        self.unit = unit
        self.level = level

        if abs(diff) < 0.5 {
            self.formattedDelta = "Na meta"
        } else if diff > 0 {
            if unit == "kcal" {
                self.formattedDelta = String(format: "+%.0f %@", diff, unit)
            } else {
                self.formattedDelta = String(format: "+%.1f %@", diff, unit)
            }
        } else {
            if unit == "kcal" {
                self.formattedDelta = String(format: "%.0f %@", diff, unit)
            } else {
                self.formattedDelta = String(format: "%.1f %@", diff, unit)
            }
        }
    }
}

/// Alerta emitido pelo avaliador de conformidade nutricional.
public struct PlanComplianceAlert: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var severity: AlertSeverity
    public var message: String

    public init(id: UUID = UUID(), severity: AlertSeverity, message: String) {
        self.id = id
        self.severity = severity
        self.message = message
    }
}

/// Relatório consolidado de avaliação e conformidade de um plano alimentar com as metas nutricionais.
public struct PlanComplianceReport: Codable, Sendable, Equatable {
    public var overallLevel: ComplianceLevel
    public var title: String
    public var summaryVerdict: String
    public var calories: MetricCompliance
    public var protein: MetricCompliance
    public var carbs: MetricCompliance
    public var fat: MetricCompliance
    public var fiber: MetricCompliance
    public var proteinGramsPerKg: Double?
    public var alerts: [PlanComplianceAlert]

    public init(
        overallLevel: ComplianceLevel,
        title: String,
        summaryVerdict: String,
        calories: MetricCompliance,
        protein: MetricCompliance,
        carbs: MetricCompliance,
        fat: MetricCompliance,
        fiber: MetricCompliance,
        proteinGramsPerKg: Double? = nil,
        alerts: [PlanComplianceAlert] = []
    ) {
        self.overallLevel = overallLevel
        self.title = title
        self.summaryVerdict = summaryVerdict
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.proteinGramsPerKg = proteinGramsPerKg
        self.alerts = alerts
    }
}

/// Motor clínico de avaliação de conformidade nutricional de planos alimentares.
/// Analisa a adesão calórica, distribuição de macronutrientes, segurança biológica (lipídios mínimos e g/kg proteico)
/// e avisa com transparência sobre déficits excessivos, superávits involuntários ou desvios pós-edição de itens.
public enum MealPlanComplianceEvaluator {

    /// Avalia a conformidade completa do plano alimentar contra uma meta nutricional estipulada.
    public static func evaluate(
        plan: DailyMealPlan,
        target: NutritionTarget,
        goal: NutritionGoal? = nil,
        currentWeightKg: Double? = nil
    ) -> PlanComplianceReport {
        var alerts: [PlanComplianceAlert] = []

        // MARK: - 1. Calorias
        let plannedCalories = plan.totalCalories
        let targetCalories = target.calories
        let calDelta = plannedCalories - targetCalories
        let calRatio = plannedCalories / max(1.0, targetCalories)
        let calPercent = calRatio * 100.0

        let calLevel: ComplianceLevel
        if calRatio >= 0.95 && calRatio <= 1.05 {
            calLevel = .optimal
        } else if (calRatio >= 0.90 && calRatio < 0.95) || (calRatio > 1.05 && calRatio <= 1.10) {
            calLevel = .acceptable
        } else if calRatio < 0.80 {
            calLevel = .critical
        } else if calRatio < 0.90 {
            calLevel = .below
        } else if calRatio > 1.15 {
            calLevel = .critical
        } else {
            calLevel = .above
        }

        let caloriesMetric = MetricCompliance(
            name: "Calorias",
            target: targetCalories,
            planned: plannedCalories,
            unit: "kcal",
            level: calLevel
        )

        // Alertas de Calorias por Objetivo
        if let g = goal {
            switch g {
            case .fatLoss:
                if calRatio > 1.15 {
                    alerts.append(PlanComplianceAlert(
                        severity: .danger,
                        message: "Superávit calórico involuntário de +\(Int(calDelta)) kcal. O plano ultrapassa o limite para déficit e compromete a perda de gordura."
                    ))
                } else if calRatio > 1.05 {
                    alerts.append(PlanComplianceAlert(
                        severity: .warning,
                        message: "O plano atual excede a meta calórica em +\(Int(calDelta)) kcal, o que pode desacelerar ou estagnar a perda de gordura programada."
                    ))
                } else if calRatio < 0.80 {
                    alerts.append(PlanComplianceAlert(
                        severity: .danger,
                        message: "Déficit calórico agressivo (\(Int(calPercent))%). Consumo muito abaixo do ideal aumenta o risco de perda de massa muscular, fadiga e desaceleração metabólica."
                    ))
                }
            case .muscleGain:
                if calRatio < 0.90 {
                    alerts.append(PlanComplianceAlert(
                        severity: .warning,
                        message: "Calorias abaixo da meta de superávit para hipertrofia (\(Int(calPercent))%). Consumo insuficiente pode limitar a síntese proteica e os ganhos musculares."
                    ))
                } else if calRatio > 1.15 {
                    alerts.append(PlanComplianceAlert(
                        severity: .warning,
                        message: "Superávit calórico excessivo (+\(Int(calDelta)) kcal). Risco de acúmulo desnecessário de gordura corporal."
                    ))
                }
            default:
                if calRatio < 0.80 {
                    alerts.append(PlanComplianceAlert(
                        severity: .danger,
                        message: "Consumo calórico expressivamente abaixo da meta estipulada (\(Int(calPercent))%)."
                    ))
                } else if calRatio > 1.20 {
                    alerts.append(PlanComplianceAlert(
                        severity: .warning,
                        message: "Consumo calórico expressivamente acima da meta estipulada (\(Int(calPercent))%)."
                    ))
                }
            }
        } else {
            if calRatio < 0.80 {
                alerts.append(PlanComplianceAlert(
                    severity: .danger,
                    message: "Consumo calórico expressivamente abaixo da meta estipulada (\(Int(calPercent))%)."
                ))
            } else if calRatio > 1.20 {
                alerts.append(PlanComplianceAlert(
                    severity: .warning,
                    message: "Consumo calórico expressivamente acima da meta estipulada (\(Int(calPercent))%)."
                ))
            }
        }

        // Detecção de Edição / Remoção de Alimentos
        if calDelta <= -300 && calRatio < 0.85 {
            alerts.append(PlanComplianceAlert(
                severity: .warning,
                message: "Ao remover alimentos, o plano ficou \(abs(Int(calDelta))) kcal abaixo do déficit seguro."
            ))
        } else if calDelta >= 250 && calRatio > 1.10 {
            alerts.append(PlanComplianceAlert(
                severity: .warning,
                message: "Alimentos adicionados excederam a meta em +\(Int(calDelta)) kcal."
            ))
        }

        // MARK: - 2. Proteína
        let plannedProtein = plan.totalProtein
        let targetProtein = target.proteinGrams
        let protRatio = plannedProtein / max(1.0, targetProtein)

        let protLevel: ComplianceLevel
        if protRatio >= 0.95 && protRatio <= 1.25 {
            protLevel = .optimal
        } else if (protRatio >= 0.90 && protRatio < 0.95) || (protRatio > 1.25 && protRatio <= 1.40) {
            protLevel = .acceptable
        } else if protRatio < 0.75 {
            protLevel = .critical
        } else if protRatio < 0.90 {
            protLevel = .below
        } else {
            protLevel = .above
        }

        let proteinMetric = MetricCompliance(
            name: "Proteínas",
            target: targetProtein,
            planned: plannedProtein,
            unit: "g",
            level: protLevel
        )

        var proteinGramsPerKg: Double? = nil
        var emittedGPerKgAlert = false
        if let weight = currentWeightKg, weight > 0 {
            let gPerKg = (plannedProtein / weight).rounded(to: 2)
            proteinGramsPerKg = gPerKg

            if goal == .fatLoss && gPerKg < 1.6 {
                emittedGPerKgAlert = true
                alerts.append(PlanComplianceAlert(
                    severity: .danger,
                    message: "Proteína em \(String(format: "%.2f", gPerKg)) g/kg está abaixo do piso clínico de 1.6 g/kg para preservar massa magra em déficit calórico."
                ))
            } else if goal == .muscleGain && gPerKg < 1.6 {
                emittedGPerKgAlert = true
                alerts.append(PlanComplianceAlert(
                    severity: .warning,
                    message: "Proteína em \(String(format: "%.2f", gPerKg)) g/kg abaixo da faixa recomendada para hipertrofia (1.6 a 2.2 g/kg)."
                ))
            }
        }

        if protRatio < 0.90 && !emittedGPerKgAlert {
            alerts.append(PlanComplianceAlert(
                severity: protRatio < 0.75 ? .danger : .warning,
                message: "Aporte proteico abaixo da meta (\(Int(protRatio * 100))%). Risco de perda de massa magra e menor saciedade."
            ))
        }

        // MARK: - 3. Gorduras
        let plannedFat = plan.totalFat
        let targetFat = target.fatGrams
        let fatRatio = plannedFat / max(1.0, targetFat)

        let isFatTooLow = plannedFat < 30.0 || (currentWeightKg != nil && currentWeightKg! > 0 && (plannedFat / currentWeightKg!) < 0.5)

        let fatLevel: ComplianceLevel
        if isFatTooLow {
            fatLevel = .critical
        } else if fatRatio >= 0.90 && fatRatio <= 1.15 {
            fatLevel = .optimal
        } else if (fatRatio >= 0.80 && fatRatio < 0.90) || (fatRatio > 1.15 && fatRatio <= 1.30) {
            fatLevel = .acceptable
        } else if fatRatio < 0.80 {
            fatLevel = .below
        } else {
            fatLevel = .above
        }

        let fatMetric = MetricCompliance(
            name: "Gorduras",
            target: targetFat,
            planned: plannedFat,
            unit: "g",
            level: fatLevel
        )

        if isFatTooLow {
            alerts.append(PlanComplianceAlert(
                severity: .danger,
                message: "Gorduras totais (\(Int(plannedFat))g) abaixo do piso de segurança hormonal (mínimo de 30g ou 0.5 g/kg). Pode prejudicar a produção de hormônios esteroides e a absorção de vitaminas lipossolúveis (A, D, E e K)."
            ))
        } else if fatRatio > 1.30 {
            alerts.append(PlanComplianceAlert(
                severity: .warning,
                message: "Gorduras totais excedem a meta em mais de 30% (+\(Int(plannedFat - targetFat))g). Lipídios em excesso elevam a densidade calórica total do plano."
            ))
        }

        // MARK: - 4. Carboidratos
        let plannedCarbs = plan.totalCarbs
        let targetCarbs = target.carbsGrams
        let carbsRatio = plannedCarbs / max(1.0, targetCarbs)

        let carbsLevel: ComplianceLevel
        if carbsRatio >= 0.90 && carbsRatio <= 1.10 {
            carbsLevel = .optimal
        } else if (carbsRatio >= 0.80 && carbsRatio < 0.90) || (carbsRatio > 1.10 && carbsRatio <= 1.25) {
            carbsLevel = .acceptable
        } else if carbsRatio < 0.80 {
            carbsLevel = .below
        } else {
            carbsLevel = .above
        }

        let carbsMetric = MetricCompliance(
            name: "Carboidratos",
            target: targetCarbs,
            planned: plannedCarbs,
            unit: "g",
            level: carbsLevel
        )

        // MARK: - 5. Fibras
        let plannedFiber = plan.totalFiber
        let targetFiber = target.fiberGrams
        let fiberRatio = plannedFiber / max(1.0, targetFiber)

        let fiberLevel: ComplianceLevel
        if fiberRatio >= 0.85 {
            fiberLevel = .optimal
        } else if fiberRatio >= 0.70 {
            fiberLevel = .acceptable
        } else {
            fiberLevel = .below
        }

        let fiberMetric = MetricCompliance(
            name: "Fibras",
            target: targetFiber,
            planned: plannedFiber,
            unit: "g",
            level: fiberLevel
        )

        if plannedFiber < 20.0 {
            alerts.append(PlanComplianceAlert(
                severity: .info,
                message: "Aporte de fibras (\(Int(plannedFiber))g) abaixo do ideal (mínimo de 20g a 25g). Considere incluir mais vegetais, aveia ou frutas."
            ))
        }

        // MARK: - Nível Geral (Overall Level)
        let overallLevel: ComplianceLevel
        let hasDanger = alerts.contains(where: { $0.severity == .danger })
        let hasWarning = alerts.contains(where: { $0.severity == .warning })

        if hasDanger || calLevel == .critical || protLevel == .critical || fatLevel == .critical {
            overallLevel = .critical
        } else if calLevel == .optimal && (protLevel == .optimal || protLevel == .acceptable) && !hasWarning {
            overallLevel = .optimal
        } else if (calLevel == .optimal || calLevel == .acceptable) && (protLevel == .optimal || protLevel == .acceptable) {
            overallLevel = .acceptable
        } else if calLevel == .below {
            overallLevel = .below
        } else if calLevel == .above {
            overallLevel = .above
        } else {
            overallLevel = .acceptable
        }

        // Título
        let title: String
        switch overallLevel {
        case .optimal:
            title = "Plano Perfeitamente Alinhado"
        case .acceptable:
            title = "Plano em Boa Conformidade"
        case .below:
            title = "Plano Abaixo das Metas"
        case .above:
            title = "Plano Acima das Metas"
        case .critical:
            title = "Atenção: Discrepância Nutricional Crítica"
        }

        let summaryVerdict = generateSummaryVerdict(
            overallLevel: overallLevel,
            calories: caloriesMetric,
            protein: proteinMetric,
            proteinGPerKg: proteinGramsPerKg,
            goal: goal,
            alerts: alerts
        )

        return PlanComplianceReport(
            overallLevel: overallLevel,
            title: title,
            summaryVerdict: summaryVerdict,
            calories: caloriesMetric,
            protein: proteinMetric,
            carbs: carbsMetric,
            fat: fatMetric,
            fiber: fiberMetric,
            proteinGramsPerKg: proteinGramsPerKg,
            alerts: alerts
        )
    }

    private static func generateSummaryVerdict(
        overallLevel: ComplianceLevel,
        calories: MetricCompliance,
        protein: MetricCompliance,
        proteinGPerKg: Double?,
        goal: NutritionGoal?,
        alerts: [PlanComplianceAlert]
    ) -> String {
        var lines: [String] = []

        // Linha 1: Calorias e meta
        let calPercentStr = String(format: "%.0f%%", calories.percentage)
        switch calories.level {
        case .optimal:
            lines.append("Calorias em \(calPercentStr) da meta planejada com distribuição equilibrada.")
        case .acceptable:
            lines.append("Calorias em \(calPercentStr) da meta, dentro da faixa de tolerância fisiológica.")
        case .below:
            lines.append("Calorias em \(calPercentStr) da meta (\(calories.formattedDelta)), ingestão abaixo da meta.")
        case .above:
            lines.append("Calorias em \(calPercentStr) da meta (\(calories.formattedDelta)), superávit em relação ao planejado.")
        case .critical:
            lines.append("Discrepância calórica relevante: plano em \(calPercentStr) da meta (\(calories.formattedDelta)).")
        }

        // Linha 2: Proteína / Macronutrientes
        let gKgStr = proteinGPerKg != nil ? " (\(String(format: "%.1f", proteinGPerKg!)) g/kg)" : ""
        if protein.level == .optimal {
            lines.append("Aporte proteico excelente de \(Int(protein.planned))g\(gKgStr), ideal para preservação muscular e saciedade.")
        } else if protein.level == .acceptable {
            lines.append("Aporte proteico de \(Int(protein.planned))g\(gKgStr) adequado para suporte muscular.")
        } else if protein.level == .below || protein.level == .critical {
            lines.append("Aporte de proteínas insuficiente (\(Int(protein.planned))g\(gKgStr)), reforço proteico recomendado.")
        } else {
            lines.append("Aporte proteico de \(Int(protein.planned))g\(gKgStr) ligeiramente superior à meta calculada.")
        }

        // Linha 3: Veredito / Ação recomendada
        if let primaryDanger = alerts.first(where: { $0.severity == .danger }) {
            lines.append("Ajuste prioritário: \(primaryDanger.message)")
        } else if let primaryWarning = alerts.first(where: { $0.severity == .warning }) {
            lines.append("Recomendação: \(primaryWarning.message)")
        } else if overallLevel == .optimal {
            lines.append("Plano 100% pronto e recomendado para adesão diária sem necessidade de ajustes.")
        } else {
            lines.append("O plano possui boa consistência geral com pequenos desvios aceitáveis.")
        }

        return lines.prefix(3).joined(separator: "\n")
    }
}
