import XCTest
#if canImport(PDFKit)
import PDFKit
#endif
@testable import NutriPilotCore

final class BioimpedancePDFParserTests: XCTestCase {

    func testInBody770ReportParsing() {
        let inBodyReportText = """
        Folha de Resultados InBody 770
        Nome: Carlos Eduardo da Silva
        ID: 104928
        Idade: 32   Sexo: Masculino   Altura: 182.0 cm
        Data do Teste: 14/05/2026

        Análise da Composição Corporal:
        Peso: 84.5 kg
        Massa de Músculo Esquelético (MME): 41.2 kg
        Massa Livre de Gordura: 71.8 kg
        Água Corporal Total (ACT): 52.4 L
        Percentual de Gordura Corporal (PGC): 15.0 %
        Taxa Metabólica Basal (TMB): 1921 kcal
        Nível de Gordura Visceral: Nível 5
        """

        let parsed = BioimpedancePDFParser.parse(text: inBodyReportText)

        XCTAssertEqual(parsed.detectedEquipmentOrClinic, "InBody 770")
        XCTAssertEqual(parsed.name, "Carlos Eduardo da Silva")
        XCTAssertEqual(parsed.sex, .male)
        XCTAssertEqual(parsed.heightCm, 182.0)
        XCTAssertEqual(parsed.weightKg, 84.5)
        XCTAssertEqual(parsed.bodyFatPercentage, 15.0)
        XCTAssertEqual(parsed.leanMassKg, 71.8)
        XCTAssertEqual(parsed.muscleMassKg, 41.2)
        XCTAssertEqual(parsed.bodyWaterLitersOrPercentage, 52.4)
        XCTAssertEqual(parsed.visceralFatLevel, 5)
        XCTAssertEqual(parsed.basalMetabolicRateKcal, 1921.0)

        // Valida conversão para BodyMeasurement
        let measurement = parsed.toBodyMeasurement()
        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.weightKg, 84.5)
        XCTAssertEqual(measurement?.bodyFatPercent, 15.0)
        XCTAssertEqual(measurement?.leanMassKg, 71.8)
        XCTAssertEqual(measurement?.visceralFatLevel, 5)
        XCTAssertEqual(measurement?.muscularMassKg, 41.2)
        XCTAssertEqual(measurement?.source, .bia)

        // Valida aplicação a UserProfile
        var profile = UserProfile(
            name: "Novo",
            birthDate: Date(),
            sex: .female,
            heightCm: 160.0,
            currentWeightKg: 60.0,
            activityLevel: .sedentary,
            goal: .maintenance
        )
        parsed.applyTo(profile: &profile)
        XCTAssertEqual(profile.name, "Carlos Eduardo da Silva")
        XCTAssertEqual(profile.sex, .male)
        XCTAssertEqual(profile.heightCm, 182.0)
        XCTAssertEqual(profile.currentWeightKg, 84.5)
    }

    func testTanitaReportWithMetersAndCommaDecimals() {
        let tanitaReportText = """
        TANITA MC-780
        Avaliação de Composição Corporal
        Paciente: Fernanda Lima
        Sexo: Feminino
        Data Nasc: 12/03/1995
        Estatura: 1,68 m
        Peso Corporal: 61,2 kg
        %GC: 22,4%
        Massa Magra: 47,5 kg
        Massa Muscular: 44,8 kg
        Água Corporal: 56,8%
        Gordura Visceral: 3
        TMB: 1395 kcal
        """

        let parsed = BioimpedancePDFParser.parse(text: tanitaReportText)

        XCTAssertEqual(parsed.detectedEquipmentOrClinic, "TANITA MC-780")
        XCTAssertEqual(parsed.name, "Fernanda Lima")
        XCTAssertEqual(parsed.sex, .female)
        XCTAssertEqual(parsed.heightCm, 168.0) // 1.68m convertido para 168cm
        XCTAssertEqual(parsed.weightKg, 61.2)
        XCTAssertEqual(parsed.bodyFatPercentage, 22.4)
        XCTAssertEqual(parsed.leanMassKg, 47.5)
        XCTAssertEqual(parsed.muscleMassKg, 44.8)
        XCTAssertEqual(parsed.bodyWaterLitersOrPercentage, 56.8)
        XCTAssertEqual(parsed.visceralFatLevel, 3)
        XCTAssertEqual(parsed.basalMetabolicRateKcal, 1395.0)

        // Valida parsing correto da data de nascimento
        let calendar = Calendar.current
        XCTAssertNotNil(parsed.birthDate)
        if let birthDate = parsed.birthDate {
            XCTAssertEqual(calendar.component(.day, from: birthDate), 12)
            XCTAssertEqual(calendar.component(.month, from: birthDate), 3)
            XCTAssertEqual(calendar.component(.year, from: birthDate), 1995)
        }
    }

    func testAvanutriClinicalReportParsing() {
        let avanutriReportText = """
        Laudo Clínico de Bioimpedância Avanutri Bio
        Nome do Paciente: Roberto Gomes
        D.N.: 05/11/1988
        Sexo: M
        Altura: 175cm
        Massa Corporal: 76.8kg
        Percentual de Gordura: 18.2%
        Massa Livre de Gordura: 62.8 kg
        ACT: 46.0 L
        Gordura Visceral (Nível): 6
        Taxa Metabólica Basal: 1750 kcal
        """

        let parsed = BioimpedancePDFParser.parse(text: avanutriReportText)

        XCTAssertEqual(parsed.detectedEquipmentOrClinic, "Avanutri Bio")
        XCTAssertEqual(parsed.name, "Roberto Gomes")
        XCTAssertEqual(parsed.sex, .male)
        XCTAssertEqual(parsed.heightCm, 175.0)
        XCTAssertEqual(parsed.weightKg, 76.8)
        XCTAssertEqual(parsed.bodyFatPercentage, 18.2)
        XCTAssertEqual(parsed.leanMassKg, 62.8)
        XCTAssertEqual(parsed.bodyWaterLitersOrPercentage, 46.0)
        XCTAssertEqual(parsed.visceralFatLevel, 6)
        XCTAssertEqual(parsed.basalMetabolicRateKcal, 1750.0)
    }

    func testSecaReportEnglishStyleLabels() {
        let secaReportText = """
        seca mBCA 515
        Medical Body Composition Analyzer
        Name: Lucas Mendes
        Gender: Masc
        Age: 27
        Height: 180 cm
        Weight: 80.0 kg
        Body Fat: 14.5%
        Fat Free Mass: 68.4 kg
        Skeletal Muscle Mass: 38.0 kg
        Total Body Water: 50.1 L
        Visceral Fat: 4
        BMR: 1860 kcal
        """

        let parsed = BioimpedancePDFParser.parse(text: secaReportText)

        XCTAssertEqual(parsed.detectedEquipmentOrClinic, "seca mBCA 515")
        XCTAssertEqual(parsed.name, "Lucas Mendes")
        XCTAssertEqual(parsed.sex, .male)
        XCTAssertEqual(parsed.heightCm, 180.0)
        XCTAssertEqual(parsed.weightKg, 80.0)
        XCTAssertEqual(parsed.bodyFatPercentage, 14.5)
        XCTAssertEqual(parsed.leanMassKg, 68.4)
        XCTAssertEqual(parsed.muscleMassKg, 38.0)
        XCTAssertEqual(parsed.bodyWaterLitersOrPercentage, 50.1)
        XCTAssertEqual(parsed.visceralFatLevel, 4)
        XCTAssertEqual(parsed.basalMetabolicRateKcal, 1860.0)
    }

    func testCrossConsistencyInfersLeanMassWhenMissing() {
        let partialText = """
        Peso: 80.0 kg
        Percentual de Gordura: 20.0%
        """

        let parsed = BioimpedancePDFParser.parse(text: partialText)

        XCTAssertEqual(parsed.weightKg, 80.0)
        XCTAssertEqual(parsed.bodyFatPercentage, 20.0)
        // 80.0 * (1 - 0.20) = 64.0 kg
        XCTAssertEqual(parsed.leanMassKg, 64.0)
    }

    func testEmptyTextDoesNotCrash() {
        let parsed = BioimpedancePDFParser.parse(text: "")
        XCTAssertNil(parsed.name)
        XCTAssertNil(parsed.weightKg)
        XCTAssertNil(parsed.toBodyMeasurement())
    }

    #if canImport(PDFKit)
    func testPDFDataParsing() throws {
        // Valida que dados vazios ou corrompidos não causam crash e retornam estrutura nula
        let emptyData = Data()
        let parsedEmpty = BioimpedancePDFParser.parse(pdfData: emptyData)
        XCTAssertNil(parsedEmpty.name)
        XCTAssertNil(parsedEmpty.weightKg)

        // Valida que URL inexistente retorna de forma segura sem falhas
        let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).pdf")
        let parsedMissing = BioimpedancePDFParser.parse(pdfURL: dummyURL)
        XCTAssertNil(parsedMissing.name)
        XCTAssertNil(parsedMissing.weightKg)
    }
    #endif

    // MARK: - Testes de Katch-McArdle em NutritionCalculator

    func testKatchMcArdleBMRCalculation() {
        // TMB = 370 + (21.6 * leanMassKg)
        // Exemplo: 65 kg de massa magra -> 370 + (21.6 * 65) = 370 + 1404 = 1774 kcal
        let bmrDirect = NutritionCalculator.calculateBMRKatchMcArdle(leanMassKg: 65.0)
        XCTAssertEqual(bmrDirect, 1774.0)

        // Exemplo a partir de peso total de 80kg e 18.75% de gordura -> 80 * (1 - 0.1875) = 65kg magra
        let bmrFromPercent = NutritionCalculator.calculateBMRKatchMcArdle(weightKg: 80.0, bodyFatPercentage: 18.75)
        XCTAssertEqual(bmrFromPercent, 1774.0)
    }

    func testFullTargetWithKatchMcArdleBioimpedance() {
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -28, to: Date())!

        let profile = UserProfile(
            name: "Atleta Bio",
            birthDate: birthDate,
            sex: .male,
            heightCm: 180,
            currentWeightKg: 80,
            activityLevel: .moderate,
            goal: .muscleGain
        )

        // 1. Sem dados de bioimpedância -> Usa Mifflin-St Jeor por padrão
        let mifflinResult = NutritionCalculator.calculateFullTarget(from: profile)
        XCTAssertEqual(mifflinResult.formulaUsed, "Mifflin-St Jeor")

        // 2. Com Massa Magra conhecida (ex: 68 kg via InBody) -> Usa Katch-McArdle
        let katchResult = NutritionCalculator.calculateFullTarget(from: profile, leanMassKg: 68.0)
        XCTAssertEqual(katchResult.formulaUsed, "Katch-McArdle (Bioimpedância)")
        // Katch BMR: 370 + (21.6 * 68) = 370 + 1468.8 = 1839 kcal
        XCTAssertEqual(katchResult.bmr, 1839.0, accuracy: 2.0)
        XCTAssertGreaterThan(katchResult.targetCalories, 0)

        // 3. Com % de Gordura conhecido (ex: 15% via bioimpedância)
        let katchFromBf = NutritionCalculator.calculateFullTarget(from: profile, bodyFatPercentage: 15.0)
        XCTAssertEqual(katchFromBf.formulaUsed, "Katch-McArdle (Bioimpedância)")
        // Lean mass = 80 * 0.85 = 68 kg
        XCTAssertEqual(katchFromBf.bmr, 1839.0, accuracy: 2.0)
    }
}
