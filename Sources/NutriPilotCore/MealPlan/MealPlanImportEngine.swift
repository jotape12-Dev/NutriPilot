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

    private static func splitIntoMealSections(text: String) -> [RawMealSection] {
        let lines = text.components(separatedBy: .newlines)
        var sections: [(mealType: MealType, name: String, suggestedTime: String, startIndex: Int)] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let detected = detectMealHeader(line: trimmed) {
                sections.append((detected.mealType, detected.name, detected.suggestedTime, index))
            }
        }

        guard !sections.isEmpty else { return [] }

        var result: [RawMealSection] = []

        for i in 0..<sections.count {
            let current = sections[i]
            let nextIndex = (i + 1 < sections.count) ? sections[i + 1].startIndex : lines.count

            let contentLines = lines[(current.startIndex + 1)..<nextIndex]
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

    private static func detectMealHeader(line: String) -> (mealType: MealType, name: String, suggestedTime: String)? {
        let lower = line.lowercased()

        // 1. Refeições Nominais Específicas (Prioridade Máxima sobre números genéricos)
        if matches(pattern: #"(?:caf[eé]\s*da\s*manh[aã]|desjejum)"#, in: lower) {
            let time = extractTime(from: line) ?? "07:30"
            return (.breakfast, "Café da Manhã", time)
        }

        if matches(pattern: #"\b(?:almoço|almoco)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "12:30"
            return (.lunch, "Almoço", time)
        }

        if matches(pattern: #"\b(?:jantar|janta)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "19:30"
            return (.dinner, "Jantar", time)
        }

        if matches(pattern: #"\b(?:ceia|snack\s*noturno)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "22:00"
            return (.supper, "Ceia", time)
        }

        if matches(pattern: #"(?:lanche\s*da\s*manh[aã]|colaç[aã]o)"#, in: lower) {
            let time = extractTime(from: line) ?? "10:00"
            return (.morningSnack, "Lanche da Manhã", time)
        }

        if matches(pattern: #"(?:lanche\s*da\s*tarde|pr[eé]-?treino|p[oó]s-?treino|merenda)"#, in: lower) {
            let time = extractTime(from: line) ?? "16:00"
            return (.afternoonSnack, "Lanche da Tarde", time)
        }

        if matches(pattern: #"\blanche\b"#, in: lower) {
            let time = extractTime(from: line) ?? "16:00"
            return (.afternoonSnack, "Lanche da Tarde", time)
        }

        // 2. Refeições Numeradas Genéricas (Caso o laudo use apenas '1ª Refeição', '2ª Refeição', etc.)
        if matches(pattern: #"\b(?:1[ªaºo]?\s*refeiç[aã]o|refeiç[aã]o\s*1)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "07:30"
            return (.breakfast, "Café da Manhã", time)
        }

        if matches(pattern: #"\b(?:2[ªaºo]?\s*refeiç[aã]o|refeiç[aã]o\s*2)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "10:00"
            return (.morningSnack, "Lanche da Manhã", time)
        }

        if matches(pattern: #"\b(?:3[ªaºo]?\s*refeiç[aã]o|refeiç[aã]o\s*3)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "12:30"
            return (.lunch, "Almoço", time)
        }

        if matches(pattern: #"\b(?:4[ªaºo]?\s*refeiç[aã]o|refeiç[aã]o\s*4)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "16:00"
            return (.afternoonSnack, "Lanche da Tarde", time)
        }

        if matches(pattern: #"\b(?:5[ªaºo]?\s*refeiç[aã]o|refeiç[aã]o\s*5)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "19:30"
            return (.dinner, "Jantar", time)
        }

        if matches(pattern: #"\b(?:6[ªaºo]?\s*refeiç[aã]o|refeiç[aã]o\s*6)\b"#, in: lower) {
            let time = extractTime(from: line) ?? "22:00"
            return (.supper, "Ceia", time)
        }

        return nil
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
        let lines = text.components(separatedBy: .newlines)
        var items: [PlannedMealItem] = []

        for rawLine in lines {
            let clean = rawLine
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-*•·—–"))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !clean.isEmpty else { continue }

            // Ignora notas secundárias ou substituições opcionais
            let lower = clean.lowercased()
            if lower.starts(with: "opção") || lower.starts(with: "obs") || lower.starts(with: "observação") || lower.starts(with: "ou ") {
                continue
            }

            let parsedMeal = MealParserEngine.shared.parse(text: clean)
            for parsedItem in parsedMeal.items {
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

        let amount = parsedItem.calculatedWeightGrams > 0 ? parsedItem.calculatedWeightGrams : parsedItem.detectedQuantity

        return PlannedMealItem(
            food: food,
            amount: amount,
            unit: food.servingUnit,
            portionName: parsedItem.matchedPortion?.name,
            calories: parsedItem.macros.calories,
            proteinGrams: parsedItem.macros.proteinGrams,
            carbsGrams: parsedItem.macros.carbsGrams,
            fatGrams: parsedItem.macros.fatGrams,
            fiberGrams: parsedItem.macros.fiberGrams
        )
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
