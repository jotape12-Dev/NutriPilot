import XCTest
@testable import NutriPilotCore

final class ReportExporterTests: XCTestCase {

    private var tempDirectory: URL!
    private var profileStore: ProfileStore!
    private var mealStore: MealStore!
    private var waterStore: WaterStore!
    private var bodyStore: BodyMeasurementStore!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let profileURL = tempDirectory.appendingPathComponent("profile.json")
        let mealURL = tempDirectory.appendingPathComponent("meals.json")
        let waterURL = tempDirectory.appendingPathComponent("water.json")
        let bodyURL = tempDirectory.appendingPathComponent("body.json")

        profileStore = ProfileStore(storageURL: profileURL)
        mealStore = MealStore(storageURL: mealURL)
        waterStore = WaterStore(storageURL: waterURL)
        bodyStore = BodyMeasurementStore(storageURL: bodyURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testExportJSONIntegrity() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let birthDate = calendar.date(byAdding: .year, value: -28, to: today)!

        // 1. Configuração do Perfil e Meta
        let profile = UserProfile(
            name: "Lucas Alencar",
            birthDate: birthDate,
            sex: .male,
            heightCm: 180.0,
            currentWeightKg: 82.0,
            activityLevel: .moderate,
            goal: .fatLoss,
            dietaryRestrictions: ["Sem lactose"]
        )
        let target = NutritionTarget(
            calories: 2200.0,
            proteinGrams: 160.0,
            carbsGrams: 210.0,
            fatGrams: 60.0,
            fiberGrams: 30.0,
            waterMl: 2800.0,
            source: .initialCalculation
        )
        profileStore.saveProfile(profile, target: target)

        // 2. Registros de Refeições e Água nos últimos 7 dias
        for offset in 0..<7 {
            let logDay = calendar.date(byAdding: .day, value: -offset, to: today)!

            // Adiciona 2400 ml de água por dia
            waterStore.addLog(amountMl: 2400.0, date: logDay, loggedAt: logDay)

            // Adiciona uma refeição com 500 kcal, 40g prot, 50g carb, 15g gord, 5g fib
            let meal = MealLog(
                date: logDay,
                mealType: .lunch,
                items: [
                    MealLogItem(name: "Frango", quantity: 150, calories: 250, proteinGrams: 35, carbsGrams: 0, fatGrams: 5, fiberGrams: 0),
                    MealLogItem(name: "Arroz", quantity: 150, calories: 250, proteinGrams: 5, carbsGrams: 50, fatGrams: 10, fiberGrams: 5)
                ]
            )
            mealStore.addMeal(meal)
        }

        // 3. Registros de Pesagem e Antropometria
        for offset in (0..<10).reversed() {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let weight = 83.0 - (Double(10 - offset) * 0.1) // 82.0 a 83.0 kg
            bodyStore.logWeight(kg: weight, date: day)
        }

        // Avaliação Antropométrica e Dobras Cutâneas
        let skinfolds = SkinfoldMeasurements(
            chestMm: 10.0,
            abdominalMm: 18.0,
            middleAxillaryMm: 12.0,
            subscapularMm: 14.0,
            suprailiacMm: 15.0,
            thighMm: 16.0,
            tricepsMm: 11.0
        )
        let fullMeasurement = BodyMeasurement(
            measuredAt: today,
            weightKg: 82.0,
            waistCm: 82.0,
            hipCm: 98.0,
            chestCm: 102.0,
            shoulderCm: 118.0,
            abdomenCm: 85.0,
            leftArmRelaxedCm: 35.0,
            rightArmRelaxedCm: 35.5,
            leftThighCm: 58.0,
            rightThighCm: 58.5,
            skinfolds: skinfolds,
            source: .clinicalAssessment
        )
        bodyStore.addMeasurement(fullMeasurement)

        // 4. Exportação JSON
        let jsonData = ReportExporter.exportJSON(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore,
            referenceDate: today
        )

        XCTAssertFalse(jsonData.isEmpty)

        // Decodificação para validação da integridade
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(PatientReport.self, from: jsonData)

        // Verificação do Perfil e Metas
        XCTAssertEqual(report.profile?.name, "Lucas Alencar")
        XCTAssertEqual(report.profile?.sex, .male)
        XCTAssertEqual(report.target?.calories, 2200.0)
        XCTAssertEqual(report.target?.waterMl, 2800.0)

        // Verificação do Resumo de 7 Dias
        XCTAssertEqual(report.sevenDayNutrition.dailyEntries.count, 7)
        XCTAssertEqual(report.sevenDayNutrition.averageWaterMl, 2400.0, accuracy: 0.1)
        XCTAssertEqual(report.sevenDayNutrition.averageCalories, 500.0, accuracy: 0.1)
        XCTAssertEqual(report.sevenDayNutrition.averageProteinGrams, 40.0, accuracy: 0.1)
        XCTAssertEqual(report.sevenDayNutrition.averageCarbsGrams, 50.0, accuracy: 0.1)

        // Verificação de Peso & EWMA
        XCTAssertGreaterThanOrEqual(report.weightHistory.count, 10)
        XCTAssertNotNil(report.weightPrediction?.currentTrendWeightKg)

        // Verificação de Circunferências
        XCTAssertNotNil(report.latestCircumferences)
        XCTAssertEqual(report.latestCircumferences?.waistCm, 82.0)
        XCTAssertEqual(report.latestCircumferences?.hipCm, 98.0)
        XCTAssertEqual(try XCTUnwrap(report.latestCircumferences?.waistToHipRatio), 0.84, accuracy: 0.01)

        // Verificação de Dobras e Jackson & Pollock 7 Dobras
        XCTAssertNotNil(report.latestSkinfolds)
        XCTAssertEqual(report.latestSkinfolds?.sumOf7FoldsMm, 96.0)
        XCTAssertNotNil(report.bodyComposition)
        XCTAssertEqual(report.bodyComposition?.protocolUsed, "Jackson & Pollock 7 Dobras")
        XCTAssertGreaterThan(report.bodyComposition?.bodyFatPercent ?? 0, 10.0)
        XCTAssertLessThan(report.bodyComposition?.bodyFatPercent ?? 100, 25.0)
        XCTAssertGreaterThan(report.bodyComposition?.leanMassKg ?? 0, 60.0)
    }

    func testExportMarkdownReportFormatting() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let birthDate = calendar.date(byAdding: .year, value: -30, to: today)!

        let profile = UserProfile(
            name: "Mariana Souza",
            birthDate: birthDate,
            sex: .female,
            heightCm: 165.0,
            currentWeightKg: 62.0,
            activityLevel: .sedentary,
            goal: .muscleGain,
            dietaryRestrictions: ["Vegetariana"]
        )
        let target = NutritionTarget(
            calories: 1900.0,
            proteinGrams: 110.0,
            carbsGrams: 230.0,
            fatGrams: 50.0,
            fiberGrams: 28.0,
            waterMl: 2200.0,
            source: .autoCalibrated
        )
        profileStore.saveProfile(profile, target: target)

        // Adiciona histórico de água e refeição
        waterStore.addLog(amountMl: 2000.0, date: today, loggedAt: today)
        mealStore.addMeal(
            MealLog(
                date: today,
                mealType: .breakfast,
                items: [
                    MealLogItem(name: "Aveia com Banana", quantity: 100, calories: 300, proteinGrams: 12, carbsGrams: 52, fatGrams: 4, fiberGrams: 6)
                ]
            )
        )

        // Dobras Jackson Pollock 3 Dobras Feminino (Tríceps, Suprailíaca, Coxa)
        let skinfolds = SkinfoldMeasurements(
            suprailiacMm: 16.0,
            thighMm: 22.0,
            tricepsMm: 14.0
        )
        bodyStore.addMeasurement(
            BodyMeasurement(
                measuredAt: today,
                weightKg: 62.0,
                waistCm: 68.0,
                hipCm: 96.0,
                skinfolds: skinfolds,
                source: .clinicalAssessment
            )
        )

        let markdown = ReportExporter.exportMarkdownReport(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore,
            referenceDate: today
        )

        // Valida seções essenciais do Markdown
        XCTAssertTrue(markdown.contains("# 📋 Relatório de Acompanhamento Nutricional"))
        XCTAssertTrue(markdown.contains("Mariana Souza"))
        XCTAssertTrue(markdown.contains("Feminino"))
        XCTAssertTrue(markdown.contains("Vegetariana"))
        XCTAssertTrue(markdown.contains("1900 kcal"))
        XCTAssertTrue(markdown.contains("2200 ml"))
        XCTAssertTrue(markdown.contains("Médias Diárias vs Metas"))
        XCTAssertTrue(markdown.contains("Detalhamento Dia a Dia"))
        XCTAssertTrue(markdown.contains("Evolução Ponderal & Tendência EWMA"))
        XCTAssertTrue(markdown.contains("Avaliação Antropométrica (Circunferências)"))
        XCTAssertTrue(markdown.contains("Cintura"))
        XCTAssertTrue(markdown.contains("Quadril"))
        XCTAssertTrue(markdown.contains("Jackson & Pollock 3 Dobras"))
        XCTAssertTrue(markdown.contains("Conduta Nutricional e Observações Clínicas"))
        XCTAssertTrue(markdown.contains("Assinatura e Carimbo do Nutricionista Responsável (CRN)"))
    }

    func testExportGracefulDefaultsWithEmptyStores() throws {
        let today = Date()

        let jsonData = ReportExporter.exportJSON(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore,
            referenceDate: today
        )

        XCTAssertFalse(jsonData.isEmpty)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(PatientReport.self, from: jsonData)

        XCTAssertNil(report.profile)
        XCTAssertNil(report.target)
        XCTAssertEqual(report.sevenDayNutrition.dailyEntries.count, 7)
        XCTAssertEqual(report.sevenDayNutrition.averageCalories, 0.0)
        XCTAssertEqual(report.sevenDayNutrition.averageWaterMl, 0.0)

        let markdown = ReportExporter.exportMarkdownReport(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore,
            referenceDate: today
        )

        XCTAssertTrue(markdown.contains("Nenhum perfil de paciente cadastrado no momento"))
        XCTAssertTrue(markdown.contains("Nenhuma meta nutricional configurada"))
        XCTAssertTrue(markdown.contains("Nenhum registro de pesagem disponível"))
    }
}
