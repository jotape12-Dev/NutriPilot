import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Dados Estruturados da Bioimpedância

/// Estrutura contendo todas as variáveis clínicas e biométricas extraídas de um laudo
/// de bioimpedância ou exame antropométrico em PDF.
public struct BioimpedanceParsedData: Codable, Sendable, Equatable {
    public var name: String?
    public var birthDate: Date?
    public var sex: BiologicalSex?
    public var heightCm: Double?
    public var weightKg: Double?
    public var bodyFatPercentage: Double?
    public var leanMassKg: Double?
    public var muscleMassKg: Double?
    public var bodyWaterLitersOrPercentage: Double?
    public var visceralFatLevel: Int?
    public var basalMetabolicRateKcal: Double?
    public var detectedEquipmentOrClinic: String?

    public init(
        name: String? = nil,
        birthDate: Date? = nil,
        sex: BiologicalSex? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        bodyFatPercentage: Double? = nil,
        leanMassKg: Double? = nil,
        muscleMassKg: Double? = nil,
        bodyWaterLitersOrPercentage: Double? = nil,
        visceralFatLevel: Int? = nil,
        basalMetabolicRateKcal: Double? = nil,
        detectedEquipmentOrClinic: String? = nil
    ) {
        self.name = name
        self.birthDate = birthDate
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.leanMassKg = leanMassKg
        self.muscleMassKg = muscleMassKg
        self.bodyWaterLitersOrPercentage = bodyWaterLitersOrPercentage
        self.visceralFatLevel = visceralFatLevel
        self.basalMetabolicRateKcal = basalMetabolicRateKcal
        self.detectedEquipmentOrClinic = detectedEquipmentOrClinic
    }

    /// Converte os dados extraídos em um registro de `BodyMeasurement` para persistência.
    public func toBodyMeasurement(
        date: Date = Date(),
        source: MeasurementSource = .bia
    ) -> BodyMeasurement? {
        guard let weight = weightKg else { return nil }

        let fatMass: Double?
        if let bf = bodyFatPercentage {
            fatMass = (weight * (bf / 100.0)).rounded(to: 2)
        } else if let lean = leanMassKg {
            fatMass = max(0.0, weight - lean).rounded(to: 2)
        } else {
            fatMass = nil
        }

        let leanMass: Double?
        if let lm = leanMassKg {
            leanMass = lm.rounded(to: 2)
        } else if let fm = fatMass {
            leanMass = max(0.0, weight - fm).rounded(to: 2)
        } else {
            leanMass = nil
        }

        return BodyMeasurement(
            measuredAt: date,
            weightKg: weight,
            bodyFatPercent: bodyFatPercentage,
            waterPercent: bodyWaterLitersOrPercentage,
            visceralFatLevel: visceralFatLevel,
            leanMassKg: leanMass,
            fatMassKg: fatMass,
            muscularMassKg: muscleMassKg,
            source: source
        )
    }

    /// Aplica as métricas extraídas a um perfil de usuário existente.
    public func applyTo(profile: inout UserProfile) {
        if let n = name, !n.isEmpty { profile.name = n }
        if let b = birthDate { profile.birthDate = b }
        if let s = sex { profile.sex = s }
        if let h = heightCm, h > 0 { profile.heightCm = h }
        if let w = weightKg, w > 0 { profile.currentWeightKg = w }
    }
}

// MARK: - Motor de Análise e Extração de Laudos PDF

/// Parser inteligente que extrai métricas biométricas e antropométricas de laudos de bioimpedância
/// (InBody, Tanita, Avanutri, Seca, etc.) a partir de PDFs ou strings extraídas.
public enum BioimpedancePDFParser {

    // MARK: - API Pública

    /// Analisa um arquivo PDF localizado na URL especificada.
    public static func parse(pdfURL: URL) -> BioimpedanceParsedData {
        #if canImport(PDFKit)
        guard let document = PDFDocument(url: pdfURL) else {
            return BioimpedanceParsedData()
        }
        return parse(document: document)
        #else
        return BioimpedanceParsedData()
        #endif
    }

    /// Analisa os bytes brutos (Data) de um arquivo PDF.
    public static func parse(pdfData: Data) -> BioimpedanceParsedData {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: pdfData) else {
            return BioimpedanceParsedData()
        }
        return parse(document: document)
        #else
        return BioimpedanceParsedData()
        #endif
    }

    #if canImport(PDFKit)
    /// Analisa um documento PDFKit extraindo o texto de todas as suas páginas.
    public static func parse(document: PDFDocument) -> BioimpedanceParsedData {
        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex), let pageString = page.string {
                fullText.append(pageString)
                fullText.append("\n")
            }
        }
        return parse(text: fullText)
    }
    #endif

    /// Analisa o texto extraído de um laudo de bioimpedância utilizando regex e heurísticas clínicas.
    public static func parse(text: String) -> BioimpedanceParsedData {
        var result = BioimpedanceParsedData()

        // 1. Equipamento / Clínica
        result.detectedEquipmentOrClinic = extractEquipment(from: text)

        // 2. Nome do Paciente
        result.name = extractName(from: text)

        // 3. Sexo Biológico
        result.sex = extractSex(from: text)

        // 4. Data de Nascimento / Idade
        result.birthDate = extractBirthDate(from: text)

        // 5. Altura / Estatura (cm)
        result.heightCm = extractHeight(from: text)

        // 6. Peso / Massa Corporal (kg)
        result.weightKg = extractWeight(from: text)

        // 7. Percentual de Gordura Corporal (%GC / PGC / Body Fat)
        result.bodyFatPercentage = extractBodyFat(from: text)

        // 8. Massa Magra / Livre de Gordura (MLG / FFM)
        result.leanMassKg = extractLeanMass(from: text)

        // 9. Massa Muscular / Esquelética (MME / SMM)
        result.muscleMassKg = extractMuscleMass(from: text)

        // 10. Água Corporal (ACT / TBW)
        result.bodyWaterLitersOrPercentage = extractWater(from: text)

        // 11. Gordura Visceral (Nível 1-59)
        result.visceralFatLevel = extractVisceralFat(from: text)

        // 12. Taxa Metabólica Basal (TMB / BMR)
        result.basalMetabolicRateKcal = extractBMR(from: text)

        // Consistência Cruzada: Se leanMassKg não foi explicitamente impresso, mas temos peso e % gordura
        if result.leanMassKg == nil, let w = result.weightKg, let bf = result.bodyFatPercentage {
            result.leanMassKg = (w * (1.0 - (bf / 100.0))).rounded(to: 1)
        }

        return result
    }

    // MARK: - Extratores Individuais

    private static func extractEquipment(from text: String) -> String? {
        let patterns = [
            #"(?i)\b(InBody\s*(?:770|570|370|270|120|S10)?)\b"#,
            #"(?i)\b(Tanita\s*(?:MC-?\s*780|BC-?\s*545|RD-?\s*953|[A-Z0-9-]+)?)\b"#,
            #"(?i)\b(Avanutri(?:\s*Bio|360)?)\b"#,
            #"(?i)\b(Seca(?:\s*mBCA)?(?:\s*515|525)?)\b"#,
            #"(?i)\b(BOD\s*POD)\b"#,
            #"(?i)\b(Biodynamics)\b"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func extractName(from text: String) -> String? {
        let patterns = [
            #"(?i)(?:Nome(?:\s*do\s*Paciente)?|Paciente|Cliente|Name)\s*[:=\-\t]\s*([A-Za-zÀ-ÖØ-öø-ÿ\s]{3,45})"#,
            #"(?i)ID\s*[:=\-\t]\s*([A-Za-zÀ-ÖØ-öø-ÿ\s]{3,45})"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1) {
                let cleaned = match.components(separatedBy: "\n").first ?? match
                let finalName = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                if finalName.count >= 2 && !finalName.lowercased().contains("idade") && !finalName.lowercased().contains("sexo") {
                    return finalName
                }
            }
        }
        return nil
    }

    private static func extractSex(from text: String) -> BiologicalSex? {
        let patterns = [
            #"(?i)(?:Sexo|G[eê]nero|Gender)\s*[:=\-\t]?\s*(Masc(?:ulino)?|Fem(?:inino)?|[MF])\b"#,
            #"\b(Masculino|Feminino)\b"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1) {
                let lower = match.lowercased()
                if lower.starts(with: "m") {
                    return .male
                } else if lower.starts(with: "f") {
                    return .female
                }
            }
        }
        return nil
    }

    private static func extractBirthDate(from text: String) -> Date? {
        let datePatterns = [
            #"(?:Data\s*(?:de)?\s*Nasc(?:imento)?|D\.?N\.?|Nascimento|Birth\s*Date)\s*[:=\-\t]?\s*(\d{2}[/.-]\d{2}[/.-]\d{4})"#,
            #"(?:Data\s*(?:de)?\s*Nasc(?:imento)?|D\.?N\.?|Nascimento|Birth\s*Date)\s*[:=\-\t]?\s*(\d{4}[/.-]\d{2}[/.-]\d{2})"#
        ]

        let formatters: [DateFormatter] = [
            createFormatter("dd/MM/yyyy"),
            createFormatter("dd-MM-yyyy"),
            createFormatter("dd.MM.yyyy"),
            createFormatter("yyyy-MM-dd")
        ]

        for pattern in datePatterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1) {
                for formatter in formatters {
                    if let date = formatter.date(from: match) {
                        return date
                    }
                }
            }
        }

        // Heurística de fallback: Idade aproximada
        let agePatterns = [
            #"(?i)(?:Idade|Age)\s*[:=\-\t]?\s*(\d{1,3})\s*(?:anos|yo)?"#
        ]
        for pattern in agePatterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let age = Int(match), age >= 10 && age <= 110 {
                return Calendar.current.date(byAdding: .year, value: -age, to: Date())
            }
        }

        return nil
    }

    private static func extractHeight(from text: String) -> Double? {
        let patterns = [
            #"(?:Altura|Estatura|Height|Alt\.?)\s*[:=\-\t]?\s*(\d{1,3}(?:[.,]\d+)?)\s*(?:cm|m)?\b"#,
            #"(\d{3}(?:[.,]\d+)?)\s*cm\b"#,
            #"\b([12][.,]\d{2})\s*m\b"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let value = parseDouble(match) {
                if value >= 1.0 && value <= 2.6 {
                    return (value * 100.0).rounded(to: 1)
                } else if value >= 90.0 && value <= 260.0 {
                    return value.rounded(to: 1)
                }
            }
        }
        return nil
    }

    private static func extractWeight(from text: String) -> Double? {
        let patterns = [
            #"(?:Peso(?:\s*Corporal)?|Massa\s*Corporal|Weight|Peso\s*Atual)\s*[:=\-\t]?\s*(\d{2,3}(?:[.,]\d+)?)\s*(?:kg)?\b"#,
            #"(\d{2,3}(?:[.,]\d+)?)\s*kg\b"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let value = parseDouble(match), value >= 25.0 && value <= 350.0 {
                return value.rounded(to: 1)
            }
        }
        return nil
    }

    private static func extractBodyFat(from text: String) -> Double? {
        let patterns = [
            #"(?:%GC|PGC|Percentual\s*de\s*Gordura(?:\s*Corporal)?|Gordura\s*Corporal|Body\s*Fat|%BF|Taxa\s*de\s*Gordura)(?:\s*\([A-Za-z0-9%]+\))?\s*[:=\-\t]?\s*(\d{1,2}(?:[.,]\d+)?)\s*%?\b"#,
            #"(?:Gordura)\s*[:=\-\t]\s*(\d{1,2}(?:[.,]\d+)?)\s*%"#,
            #"(\d{1,2}(?:[.,]\d+)?)\s*%\s*(?:de\s*)?(?:gordura|gc|pgc|bf)"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let value = parseDouble(match), value >= 3.0 && value <= 65.0 {
                return value.rounded(to: 1)
            }
        }
        return nil
    }

    private static func extractLeanMass(from text: String) -> Double? {
        let patterns = [
            #"(?:Massa\s*(?:Livre\s*de\s*Gordura|Magra)|MLG|FFM|Fat\s*Free\s*Mass|Lean\s*Body\s*Mass|LBM)(?:\s*\([A-Za-z0-9]+\))?\s*[:=\-\t]?\s*(\d{2,3}(?:[.,]\d+)?)\s*(?:kg)?\b"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let value = parseDouble(match), value >= 20.0 && value <= 250.0 {
                return value.rounded(to: 1)
            }
        }
        return nil
    }

    private static func extractMuscleMass(from text: String) -> Double? {
        let patterns = [
            #"(?:Massa\s*de\s*M[uú]sculo\s*Esquel[eé]tico|Massa\s*Muscular(?:\s*Esquel[eé]tica)?|MME|SMM|Skeletal\s*Muscle\s*Mass|Massa\s*Muscular)(?:\s*\([A-Za-z0-9]+\))?\s*[:=\-\t]?\s*(\d{2,3}(?:[.,]\d+)?)\s*(?:kg)?\b"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let value = parseDouble(match), value >= 10.0 && value <= 150.0 {
                return value.rounded(to: 1)
            }
        }
        return nil
    }

    private static func extractWater(from text: String) -> Double? {
        let patterns = [
            #"(?:[AÁ]gua\s*Corporal(?:\s*Total)?|ACT|Total\s*Body\s*Water|TBW)(?:\s*\([A-Za-z0-9]+\))?\s*[:=\-\t]?\s*(\d{2,3}(?:[.,]\d+)?)\s*(?:L|l|kg|%)?\b"#,
            #"(?:[AÁ]gua|Agua)\s*[:=\-\t]\s*(\d{2,3}(?:[.,]\d+)?)\s*(?:L|l|kg|%)"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let value = parseDouble(match), value >= 15.0 && value <= 100.0 {
                return value.rounded(to: 1)
            }
        }
        return nil
    }

    private static func extractVisceralFat(from text: String) -> Int? {
        let patterns = [
            #"(?:N[ií]vel\s*de\s*)?Gordura\s*Visceral(?:\s*\(N[ií]vel\))?\s*[:=\-\t]?\s*(?:N[ií]vel\s*)?(\d{1,2})\b"#,
            #"(?:VFL|Visceral\s*Fat(?:\s*Level)?)\s*[:=\-\t]?\s*(\d{1,2})\b"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let value = Int(match), value >= 1 && value <= 59 {
                return value
            }
        }
        return nil
    }

    private static func extractBMR(from text: String) -> Double? {
        let patterns = [
            #"(?:Taxa\s*Metab[oó]lica\s*Basal|TMB|Metabolismo\s*Basal|Basal\s*Metabolic\s*Rate|BMR)(?:\s*\([A-Za-z0-9]+\))?\s*[:=\-\t]?\s*(\d{3,4}(?:[.,]\d+)?)\s*(?:kcal)?\b"#
        ]

        for pattern in patterns {
            if let match = extractFirstMatch(pattern: pattern, text: text, group: 1),
               let value = parseDouble(match), value >= 700.0 && value <= 5000.0 {
                return value.rounded(to: 1)
            }
        }
        return nil
    }

    // MARK: - Utilitários Auxiliares

    private static func extractFirstMatch(pattern: String, text: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        guard let first = matches.first, group < first.numberOfRanges else {
            return nil
        }
        let range = first.range(at: group)
        guard range.location != NSNotFound else { return nil }
        return nsString.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDouble(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    private static func createFormatter(_ format: String) -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = format
        df.locale = Locale(identifier: "pt_BR")
        df.timeZone = TimeZone.current
        return df
    }
}
