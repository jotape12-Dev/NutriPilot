import Foundation

// MARK: - Modelos de Relatório Consolidado (DTOs)

/// Representa a sumarização nutricional diária de macronutrientes e água.
public struct DailyNutritionSummary: Codable, Sendable, Equatable {
    public let date: Date
    public let waterMl: Double
    public let calories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let fiberGrams: Double

    public init(
        date: Date,
        waterMl: Double,
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double
    ) {
        self.date = date
        self.waterMl = waterMl.rounded(to: 1)
        self.calories = calories.rounded(to: 1)
        self.proteinGrams = proteinGrams.rounded(to: 1)
        self.carbsGrams = carbsGrams.rounded(to: 1)
        self.fatGrams = fatGrams.rounded(to: 1)
        self.fiberGrams = fiberGrams.rounded(to: 1)
    }
}

/// Média e histórico detalhado de consumo dos últimos 7 dias.
public struct SevenDayNutritionSummary: Codable, Sendable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let averageWaterMl: Double
    public let averageCalories: Double
    public let averageProteinGrams: Double
    public let averageCarbsGrams: Double
    public let averageFatGrams: Double
    public let averageFiberGrams: Double
    public let dailyEntries: [DailyNutritionSummary]

    public init(
        startDate: Date,
        endDate: Date,
        averageWaterMl: Double,
        averageCalories: Double,
        averageProteinGrams: Double,
        averageCarbsGrams: Double,
        averageFatGrams: Double,
        averageFiberGrams: Double,
        dailyEntries: [DailyNutritionSummary]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.averageWaterMl = averageWaterMl.rounded(to: 1)
        self.averageCalories = averageCalories.rounded(to: 1)
        self.averageProteinGrams = averageProteinGrams.rounded(to: 1)
        self.averageCarbsGrams = averageCarbsGrams.rounded(to: 1)
        self.averageFatGrams = averageFatGrams.rounded(to: 1)
        self.averageFiberGrams = averageFiberGrams.rounded(to: 1)
        self.dailyEntries = dailyEntries
    }
}

/// Registro pontual de pesagem com comparação de peso real e peso de tendência suavizado por EWMA.
public struct WeightReportItem: Codable, Sendable, Equatable {
    public let date: Date
    public let actualWeightKg: Double
    public let trendWeightKg: Double?

    public init(date: Date, actualWeightKg: Double, trendWeightKg: Double?) {
        self.date = date
        self.actualWeightKg = actualWeightKg.rounded(to: 2)
        self.trendWeightKg = trendWeightKg?.rounded(to: 2)
    }
}

/// Sumário de evolução e velocidade ponderal.
public struct WeightPredictionSummary: Codable, Sendable, Equatable {
    public let currentTrendWeightKg: Double
    public let targetWeightKg: Double?
    public let weeklyVelocityKg: Double?
    public let statusDescription: String

    public init(
        currentTrendWeightKg: Double,
        targetWeightKg: Double? = nil,
        weeklyVelocityKg: Double? = nil,
        statusDescription: String
    ) {
        self.currentTrendWeightKg = currentTrendWeightKg.rounded(to: 2)
        self.targetWeightKg = targetWeightKg?.rounded(to: 2)
        self.weeklyVelocityKg = weeklyVelocityKg?.rounded(to: 2)
        self.statusDescription = statusDescription
    }
}

/// Avaliação antropométrica com todas as circunferências corporais registradas.
public struct CircumferencesReport: Codable, Sendable, Equatable {
    public let date: Date
    public let waistCm: Double?
    public let hipCm: Double?
    public let waistToHipRatio: Double?
    public let chestCm: Double?
    public let shoulderCm: Double?
    public let abdomenCm: Double?
    public let leftArmRelaxedCm: Double?
    public let rightArmRelaxedCm: Double?
    public let leftArmContractedCm: Double?
    public let rightArmContractedCm: Double?
    public let leftForearmCm: Double?
    public let rightForearmCm: Double?
    public let leftThighCm: Double?
    public let rightThighCm: Double?
    public let leftCalfCm: Double?
    public let rightCalfCm: Double?

    public init(
        date: Date,
        waistCm: Double? = nil,
        hipCm: Double? = nil,
        waistToHipRatio: Double? = nil,
        chestCm: Double? = nil,
        shoulderCm: Double? = nil,
        abdomenCm: Double? = nil,
        leftArmRelaxedCm: Double? = nil,
        rightArmRelaxedCm: Double? = nil,
        leftArmContractedCm: Double? = nil,
        rightArmContractedCm: Double? = nil,
        leftForearmCm: Double? = nil,
        rightForearmCm: Double? = nil,
        leftThighCm: Double? = nil,
        rightThighCm: Double? = nil,
        leftCalfCm: Double? = nil,
        rightCalfCm: Double? = nil
    ) {
        self.date = date
        self.waistCm = waistCm
        self.hipCm = hipCm
        self.waistToHipRatio = waistToHipRatio
        self.chestCm = chestCm
        self.shoulderCm = shoulderCm
        self.abdomenCm = abdomenCm
        self.leftArmRelaxedCm = leftArmRelaxedCm
        self.rightArmRelaxedCm = rightArmRelaxedCm
        self.leftArmContractedCm = leftArmContractedCm
        self.rightArmContractedCm = rightArmContractedCm
        self.leftForearmCm = leftForearmCm
        self.rightForearmCm = rightForearmCm
        self.leftThighCm = leftThighCm
        self.rightThighCm = rightThighCm
        self.leftCalfCm = leftCalfCm
        self.rightCalfCm = rightCalfCm
    }
}

/// Registro de dobras cutâneas (Jackson & Pollock).
public struct SkinfoldsReport: Codable, Sendable, Equatable {
    public let date: Date
    public let chestMm: Double?
    public let abdominalMm: Double?
    public let middleAxillaryMm: Double?
    public let subscapularMm: Double?
    public let suprailiacMm: Double?
    public let thighMm: Double?
    public let tricepsMm: Double?
    public let sumOf7FoldsMm: Double?
    public let sumOf3FoldsMaleMm: Double?
    public let sumOf3FoldsFemaleMm: Double?

    public init(
        date: Date,
        chestMm: Double? = nil,
        abdominalMm: Double? = nil,
        middleAxillaryMm: Double? = nil,
        subscapularMm: Double? = nil,
        suprailiacMm: Double? = nil,
        thighMm: Double? = nil,
        tricepsMm: Double? = nil,
        sumOf7FoldsMm: Double? = nil,
        sumOf3FoldsMaleMm: Double? = nil,
        sumOf3FoldsFemaleMm: Double? = nil
    ) {
        self.date = date
        self.chestMm = chestMm
        self.abdominalMm = abdominalMm
        self.middleAxillaryMm = middleAxillaryMm
        self.subscapularMm = subscapularMm
        self.suprailiacMm = suprailiacMm
        self.thighMm = thighMm
        self.tricepsMm = tricepsMm
        self.sumOf7FoldsMm = sumOf7FoldsMm
        self.sumOf3FoldsMaleMm = sumOf3FoldsMaleMm
        self.sumOf3FoldsFemaleMm = sumOf3FoldsFemaleMm
    }
}

/// Relatório de composição corporal (fracionamento de 4 componentes, densidade corporal e % gordura).
public struct BodyCompositionReport: Codable, Sendable, Equatable {
    public let date: Date
    public let protocolUsed: String
    public let bodyFatPercent: Double
    public let fatMassKg: Double
    public let leanMassKg: Double
    public let muscleMassKg: Double?
    public let boneMassKg: Double?
    public let residualMassKg: Double?
    public let waterPercent: Double?
    public let visceralFatLevel: Int?

    public init(
        date: Date,
        protocolUsed: String,
        bodyFatPercent: Double,
        fatMassKg: Double,
        leanMassKg: Double,
        muscleMassKg: Double? = nil,
        boneMassKg: Double? = nil,
        residualMassKg: Double? = nil,
        waterPercent: Double? = nil,
        visceralFatLevel: Int? = nil
    ) {
        self.date = date
        self.protocolUsed = protocolUsed
        self.bodyFatPercent = bodyFatPercent.rounded(to: 1)
        self.fatMassKg = fatMassKg.rounded(to: 2)
        self.leanMassKg = leanMassKg.rounded(to: 2)
        self.muscleMassKg = muscleMassKg?.rounded(to: 2)
        self.boneMassKg = boneMassKg?.rounded(to: 2)
        self.residualMassKg = residualMassKg?.rounded(to: 2)
        self.waterPercent = waterPercent?.rounded(to: 1)
        self.visceralFatLevel = visceralFatLevel
    }
}

/// Estrutura consolidada completa de exportação do paciente.
public struct PatientReport: Codable, Sendable, Equatable {
    public let generatedAt: Date
    public let profile: UserProfile?
    public let target: NutritionTarget?
    public let sevenDayNutrition: SevenDayNutritionSummary
    public let weightHistory: [WeightReportItem]
    public let weightPrediction: WeightPredictionSummary?
    public let latestCircumferences: CircumferencesReport?
    public let latestSkinfolds: SkinfoldsReport?
    public let bodyComposition: BodyCompositionReport?

    public init(
        generatedAt: Date,
        profile: UserProfile?,
        target: NutritionTarget?,
        sevenDayNutrition: SevenDayNutritionSummary,
        weightHistory: [WeightReportItem],
        weightPrediction: WeightPredictionSummary?,
        latestCircumferences: CircumferencesReport?,
        latestSkinfolds: SkinfoldsReport?,
        bodyComposition: BodyCompositionReport?
    ) {
        self.generatedAt = generatedAt
        self.profile = profile
        self.target = target
        self.sevenDayNutrition = sevenDayNutrition
        self.weightHistory = weightHistory
        self.weightPrediction = weightPrediction
        self.latestCircumferences = latestCircumferences
        self.latestSkinfolds = latestSkinfolds
        self.bodyComposition = bodyComposition
    }
}

// MARK: - Motor de Exportação de Relatórios Clínicos

/// Motor responsável por agregar dados de múltiplos stores locais e produzir relatórios
/// profissionais em formato JSON (estruturado) e Markdown (formatado para impressão e exportação em PDF para nutricionistas).
public struct ReportExporter: Sendable {

    public init() {}

    // MARK: - Construção de Modelo Consolidado

    /// Constrói a estrutura agregada de dados `PatientReport` a partir dos stores da aplicação.
    public static func buildReport(
        profileStore: ProfileStore,
        mealStore: MealStore,
        waterStore: WaterStore,
        bodyStore: BodyMeasurementStore,
        referenceDate: Date = Date()
    ) -> PatientReport {
        let calendar = Calendar.current
        let startOfReference = calendar.startOfDay(for: referenceDate)

        // 1. Perfil e Metas
        let profile = profileStore.currentProfile
        let target = profileStore.currentTarget

        // 2. Histórico e Médias dos Últimos 7 Dias (incluindo o dia de referência)
        var dailyEntries: [DailyNutritionSummary] = []
        var sumWater = 0.0
        var sumCalories = 0.0
        var sumProtein = 0.0
        var sumCarbs = 0.0
        var sumFat = 0.0
        var sumFiber = 0.0

        for offset in (0..<7).reversed() {
            let day = calendar.date(byAdding: .day, value: -offset, to: startOfReference) ?? startOfReference
            let totals = mealStore.dailyTotals(for: day)
            let water = waterStore.totalWaterMl(for: day)

            let entry = DailyNutritionSummary(
                date: day,
                waterMl: water,
                calories: totals.calories,
                proteinGrams: totals.proteinGrams,
                carbsGrams: totals.carbsGrams,
                fatGrams: totals.fatGrams,
                fiberGrams: totals.fiberGrams
            )
            dailyEntries.append(entry)

            sumWater += water
            sumCalories += totals.calories
            sumProtein += totals.proteinGrams
            sumCarbs += totals.carbsGrams
            sumFat += totals.fatGrams
            sumFiber += totals.fiberGrams
        }

        let dayCount = max(1.0, Double(dailyEntries.count))
        let sevenDaySummary = SevenDayNutritionSummary(
            startDate: dailyEntries.first?.date ?? referenceDate,
            endDate: dailyEntries.last?.date ?? referenceDate,
            averageWaterMl: sumWater / dayCount,
            averageCalories: sumCalories / dayCount,
            averageProteinGrams: sumProtein / dayCount,
            averageCarbsGrams: sumCarbs / dayCount,
            averageFatGrams: sumFat / dayCount,
            averageFiberGrams: sumFiber / dayCount,
            dailyEntries: dailyEntries
        )

        // 3. Histórico de Peso com EWMA
        let ewmaSeries = bodyStore.weightTrendSeries(spanDays: 7)
        let weightHistory: [WeightReportItem]
        if !ewmaSeries.isEmpty {
            weightHistory = ewmaSeries.map {
                WeightReportItem(date: $0.date, actualWeightKg: $0.actualWeightKg, trendWeightKg: $0.trendWeightKg)
            }
        } else {
            weightHistory = bodyStore.sortedMeasurements.map {
                WeightReportItem(date: $0.measuredAt, actualWeightKg: $0.weightKg, trendWeightKg: nil)
            }
        }

        let currentTrend = bodyStore.currentTrendWeight(spanDays: 7) ?? bodyStore.latestMeasurement?.weightKg ?? profile?.currentWeightKg
        let velocity = bodyStore.weeklyVelocity(daysWindow: 14, referenceDate: referenceDate)

        var predictionSummary: WeightPredictionSummary? = nil
        if let trend = currentTrend {
            let statusDesc: String
            if let vel = velocity {
                if abs(vel) < 0.05 {
                    statusDesc = "Estável / Platô ponderal"
                } else if vel < 0 {
                    statusDesc = "Perda de peso a \(abs(vel)) kg/semana"
                } else {
                    statusDesc = "Ganho de peso a \(vel) kg/semana"
                }
            } else {
                statusDesc = "Dados insuficientes para velocidade semanal"
            }

            predictionSummary = WeightPredictionSummary(
                currentTrendWeightKg: trend,
                targetWeightKg: nil,
                weeklyVelocityKg: velocity,
                statusDescription: statusDesc
            )
        }

        // 4. Circunferências Corporais Mais Recentes
        var circumferencesReport: CircumferencesReport? = nil
        if let m = bodyStore.sortedMeasurements.reversed().first(where: {
            $0.waistCm != nil || $0.hipCm != nil || $0.chestCm != nil ||
            $0.shoulderCm != nil || $0.abdomenCm != nil ||
            $0.leftArmRelaxedCm != nil || $0.rightArmRelaxedCm != nil ||
            $0.leftArmContractedCm != nil || $0.rightArmContractedCm != nil ||
            $0.leftForearmCm != nil || $0.rightForearmCm != nil ||
            $0.leftThighCm != nil || $0.rightThighCm != nil ||
            $0.leftCalfCm != nil || $0.rightCalfCm != nil
        }) {
            var rcq: Double? = nil
            if let w = m.waistCm, let h = m.hipCm, h > 0 {
                rcq = (w / h).rounded(to: 2)
            }

            circumferencesReport = CircumferencesReport(
                date: m.measuredAt,
                waistCm: m.waistCm,
                hipCm: m.hipCm,
                waistToHipRatio: rcq,
                chestCm: m.chestCm,
                shoulderCm: m.shoulderCm,
                abdomenCm: m.abdomenCm,
                leftArmRelaxedCm: m.leftArmRelaxedCm,
                rightArmRelaxedCm: m.rightArmRelaxedCm,
                leftArmContractedCm: m.leftArmContractedCm,
                rightArmContractedCm: m.rightArmContractedCm,
                leftForearmCm: m.leftForearmCm,
                rightForearmCm: m.rightForearmCm,
                leftThighCm: m.leftThighCm,
                rightThighCm: m.rightThighCm,
                leftCalfCm: m.leftCalfCm,
                rightCalfCm: m.rightCalfCm
            )
        }

        // 5. Dobras Cutâneas e Composição Corporal
        var skinfoldsReport: SkinfoldsReport? = nil
        var bodyCompositionReport: BodyCompositionReport? = nil

        if let m = bodyStore.sortedMeasurements.reversed().first(where: { $0.skinfolds != nil }) {
            if let sf = m.skinfolds {
                skinfoldsReport = SkinfoldsReport(
                    date: m.measuredAt,
                    chestMm: sf.chestMm,
                    abdominalMm: sf.abdominalMm,
                    middleAxillaryMm: sf.middleAxillaryMm,
                    subscapularMm: sf.subscapularMm,
                    suprailiacMm: sf.suprailiacMm,
                    thighMm: sf.thighMm,
                    tricepsMm: sf.tricepsMm,
                    sumOf7FoldsMm: sf.sumOf7Folds,
                    sumOf3FoldsMaleMm: sf.sumOf3FoldsMale,
                    sumOf3FoldsFemaleMm: sf.sumOf3FoldsFemale
                )

                if let prof = profile {
                    let age = Double(prof.age)
                    let weight = m.weightKg > 0 ? m.weightKg : prof.currentWeightKg

                    if let result7 = BodyCompositionCalculator.calculate7Folds(skinfolds: sf, weightKg: weight, ageYears: age, sex: prof.sex) {
                        bodyCompositionReport = BodyCompositionReport(
                            date: m.measuredAt,
                            protocolUsed: result7.protocolUsed,
                            bodyFatPercent: result7.bodyFatPercent,
                            fatMassKg: result7.fatMassKg,
                            leanMassKg: result7.leanMassKg,
                            muscleMassKg: result7.muscleMassKg,
                            boneMassKg: result7.boneMassKg,
                            residualMassKg: result7.residualMassKg,
                            waterPercent: m.waterPercent,
                            visceralFatLevel: m.visceralFatLevel
                        )
                    } else if let result3 = BodyCompositionCalculator.calculate3Folds(skinfolds: sf, weightKg: weight, ageYears: age, sex: prof.sex) {
                        bodyCompositionReport = BodyCompositionReport(
                            date: m.measuredAt,
                            protocolUsed: result3.protocolUsed,
                            bodyFatPercent: result3.bodyFatPercent,
                            fatMassKg: result3.fatMassKg,
                            leanMassKg: result3.leanMassKg,
                            muscleMassKg: result3.muscleMassKg,
                            boneMassKg: result3.boneMassKg,
                            residualMassKg: result3.residualMassKg,
                            waterPercent: m.waterPercent,
                            visceralFatLevel: m.visceralFatLevel
                        )
                    }
                }
            }
        }

        // Se ainda não tiver cálculo de dobras mas tiver bioimpedância/avaliação direta com bodyFatPercent
        if bodyCompositionReport == nil, let m = bodyStore.sortedMeasurements.reversed().first(where: { $0.bodyFatPercent != nil }) {
            let bf = m.bodyFatPercent!
            let fatKg = m.fatMassKg ?? (m.weightKg * (bf / 100.0)).rounded(to: 2)
            let leanKg = m.leanMassKg ?? max(0, m.weightKg - fatKg).rounded(to: 2)

            bodyCompositionReport = BodyCompositionReport(
                date: m.measuredAt,
                protocolUsed: m.source.rawValue,
                bodyFatPercent: bf,
                fatMassKg: fatKg,
                leanMassKg: leanKg,
                muscleMassKg: m.muscularMassKg,
                boneMassKg: m.boneMassKg,
                residualMassKg: m.residualMassKg,
                waterPercent: m.waterPercent,
                visceralFatLevel: m.visceralFatLevel
            )
        }

        return PatientReport(
            generatedAt: referenceDate,
            profile: profile,
            target: target,
            sevenDayNutrition: sevenDaySummary,
            weightHistory: weightHistory,
            weightPrediction: predictionSummary,
            latestCircumferences: circumferencesReport,
            latestSkinfolds: skinfoldsReport,
            bodyComposition: bodyCompositionReport
        )
    }

    // MARK: - Exportação JSON

    /// Exporta os dados consolidados do paciente em formato JSON formatado.
    public static func exportJSON(
        profileStore: ProfileStore,
        mealStore: MealStore,
        waterStore: WaterStore,
        bodyStore: BodyMeasurementStore,
        referenceDate: Date = Date()
    ) -> Data {
        let report = buildReport(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore,
            referenceDate: referenceDate
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(report)
        } catch {
            print("Erro ao serializar relatório JSON: \(error)")
            return Data("{}".utf8)
        }
    }

    public func exportJSON(
        profileStore: ProfileStore,
        mealStore: MealStore,
        waterStore: WaterStore,
        bodyStore: BodyMeasurementStore,
        referenceDate: Date = Date()
    ) -> Data {
        Self.exportJSON(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore,
            referenceDate: referenceDate
        )
    }

    // MARK: - Exportação Markdown

    /// Gera relatório consolidado completo formatado em Markdown profissional,
    /// ideal para visualização, impressão ou conversão direta para PDF por nutricionistas.
    public static func exportMarkdownReport(
        profileStore: ProfileStore,
        mealStore: MealStore,
        waterStore: WaterStore,
        bodyStore: BodyMeasurementStore,
        referenceDate: Date = Date()
    ) -> String {
        let report = buildReport(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore,
            referenceDate: referenceDate
        )

        return formatMarkdown(report: report)
    }

    public func exportMarkdownReport(
        profileStore: ProfileStore,
        mealStore: MealStore,
        waterStore: WaterStore,
        bodyStore: BodyMeasurementStore,
        referenceDate: Date = Date()
    ) -> String {
        Self.exportMarkdownReport(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore,
            referenceDate: referenceDate
        )
    }

    // MARK: - Formatador Markdown

    private static func formatMarkdown(report: PatientReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.locale = Locale(identifier: "pt_BR")

        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        dateTimeFormatter.locale = Locale(identifier: "pt_BR")

        var md = ""

        // Cabeçalho
        md += "# 📋 Relatório de Acompanhamento Nutricional\n"
        md += "**NutriPilot Clinical Engine** | *Documento oficial para acompanhamento clínico nutricional*\n\n"
        md += "**Data de Emissão:** \(dateTimeFormatter.string(from: report.generatedAt))\n\n"
        md += "---\n\n"

        // 1. Perfil do Paciente
        md += "## 👤 1. Dados do Paciente\n"
        if let profile = report.profile {
            md += "- **Nome:** \(profile.name)\n"
            md += "- **Idade:** \(profile.age) anos\n"
            md += "- **Sexo Biológico:** \(profile.sex.rawValue)\n"
            md += "- **Altura:** \(String(format: "%.1f", profile.heightCm)) cm\n"
            md += "- **Peso Atual Cadastrado:** \(String(format: "%.1f", profile.currentWeightKg)) kg\n"
            md += "- **Nível de Atividade:** \(profile.activityLevel.rawValue)\n"
            md += "- **Objetivo Nutricional:** \(profile.goal.rawValue)\n"
            let restrictions = profile.dietaryRestrictions.isEmpty ? "Nenhuma restrição registrada" : profile.dietaryRestrictions.joined(separator: ", ")
            md += "- **Restrições / Preferências:** \(restrictions)\n"
        } else {
            md += "*Nenhum perfil de paciente cadastrado no momento.*\n"
        }
        md += "\n---\n\n"

        // 2. Metas Nutricionais
        md += "## 🎯 2. Metas Nutricionais Estabelecidas\n"
        if let target = report.target {
            md += "| Parâmetro Nutricional | Meta Diária Planejada |\n"
            md += "| :--- | :--- |\n"
            md += "| **Energia (Calorias)** | \(String(format: "%.0f", target.calories)) kcal |\n"
            md += "| **Proteínas** | \(String(format: "%.1f", target.proteinGrams)) g |\n"
            md += "| **Carboidratos** | \(String(format: "%.1f", target.carbsGrams)) g |\n"
            md += "| **Gorduras** | \(String(format: "%.1f", target.fatGrams)) g |\n"
            md += "| **Fibras** | \(String(format: "%.1f", target.fiberGrams)) g |\n"
            md += "| **Hidratação (Água)** | \(String(format: "%.0f", target.waterMl)) ml |\n\n"
            md += "*Origem da Meta: \(target.source.rawValue)*"
            if let notes = target.notes, !notes.isEmpty {
                md += " — *\(notes)*"
            }
            md += "\n"
        } else {
            md += "*Nenhuma meta nutricional configurada.*\n"
        }
        md += "\n---\n\n"

        // 3. Resumo de Consumo dos Últimos 7 Dias
        md += "## 📊 3. Consumo dos Últimos 7 Dias\n"
        let seven = report.sevenDayNutrition
        let startStr = dateFormatter.string(from: seven.startDate)
        let endStr = dateFormatter.string(from: seven.endDate)
        md += "*Período analisado: de \(startStr) até \(endStr)*\n\n"

        md += "### Médias Diárias vs Metas\n"
        md += "| Parâmetro | Média Consumida | Meta Diária | Aderência |\n"
        md += "| :--- | :--- | :--- | :--- |\n"

        let targetCal = report.target?.calories
        let targetProt = report.target?.proteinGrams
        let targetCarbs = report.target?.carbsGrams
        let targetFat = report.target?.fatGrams
        let targetFib = report.target?.fiberGrams
        let targetWater = report.target?.waterMl

        md += formatRow(param: "Calorias", avg: "\(String(format: "%.0f", seven.averageCalories)) kcal", target: targetCal.map { "\(String(format: "%.0f", $0)) kcal" }, adherence: adherencePercent(val: seven.averageCalories, target: targetCal))
        md += formatRow(param: "Proteínas", avg: "\(String(format: "%.1f", seven.averageProteinGrams)) g", target: targetProt.map { "\(String(format: "%.1f", $0)) g" }, adherence: adherencePercent(val: seven.averageProteinGrams, target: targetProt))
        md += formatRow(param: "Carboidratos", avg: "\(String(format: "%.1f", seven.averageCarbsGrams)) g", target: targetCarbs.map { "\(String(format: "%.1f", $0)) g" }, adherence: adherencePercent(val: seven.averageCarbsGrams, target: targetCarbs))
        md += formatRow(param: "Gorduras", avg: "\(String(format: "%.1f", seven.averageFatGrams)) g", target: targetFat.map { "\(String(format: "%.1f", $0)) g" }, adherence: adherencePercent(val: seven.averageFatGrams, target: targetFat))
        md += formatRow(param: "Fibras", avg: "\(String(format: "%.1f", seven.averageFiberGrams)) g", target: targetFib.map { "\(String(format: "%.1f", $0)) g" }, adherence: adherencePercent(val: seven.averageFiberGrams, target: targetFib))
        md += formatRow(param: "Água", avg: "\(String(format: "%.0f", seven.averageWaterMl)) ml", target: targetWater.map { "\(String(format: "%.0f", $0)) ml" }, adherence: adherencePercent(val: seven.averageWaterMl, target: targetWater))

        md += "\n### Detalhamento Dia a Dia\n"
        md += "| Data | Água (ml) | Calorias (kcal) | Proteínas (g) | Carbs (g) | Gorduras (g) | Fibras (g) |\n"
        md += "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n"
        for entry in seven.dailyEntries {
            let dayText = dateFormatter.string(from: entry.date)
            md += "| \(dayText) | \(String(format: "%.0f", entry.waterMl)) ml | \(String(format: "%.0f", entry.calories)) | \(String(format: "%.1f", entry.proteinGrams)) | \(String(format: "%.1f", entry.carbsGrams)) | \(String(format: "%.1f", entry.fatGrams)) | \(String(format: "%.1f", entry.fiberGrams)) |\n"
        }
        md += "\n---\n\n"

        // 4. Evolução Ponderal & Tendência EWMA
        md += "## ⚖️ 4. Evolução Ponderal & Tendência EWMA\n"
        if let pred = report.weightPrediction {
            md += "- **Peso de Tendência Atual (EWMA):** \(String(format: "%.2f", pred.currentTrendWeightKg)) kg\n"
            if let vel = pred.weeklyVelocityKg {
                let sign = vel > 0 ? "+" : ""
                md += "- **Velocidade Semanal de Peso:** \(sign)\(String(format: "%.2f", vel)) kg/semana\n"
            }
            md += "- **Diagnóstico:** \(pred.statusDescription)\n\n"
        }

        if !report.weightHistory.isEmpty {
            md += "### Histórico Recente de Pesagens\n"
            md += "| Data | Peso Real (kg) | Peso Tendência EWMA (kg) |\n"
            md += "| :--- | :--- | :--- |\n"
            for item in report.weightHistory.suffix(14) {
                let dayText = dateFormatter.string(from: item.date)
                let actual = String(format: "%.2f", item.actualWeightKg)
                let trend = item.trendWeightKg.map { String(format: "%.2f", $0) } ?? "-"
                md += "| \(dayText) | \(actual) | \(trend) |\n"
            }
        } else {
            md += "*Nenhum registro de pesagem disponível.*\n"
        }
        md += "\n---\n\n"

        // 5. Circunferências Corporais
        md += "## 📐 5. Avaliação Antropométrica (Circunferências)\n"
        if let circ = report.latestCircumferences {
            md += "*Última avaliação: \(dateFormatter.string(from: circ.date))*\n\n"
            md += "| Perímetro / Região | Medida (cm) |\n"
            md += "| :--- | :--- |\n"
            if let w = circ.waistCm { md += "| **Cintura** | \(String(format: "%.1f", w)) cm |\n" }
            if let h = circ.hipCm { md += "| **Quadril** | \(String(format: "%.1f", h)) cm |\n" }
            if let rcq = circ.waistToHipRatio { md += "| **Relação Cintura/Quadril (RCQ)** | \(String(format: "%.2f", rcq)) |\n" }
            if let ch = circ.chestCm { md += "| **Tórax** | \(String(format: "%.1f", ch)) cm |\n" }
            if let sh = circ.shoulderCm { md += "| **Ombros** | \(String(format: "%.1f", sh)) cm |\n" }
            if let ab = circ.abdomenCm { md += "| **Abdômen** | \(String(format: "%.1f", ab)) cm |\n" }
            if circ.leftArmRelaxedCm != nil || circ.rightArmRelaxedCm != nil {
                let d = circ.rightArmRelaxedCm.map { String(format: "%.1f cm", $0) } ?? "-"
                let e = circ.leftArmRelaxedCm.map { String(format: "%.1f cm", $0) } ?? "-"
                md += "| **Braço Relaxado (D / E)** | \(d) / \(e) |\n"
            }
            if circ.leftArmContractedCm != nil || circ.rightArmContractedCm != nil {
                let d = circ.rightArmContractedCm.map { String(format: "%.1f cm", $0) } ?? "-"
                let e = circ.leftArmContractedCm.map { String(format: "%.1f cm", $0) } ?? "-"
                md += "| **Braço Contraído (D / E)** | \(d) / \(e) |\n"
            }
            if circ.leftForearmCm != nil || circ.rightForearmCm != nil {
                let d = circ.rightForearmCm.map { String(format: "%.1f cm", $0) } ?? "-"
                let e = circ.leftForearmCm.map { String(format: "%.1f cm", $0) } ?? "-"
                md += "| **Antebraço (D / E)** | \(d) / \(e) |\n"
            }
            if circ.leftThighCm != nil || circ.rightThighCm != nil {
                let d = circ.rightThighCm.map { String(format: "%.1f cm", $0) } ?? "-"
                let e = circ.leftThighCm.map { String(format: "%.1f cm", $0) } ?? "-"
                md += "| **Coxa (D / E)** | \(d) / \(e) |\n"
            }
            if circ.leftCalfCm != nil || circ.rightCalfCm != nil {
                let d = circ.rightCalfCm.map { String(format: "%.1f cm", $0) } ?? "-"
                let e = circ.leftCalfCm.map { String(format: "%.1f cm", $0) } ?? "-"
                md += "| **Panturrilha (D / E)** | \(d) / \(e) |\n"
            }
        } else {
            md += "*Nenhuma medição de circunferências registrada.*\n"
        }
        md += "\n---\n\n"

        // 6. Dobras Cutâneas e Composição Corporal
        md += "## 🔬 6. Dobras Cutâneas & Composição Corporal\n"
        if let comp = report.bodyComposition {
            md += "*Última avaliação: \(dateFormatter.string(from: comp.date))* — **Protocolo:** \(comp.protocolUsed)\n\n"
            md += "| Componente Corporal | Valor Estimado |\n"
            md += "| :--- | :--- |\n"
            md += "| **Gordura Corporal (%BF)** | **\(String(format: "%.1f", comp.bodyFatPercent))%** |\n"
            md += "| **Massa Gorda** | \(String(format: "%.2f", comp.fatMassKg)) kg |\n"
            md += "| **Massa Magra** | \(String(format: "%.2f", comp.leanMassKg)) kg |\n"
            if let m = comp.muscleMassKg { md += "| **Massa Muscular** | \(String(format: "%.2f", m)) kg |\n" }
            if let b = comp.boneMassKg { md += "| **Massa Óssea** | \(String(format: "%.2f", b)) kg |\n" }
            if let r = comp.residualMassKg { md += "| **Massa Residual** | \(String(format: "%.2f", r)) kg |\n" }
            if let w = comp.waterPercent { md += "| **Água Corporal Total** | \(String(format: "%.1f", w))% |\n" }
            if let v = comp.visceralFatLevel { md += "| **Gordura Visceral (Nível)** | \(v) |\n" }
            md += "\n"
        } else {
            md += "*Nenhum cálculo de composição corporal disponível.*\n\n"
        }

        if let folds = report.latestSkinfolds {
            md += "### Dobras Cutâneas Registradas (mm)\n"
            md += "| Dobra | Espessura (mm) |\n"
            md += "| :--- | :--- |\n"
            if let v = folds.chestMm { md += "| Peitoral | \(String(format: "%.1f", v)) mm |\n" }
            if let v = folds.abdominalMm { md += "| Abdominal | \(String(format: "%.1f", v)) mm |\n" }
            if let v = folds.middleAxillaryMm { md += "| Axilar Média | \(String(format: "%.1f", v)) mm |\n" }
            if let v = folds.subscapularMm { md += "| Subescapular | \(String(format: "%.1f", v)) mm |\n" }
            if let v = folds.suprailiacMm { md += "| Suprailíaca | \(String(format: "%.1f", v)) mm |\n" }
            if let v = folds.thighMm { md += "| Coxa | \(String(format: "%.1f", v)) mm |\n" }
            if let v = folds.tricepsMm { md += "| Tríceps | \(String(format: "%.1f", v)) mm |\n" }
            if let v = folds.sumOf7FoldsMm { md += "| **Soma de 7 Dobras** | **\(String(format: "%.1f", v)) mm** |\n" }
            if let v = folds.sumOf3FoldsMaleMm { md += "| **Soma de 3 Dobras (M)** | **\(String(format: "%.1f", v)) mm** |\n" }
            if let v = folds.sumOf3FoldsFemaleMm { md += "| **Soma de 3 Dobras (F)** | **\(String(format: "%.1f", v)) mm** |\n" }
        } else {
            md += "*Nenhuma medição de dobras cutâneas registrada.*\n"
        }
        md += "\n---\n\n"

        // 7. Parecer Clínico e Conduta Nutricional
        md += "## 📝 7. Conduta Nutricional e Observações Clínicas\n\n"
        md += "```text\n"
        md += "[ Espaço reservado para evolução e orientações personalizadas do nutricionista ]\n\n\n"
        md += "```\n\n"
        md += "<br><br>\n\n"
        md += "________________________________________________________\n"
        md += "**Assinatura e Carimbo do Nutricionista Responsável (CRN)**\n"

        return md
    }

    private static func formatRow(param: String, avg: String, target: String?, adherence: String) -> String {
        let tgt = target ?? "-"
        return "| **\(param)** | \(avg) | \(tgt) | \(adherence) |\n"
    }

    private static func adherencePercent(val: Double, target: Double?) -> String {
        guard let target = target, target > 0 else { return "-" }
        let percent = (val / target) * 100.0
        return String(format: "%.1f%%", percent)
    }
}
