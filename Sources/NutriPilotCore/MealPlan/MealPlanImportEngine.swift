import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

/// Motor de inteligência para importação e parsing de planos alimentares pré-existentes
/// (dietas prescritas por nutricionistas brasileiros em texto, PDF ou WhatsApp).
public enum MealPlanImportEngine {

    // MARK: - API Pública

    /// Importa um plano alimentar completo a partir de texto estruturado ou natural em português.
    public static func importPlan(
        text: String,
        title: String = "Meu Plano Importado"
    ) -> MealPlan {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return makeEmptyPlan()
        }

        let mealSections = splitIntoMealSections(text: cleanText)

        var plannedMeals: [PlannedMeal] = []

        if !mealSections.isEmpty {
            for section in mealSections {
                let items = parseSectionItems(text: section.content)
                if !items.isEmpty {
                    let targetCals = items.reduce(0.0) { $0 + $1.calories }.rounded(to: 1)
                    let plannedMeal = PlannedMeal(
                        mealType: section.mealType,
                        name: section.name,
                        suggestedTime: section.suggestedTime,
                        targetCalories: targetCals,
                        items: items
                    )
                    plannedMeals.append(plannedMeal)
                }
            }
        }

        // Se nenhuma seção específica de refeição for rotulada, agrupa todos os alimentos encontrados
        if plannedMeals.isEmpty {
            let items = parseSectionItems(text: cleanText)
            if !items.isEmpty {
                let targetCals = items.reduce(0.0) { $0 + $1.calories }.rounded(to: 1)
                let defaultMeal = PlannedMeal(
                    mealType: .lunch,
                    name: "Refeição Principal",
                    suggestedTime: "12:30",
                    targetCalories: targetCals,
                    items: items
                )
                plannedMeals.append(defaultMeal)
            }
        }

        guard !plannedMeals.isEmpty else {
            return makeEmptyPlan()
        }

        let totalCals = plannedMeals.reduce(0.0) { $0 + $1.totalCalories }.rounded(to: 1)
        let totalProt = plannedMeals.reduce(0.0) { $0 + $1.totalProtein }.rounded(to: 1)
        let totalCarbs = plannedMeals.reduce(0.0) { $0 + $1.totalCarbs }.rounded(to: 1)
        let totalFat = plannedMeals.reduce(0.0) { $0 + $1.totalFat }.rounded(to: 1)
        let totalFiber = plannedMeals.reduce(0.0) { $0 + $1.totalFiber }.rounded(to: 1)

        return DailyMealPlan(
            id: UUID(),
            createdAt: Date(),
            targetCalories: totalCals,
            targetProteinGrams: totalProt,
            targetCarbsGrams: totalCarbs,
            targetFatGrams: totalFat,
            targetFiberGrams: totalFiber,
            meals: plannedMeals
        )
    }

    /// Importa um plano alimentar extraindo o texto de todas as páginas de um PDF de laudo nutricional.
    public static func importPlan(
        pdfData: Data,
        title: String = "Meu Plano Importado"
    ) -> MealPlan {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: pdfData) else {
            return makeEmptyPlan()
        }
        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex), let pageString = page.string {
                fullText.append(pageString)
                fullText.append("\n")
            }
        }
        return importPlan(text: fullText, title: title)
        #else
        return makeEmptyPlan()
        #endif
    }

    // MARK: - Segmentação de Refeições

    private struct RawMealSection {
        let mealType: MealType
        let name: String
        let suggestedTime: String
        let content: String
    }

    private struct DetectedHeader {
        let mealType: MealType
        let name: String
        let suggestedTime: String
        let inlineContent: String?
    }

    private static func splitIntoMealSections(text: String) -> [RawMealSection] {
        let lines = text.components(separatedBy: .newlines)
        var sections: [(mealType: MealType, name: String, suggestedTime: String, startIndex: Int, inlineContent: String?)] = []
        var terminationIndex: Int? = nil

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Se já encontramos ao menos 1 refeição e chegamos a seções de encerramento / tabelas / preparo semanal, encerra!
            if !sections.isEmpty && isMealListTerminationLine(trimmed) {
                terminationIndex = index
                break
            }

            if let detected = detectMealHeader(line: trimmed) {
                sections.append((detected.mealType, detected.name, detected.suggestedTime, index, detected.inlineContent))
            }
        }

        guard !sections.isEmpty else { return [] }

        var result: [RawMealSection] = []

        for i in 0..<sections.count {
            let current = sections[i]
            let nextIndex = (i + 1 < sections.count) ? sections[i + 1].startIndex : (terminationIndex ?? lines.count)

            var contentLines: [String] = []
            if let inline = current.inlineContent, !inline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contentLines.append(inline)
            }
            if current.startIndex + 1 < nextIndex {
                contentLines.append(contentsOf: lines[(current.startIndex + 1)..<nextIndex])
            }

            let contentText = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            result.append(
                RawMealSection(
                    mealType: current.mealType,
                    name: current.name,
                    suggestedTime: current.suggestedTime,
                    content: contentText
                )
            )
        }

        return result
    }

    private static func isMealListTerminationLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        let patterns = [
            #"calorias\s*e\s*macros"#,
            #"macros\s*por\s*refeiç[aã]o"#,
            #"resumo\s*nutricional"#,
            #"tabela\s*nutricional"#,
            #"totais\s*(?:da\s*dieta|nutricionais|desta\s*tabela)?"#,
            #"preparo\s*das\s*(?:tr[eê]s\s*)?marmitas"#,
            #"preparo\s*semanal"#,
            #"para\s*\d+\s*dias"#,
            #"acompanhamento\s*e\s*limites"#,
            #"orientaç[oõ]es\s*gerais"#,
            #"recomendaç[oõ]es"#,
            #"observaç[oõ]es\s*finais"#,
            #"material\s*educativo"#,
            #"d[eé]ficit\s*estimado"#,
            #"relaç[aã]o\s*com\s*o\s*peso"#,
            #"prescriç[aã]o\s*v[aá]lida\s*at[eé]"#,
            #"assinatura"#
        ]
        for pattern in patterns {
            if matches(pattern: pattern, in: lower) {
                return true
            }
        }
        return false
    }

    private static func detectMealHeader(line: String) -> DetectedHeader? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        let startsWithTime = matches(pattern: #"^\d{1,2}[:hH]\d{2}"#, in: trimmed)
        let startsWithMealNum = matches(pattern: #"^(?:\d+[ªaºo]?\s*refeiç[aã]o|refeiç[aã]o\s*\d+)"#, in: lower)

        // Linha longa sem prefixo de hora ou número de refeição provavelmente é prosa narrativa
        if !startsWithTime && !startsWithMealNum && trimmed.count > 60 {
            return nil
        }

        // Linhas sem horário que terminam com ponto final '.' e não contêm alimentos inline (';' ou '+') são sentenças, não cabeçalhos
        if !startsWithTime && !startsWithMealNum && trimmed.hasSuffix(".") && !trimmed.contains(";") && !trimmed.contains("+") && !trimmed.contains(":") {
            return nil
        }

        // Caso 1: Começa com horário (Ex: "08h00 — Café da manhã 2 ovos inteiros...", "12:30 - Almoço")
        if startsWithTime {
            if let timeMatch = firstMatch(pattern: #"^(\d{1,2})[:hH](\d{2})\s*(?:[—–-]|:|\s)\s*(.*)$"#, in: trimmed) {
                let hour = Int(timeMatch.0) ?? 0
                let min = Int(timeMatch.1) ?? 0
                let formattedTime = String(format: "%02d:%02d", hour, min)
                let remainder = timeMatch.2.trimmingCharacters(in: .whitespacesAndNewlines)

                if let identified = identifyMealInText(remainder, fallbackTime: formattedTime) {
                    return identified
                }
            }
        }

        // Caso 2: Começa com número da refeição (Ex: "1ª Refeição - Café da Manhã (07:30)", "Refeição 2:")
        if startsWithMealNum {
            if let numMatch = firstMatch(pattern: #"^(?:(\d+)[ªaºo]?\s*refeiç[aã]o|refeiç[aã]o\s*(\d+))\b(?:\s*[-—–:]\s*|\s*)(.*)$"#, in: lower) {
                let numStr = !numMatch.0.isEmpty ? numMatch.0 : numMatch.1
                let mealNum = Int(numStr) ?? 1
                let remainder = (trimmed as NSString).substring(from: (trimmed as NSString).length - (numMatch.2 as NSString).length)
                let time = extractTime(from: trimmed) ?? defaultTimeForMealNumber(mealNum)

                if let identified = identifyMealInText(remainder, fallbackTime: time) {
                    return identified
                } else {
                    let defaultType = defaultMealTypeForNumber(mealNum)
                    let defaultName = "\(mealNum)ª Refeição"
                    return DetectedHeader(mealType: defaultType, name: defaultName, suggestedTime: time, inlineContent: remainder.isEmpty ? nil : remainder)
                }
            }
        }

        // Caso 3: Começa diretamente pelo nome da refeição (Ex: "Café da manhã (08:00):", "Almoço:", "Jantar Igual ao almoço:")
        let time = extractTime(from: trimmed) ?? "12:30"
        if let identified = identifyMealInText(trimmed, fallbackTime: time) {
            return identified
        }

        return nil
    }

    private static func identifyMealInText(_ text: String, fallbackTime: String) -> DetectedHeader? {
        struct MealPattern {
            let pattern: String
            let mealType: MealType
            let name: String
            let defaultTime: String
        }

        let mealPatterns: [MealPattern] = [
            MealPattern(pattern: #"\b(?:caf[eé]\s*da\s*manh[aã]|desjejum)\b"#, mealType: .breakfast, name: "Café da Manhã", defaultTime: "07:30"),
            MealPattern(pattern: #"\b(?:almoço|almoco)\b"#, mealType: .lunch, name: "Almoço", defaultTime: "12:30"),
            MealPattern(pattern: #"\b(?:jantar|janta)\b"#, mealType: .dinner, name: "Jantar", defaultTime: "19:30"),
            MealPattern(pattern: #"\b(?:ceia|snack\s*noturno)\b"#, mealType: .supper, name: "Ceia", defaultTime: "22:00"),
            MealPattern(pattern: #"\b(?:lanche\s*da\s*manh[aã]|colaç[aã]o)\b"#, mealType: .morningSnack, name: "Lanche da Manhã", defaultTime: "10:00"),
            MealPattern(pattern: #"\b(?:antes\s*do\s*treino|pr[eé]-?treino)\b"#, mealType: .afternoonSnack, name: "Pré-Treino", defaultTime: "18:00"),
            MealPattern(pattern: #"\bp[oó]s-?treino\b"#, mealType: .afternoonSnack, name: "Pós-Treino", defaultTime: "20:00"),
            MealPattern(pattern: #"\blanche\s*da\s*tarde\b"#, mealType: .afternoonSnack, name: "Lanche da Tarde", defaultTime: "16:00"),
            MealPattern(pattern: #"\blanche\b"#, mealType: .afternoonSnack, name: "Lanche", defaultTime: "16:00")
        ]

        for mp in mealPatterns {
            guard let regex = try? NSRegularExpression(pattern: mp.pattern, options: [.caseInsensitive]) else { continue }
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                if match.range.location <= 4 {
                    let endOfMatch = match.range.location + match.range.length
                    var remainder = nsText.substring(from: endOfMatch)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "-—–:"))
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if let parenTime = extractTime(from: remainder) {
                        remainder = remainder.replacingOccurrences(of: "(\(parenTime))", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "-—–:"))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    let lowerRem = remainder.lowercased()
                    let prosePrefixes = ["e ", "ou ", "de ", "em ", "para ", "com ", "no ", "na "]
                    for pp in prosePrefixes {
                        if lowerRem.starts(with: pp) {
                            return nil
                        }
                    }

                    let chosenTime = (fallbackTime != "12:30" && fallbackTime != "07:30") ? fallbackTime : mp.defaultTime
                    let finalInline = remainder.isEmpty ? nil : remainder
                    return DetectedHeader(mealType: mp.mealType, name: mp.name, suggestedTime: chosenTime, inlineContent: finalInline)
                }
            }
        }

        return nil
    }

    private static func defaultTimeForMealNumber(_ num: Int) -> String {
        switch num {
        case 1: return "07:30"
        case 2: return "10:00"
        case 3: return "12:30"
        case 4: return "16:00"
        case 5: return "19:30"
        case 6: return "22:00"
        default: return "12:00"
        }
    }

    private static func defaultMealTypeForNumber(_ num: Int) -> MealType {
        switch num {
        case 1: return .breakfast
        case 2: return .morningSnack
        case 3: return .lunch
        case 4: return .afternoonSnack
        case 5: return .dinner
        case 6: return .supper
        default: return .lunch
        }
    }

    private static func firstMatch(pattern: String, in text: String) -> (String, String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let g1 = match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound ? ns.substring(with: match.range(at: 1)) : ""
        let g2 = match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound ? ns.substring(with: match.range(at: 2)) : ""
        let g3 = match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)) : ""
        return (g1, g2, g3)
    }

    private static func extractTime(from line: String) -> String? {
        let pattern = #"(\d{1,2})[:hH](\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = line as NSString
        guard let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let h = ns.substring(with: match.range(at: 1))
        let m = ns.substring(with: match.range(at: 2))
        let hour = Int(h) ?? 0
        let min = Int(m) ?? 0
        return String(format: "%02d:%02d", hour, min)
    }

    // MARK: - Parsing de Alimentos da Refeição

    private static func parseSectionItems(text: String) -> [PlannedMealItem] {
        let rawLines = text.components(separatedBy: .newlines)
        var mergedLines: [String] = []

        // 1. Reconstrução de quebras de linha acidentais de PDFs (ex: "... e 15 g de" + "azeite.")
        var buffer = ""
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if buffer.isEmpty {
                buffer = trimmed
            } else {
                let lowerBuf = buffer.lowercased()
                if lowerBuf.hasSuffix(" de") || lowerBuf.hasSuffix(" com") || lowerBuf.hasSuffix(" e") || lowerBuf.hasSuffix(" sem") || lowerBuf.hasSuffix(",") {
                    buffer += " " + trimmed
                } else {
                    mergedLines.append(buffer)
                    buffer = trimmed
                }
            }
        }
        if !buffer.isEmpty {
            mergedLines.append(buffer)
        }

        var items: [PlannedMealItem] = []

        for rawLine in mergedLines {
            var clean = rawLine
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-*•·—–"))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !clean.isEmpty else { continue }

            let lower = clean.lowercased()
            if lower.starts(with: "opção") || lower.starts(with: "obs") || lower.starts(with: "observação") || lower.starts(with: "ou ") {
                continue
            }
            if lower.contains("kcal") && (lower.contains("proteína") || lower.contains("carboidratos") || lower.contains("gordura")) {
                continue
            }
            if lower.starts(with: "refeição ") || lower.starts(with: "total ") || lower.starts(with: "valores estimados") {
                continue
            }

            let referencePrefixes = [
                "igual ao almoço:", "igual ao almoco:", "igual ao almoço", "igual ao almoco",
                "mesmo que o almoço:", "mesmo que o almoço",
                "igual ao jantar:", "igual ao jantar"
            ]
            for prefix in referencePrefixes {
                if lower.starts(with: prefix) {
                    clean = String(clean.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }

            // Remove notas explicativas de modo de preparo ou restrições (ex: ", incluindo o preparo", "sem adição de azeite prevista")
            let notesToRemove = [
                #",\s*incluindo\s*(?:o\s*)?(?:preparo|[oó]leo).*"#,
                #"sem\s*adi[cç][aã]o\s*de\s*.*"#,
                #"\bconforme\s*prefer[eê]ncia\b"#,
                #"\bà\s*vontade\b"#,
                #"\bse\s*necess[aá]rio\b"#,
                #"\bopcional\b"#,
                #"\([^\)]*parte\s*comest[ií]vel[^\)]*\)"#,
                #"\([^\)]*pesad[oa]s?\s*crus?[^\)]*\)"#
            ]
            for pattern in notesToRemove {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: (clean as NSString).length), withTemplate: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            guard !clean.isEmpty else { continue }

            let parsedMeal = MealParserEngine.shared.parse(text: clean)
            for parsedItem in parsedMeal.items {
                if parsedItem.macros.calories > 4000.0 {
                    continue
                }
                let plannedItem = toPlannedMealItem(parsedItem)
                items.append(plannedItem)
            }
        }

        return items
    }

    private static func toPlannedMealItem(_ parsedItem: ParsedMealItem) -> PlannedMealItem {
        let food: FoodItem
        if let itemFood = parsedItem.food {
            food = itemFood
        } else {
            food = FoodItem(
                id: UUID(),
                name: parsedItem.rawText,
                servingSize: parsedItem.calculatedWeightGrams > 0 ? parsedItem.calculatedWeightGrams : 100.0,
                servingUnit: parsedItem.detectedUnit.isEmpty ? "g" : parsedItem.detectedUnit,
                calories: parsedItem.macros.calories,
                proteinGrams: parsedItem.macros.proteinGrams,
                carbsGrams: parsedItem.macros.carbsGrams,
                fatGrams: parsedItem.macros.fatGrams,
                fiberGrams: parsedItem.macros.fiberGrams,
                source: "Importado"
            )
        }

        // Determina a gramatura precisa com base na TBCA ou referenceUnitPortion
        var amount = parsedItem.calculatedWeightGrams > 0 ? parsedItem.calculatedWeightGrams : parsedItem.detectedQuantity
        if amount <= 0 || (parsedItem.calculatedWeightGrams <= 0 && parsedItem.detectedQuantity > 0) {
            if let ref = food.referenceUnitPortion, parsedItem.detectedQuantity > 0 {
                amount = parsedItem.detectedQuantity * ref.gramWeight
            } else if amount <= 0 {
                amount = food.servingSize
            }
        }

        let portionName = resolvePreservedPortionName(
            rawText: parsedItem.rawText,
            quantity: parsedItem.detectedQuantity,
            unit: parsedItem.detectedUnit,
            matchedPortion: parsedItem.matchedPortion,
            food: food
        )

        let calc = food.calculatedFor(amount: amount)

        return PlannedMealItem(
            food: food,
            amount: amount,
            unit: food.servingUnit,
            portionName: portionName,
            calories: calc.calories,
            proteinGrams: calc.protein,
            carbsGrams: calc.carbs,
            fatGrams: calc.fat,
            fiberGrams: calc.fiber
        )
    }

    private static func resolvePreservedPortionName(
        rawText: String,
        quantity: Double,
        unit: String,
        matchedPortion: FoodPortion?,
        food: FoodItem
    ) -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Tenta extrair do início do texto a porção prescrita exata (ex: "2 unidades", "2 ovos", "2 fatias", "3 claras", "1 filé", "2 colheres")
        let pattern = "^(\\d+(?:[.,]\\d+)?)\\s*(unidades?|ovos?|claras?|fatias?|fil[eé]s?|bifes?|postas?|colher(?:es)?(?:\\s+de\\s+[a-zA-Záàâãéèêíïóôõöúçñ]+)?|x[ií]caras?(?:\\s+de\\s+[a-zA-Záàâãéèêíïóôõöúçñ]+)?|copos?|conchas?|scoops?|latas?|potes?|discos?)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) {
            let fullMatch = (trimmed as NSString).substring(with: match.range(at: 0))
            return fullMatch.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. Se a unidade detectada for não-métrica (não é "g" nem "ml")
        let normUnit = unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normUnit.isEmpty && normUnit != "g" && normUnit != "grama" && normUnit != "gramas" && normUnit != "ml" {
            let q = quantity > 0 ? quantity : 1.0
            let qStr = q == floor(q) ? "\(Int(q))" : String(format: "%.1f", q)
            let unitDisplay: String
            if normUnit.contains("unidade") || normUnit == "un" || normUnit == "und" {
                let isEgg = food.name.localizedCaseInsensitiveContains("ovo") && !food.name.localizedCaseInsensitiveContains("clara")
                if isEgg {
                    unitDisplay = q > 1.05 ? "ovos" : "ovo"
                } else {
                    unitDisplay = q > 1.05 ? "unidades" : "unidade"
                }
            } else if normUnit.contains("fatia") {
                unitDisplay = q > 1.05 ? "fatias" : "fatia"
            } else if normUnit.contains("ovo") {
                unitDisplay = q > 1.05 ? "ovos" : "ovo"
            } else if normUnit.contains("clara") {
                unitDisplay = q > 1.05 ? "claras" : "clara"
            } else {
                unitDisplay = unit
            }
            return "\(qStr) \(unitDisplay)"
        }

        // 3. Fallback para porção casada (se não for métrica)
        if let mp = matchedPortion, !mp.name.lowercased().contains("grama") && !mp.name.lowercased().contains("100g") {
            return mp.name
        }

        return nil
    }

    private static func matches(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let ns = text as NSString
        return regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) != nil
    }

    private static func makeEmptyPlan() -> MealPlan {
        DailyMealPlan(
            id: UUID(),
            createdAt: Date(),
            targetCalories: 0,
            targetProteinGrams: 0,
            targetCarbsGrams: 0,
            targetFatGrams: 0,
            targetFiberGrams: 0,
            meals: []
        )
    }
}
