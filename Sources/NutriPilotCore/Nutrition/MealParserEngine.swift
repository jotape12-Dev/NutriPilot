import Foundation

/// Nível de precisão e confiabilidade do reconhecimento do alimento e porção.
public enum ParseConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
}

/// Representa um item individual decomposto de uma frase em linguagem natural.
public struct ParsedMealItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var rawText: String
    public var food: FoodItem?
    public var matchedPortion: FoodPortion?
    public var detectedQuantity: Double
    public var detectedUnit: String
    public var calculatedWeightGrams: Double
    public var macros: MacroBreakdown
    public var confidence: ParseConfidence

    public init(
        id: UUID = UUID(),
        rawText: String,
        food: FoodItem?,
        matchedPortion: FoodPortion? = nil,
        detectedQuantity: Double,
        detectedUnit: String,
        calculatedWeightGrams: Double,
        macros: MacroBreakdown,
        confidence: ParseConfidence
    ) {
        self.id = id
        self.rawText = rawText
        self.food = food
        self.matchedPortion = matchedPortion
        self.detectedQuantity = detectedQuantity
        self.detectedUnit = detectedUnit
        self.calculatedWeightGrams = calculatedWeightGrams
        self.macros = macros
        self.confidence = confidence
    }

    /// Converte o item decomposto em um MealLogItem pronto para ser salvo em MealStore.
    public func toMealLogItem() -> MealLogItem {
        let displayName: String
        if let portion = matchedPortion {
            if detectedQuantity == 1.0 {
                displayName = "\(food?.name ?? rawText) (\(portion.name))"
            } else {
                let qtyFormatted = detectedQuantity.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(detectedQuantity))"
                    : String(format: "%.1f", detectedQuantity)
                displayName = "\(food?.name ?? rawText) (\(qtyFormatted)x \(portion.name))"
            }
        } else if let food = food {
            displayName = food.name
        } else {
            displayName = rawText
        }

        return MealLogItem(
            foodId: food?.id,
            name: displayName,
            quantity: calculatedWeightGrams,
            unit: food?.servingUnit ?? detectedUnit,
            calories: macros.calories,
            proteinGrams: macros.proteinGrams,
            carbsGrams: macros.carbsGrams,
            fatGrams: macros.fatGrams,
            fiberGrams: macros.fiberGrams
        )
    }
}

/// Refeição completa decomposta de uma sentença ou texto digitado/falado pelo usuário.
public struct ParsedMeal: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var rawInput: String
    public var items: [ParsedMealItem]
    public var totalCalories: Double
    public var totalProteinGrams: Double
    public var totalCarbsGrams: Double
    public var totalFatGrams: Double
    public var totalFiberGrams: Double
    public var overallConfidence: ParseConfidence

    public init(
        id: UUID = UUID(),
        rawInput: String,
        items: [ParsedMealItem]
    ) {
        self.id = id
        self.rawInput = rawInput
        self.items = items
        self.totalCalories = items.reduce(0.0) { $0 + $1.macros.calories }.rounded(to: 1)
        self.totalProteinGrams = items.reduce(0.0) { $0 + $1.macros.proteinGrams }.rounded(to: 1)
        self.totalCarbsGrams = items.reduce(0.0) { $0 + $1.macros.carbsGrams }.rounded(to: 1)
        self.totalFatGrams = items.reduce(0.0) { $0 + $1.macros.fatGrams }.rounded(to: 1)
        self.totalFiberGrams = items.reduce(0.0) { $0 + $1.macros.fiberGrams }.rounded(to: 1)

        if items.isEmpty {
            self.overallConfidence = .low
        } else if items.allSatisfy({ $0.confidence == .high }) {
            self.overallConfidence = .high
        } else if items.contains(where: { $0.confidence == .low }) {
            self.overallConfidence = .low
        } else {
            self.overallConfidence = .medium
        }
    }

    /// Converte a refeição parseada em MealLog diretamente utilizável pela aplicação.
    public func toMealLog(
        mealType: MealType = .lunch,
        date: Date = Date(),
        inputMethod: InputMethod = .quickText
    ) -> MealLog {
        let confidenceScore: Double
        switch overallConfidence {
        case .high: confidenceScore = 1.0
        case .medium: confidenceScore = 0.75
        case .low: confidenceScore = 0.4
        }

        return MealLog(
            date: date,
            mealType: mealType,
            loggedAt: Date(),
            inputMethod: inputMethod,
            rawInput: rawInput,
            confidence: confidenceScore,
            items: items.map { $0.toMealLogItem() },
            confirmedByUser: overallConfidence == .high
        )
    }
}

/// Motor de processamento de linguagem natural em português (NLP) para decomposição instantânea de refeições.
/// Reconhece separadores compostos, quantificadores numéricos e por extenso, medidas caseiras e mapeia para a TBCA.
public final class MealParserEngine: Sendable {
    public static let shared = MealParserEngine()

    public let searchEngine: FoodSearchEngine

    public init(searchEngine: FoodSearchEngine = .shared) {
        self.searchEngine = searchEngine
    }

    // MARK: - API Principal

    /// Analisa uma frase com uma ou mais comidas e devolve uma `ParsedMeal` com macronutrientes calculados.
    public func parse(text: String) -> ParsedMeal {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return ParsedMeal(rawInput: text, items: [])
        }

        let itemFragments = splitIntoItemFragments(text: cleanText)
        let parsedItems = itemFragments.compactMap { parseItem(fragment: $0) }

        return ParsedMeal(rawInput: text, items: parsedItems)
    }

    // MARK: - Divisão de Frases em Itens

    /// Divide o texto em fragmentos individuais respeitando separadores clássicos do português brasileiro.
    private func splitIntoItemFragments(text: String) -> [String] {
        // Protege números compostos com 'e' (ex: "uma e meia", "dois e meio") e modificadores legítimos
        let preparedText = text
            .replacingOccurrences(of: " e meio", with: "___e_meio___", options: .caseInsensitive)
            .replacingOccurrences(of: " e meia", with: "___e_meia___", options: .caseInsensitive)
            .replacingOccurrences(of: "com casca", with: "___com_casca___", options: .caseInsensitive)
            .replacingOccurrences(of: "sem casca", with: "___sem_casca___", options: .caseInsensitive)
            .replacingOccurrences(of: "sem açúcar", with: "___sem_acucar___", options: .caseInsensitive)
            .replacingOccurrences(of: "sem acucar", with: "___sem_acucar___", options: .caseInsensitive)

        // Expressão regular de separadores:
        // Vírgulas, ponto e vírgula, quebras de linha, sinal de +, e conjunções " e ", " com ", " mais "
        let pattern = "[,;\n\r+]|\\s+(?:e|com|mais)\\s+"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [text]
        }

        let range = NSRange(location: 0, length: preparedText.utf16.count)
        let modified = regex.stringByReplacingMatches(in: preparedText, options: [], range: range, withTemplate: "|||")

        let rawFragments = modified
            .components(separatedBy: "|||")
            .map { fragment in
                fragment
                    .replacingOccurrences(of: "___e_meio___", with: " e meio")
                    .replacingOccurrences(of: "___e_meia___", with: " e meia")
                    .replacingOccurrences(of: "___com_casca___", with: "com casca")
                    .replacingOccurrences(of: "___sem_casca___", with: "sem casca")
                    .replacingOccurrences(of: "___sem_acucar___", with: "sem açúcar")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return rawFragments
    }

    // MARK: - Parser de Item Individual

    private func parseItem(fragment: String) -> ParsedMealItem? {
        let raw = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        // Extrai quantidade, unidade e termo de busca do alimento
        let extraction = extractQuantityUnitAndQuery(from: raw)

        let quantity = extraction.quantity
        let unitString = extraction.unit
        let foodQuery = extraction.foodQuery

        // Busca o alimento na base via FoodSearchEngine
        let searchResults = searchEngine.search(query: foodQuery, limit: 3)
        let foundFood = searchResults.first

        guard let food = foundFood else {
            // Nenhum alimento correspondente encontrado
            return ParsedMealItem(
                rawText: raw,
                food: nil,
                matchedPortion: nil,
                detectedQuantity: quantity,
                detectedUnit: unitString,
                calculatedWeightGrams: 0,
                macros: MacroBreakdown(calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0, fiberGrams: 0),
                confidence: .low
            )
        }

        // Calcula peso e macronutrientes conforme unidade / medida caseira detectada
        let calculation = resolveWeightAndPortion(food: food, unit: unitString, quantity: quantity)

        let confidence: ParseConfidence
        if calculation.matchedPortion != nil || calculation.isMetricGramOrMl {
            confidence = .high
        } else {
            confidence = .medium
        }

        let macros = searchEngine.calculateMacros(for: food, amount: calculation.calculatedGrams)

        return ParsedMealItem(
            rawText: raw,
            food: food,
            matchedPortion: calculation.matchedPortion,
            detectedQuantity: quantity,
            detectedUnit: unitString,
            calculatedWeightGrams: calculation.calculatedGrams,
            macros: macros,
            confidence: confidence
        )
    }

    // MARK: - Extração de Quantidade, Unidade e Query

    private struct ExtractedData {
        let quantity: Double
        let unit: String
        let foodQuery: String
    }

    private func extractQuantityUnitAndQuery(from text: String) -> ExtractedData {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Tenta quantificador numérico com unidade métrica prefixada (ex: "200g de patinho", "150ml leite")
        if let metricMatch = matchMetricPrefix(clean) {
            return metricMatch
        }

        // 2. Tenta quantidade prefixada (numeral ou por extenso) seguida de medida caseira ou alimento
        if let prefixMatch = matchStandardPrefix(clean) {
            return prefixMatch
        }

        // 3. Tenta quantidade e unidade no sufixo (ex: "patinho grelhado 200g", "arroz 4 colheres")
        if let suffixMatch = matchSuffix(clean) {
            return suffixMatch
        }

        // 4. Sem quantificador explícito (ex: "arroz branco", "banana") -> Assume 1 unidade/porção
        let query = cleanPrepositions(from: clean)
        return ExtractedData(quantity: 1.0, unit: "unidade", foodQuery: query)
    }

    /// Trata prefixos como "200g", "150ml", "1.5kg"
    private func matchMetricPrefix(_ text: String) -> ExtractedData? {
        let pattern = "^(\\d+(?:[.,]\\d+)?)\\s*(kg|g|gr|gramas?|ml|mls|mililitros?|l|litros?)\\b(?:\\s+de\\s+|\\s+da\\s+|\\s+do\\s+|\\s+)(.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
              match.numberOfRanges >= 4 else {
            return nil
        }

        let rawQty = (text as NSString).substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ".")
        let rawUnit = (text as NSString).substring(with: match.range(at: 2)).lowercased()
        let rawFood = (text as NSString).substring(with: match.range(at: 3))

        guard let qty = Double(rawQty) else { return nil }

        let normalizedUnit: String
        let finalQty: Double

        if rawUnit.starts(with: "k") {
            normalizedUnit = "g"
            finalQty = qty * 1000.0
        } else if rawUnit == "l" || rawUnit.starts(with: "litr") {
            normalizedUnit = "ml"
            finalQty = qty * 1000.0
        } else if rawUnit.starts(with: "m") {
            normalizedUnit = "ml"
            finalQty = qty
        } else {
            normalizedUnit = "g"
            finalQty = qty
        }

        return ExtractedData(
            quantity: finalQty,
            unit: normalizedUnit,
            foodQuery: cleanPrepositions(from: rawFood)
        )
    }

    /// Trata prefixos padrão com números ou numerais por extenso (ex: "2 filés de frango", "1/2 abacate", "duas colheres de arroz")
    private func matchStandardPrefix(_ text: String) -> ExtractedData? {
        let tokens = text.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        var quantity: Double?
        var wordsConsumed = 0

        // Fração composta ou palavra composta (ex: "um e meio", "uma e meia")
        if tokens.count >= 3 {
            let combined = "\(tokens[0].lowercased()) \(tokens[1].lowercased()) \(tokens[2].lowercased())"
            if combined == "um e meio" || combined == "uma e meia" {
                quantity = 1.5
                wordsConsumed = 3
            } else if combined == "dois e meio" || combined == "duas e meia" {
                quantity = 2.5
                wordsConsumed = 3
            } else if combined == "tres e meio" || combined == "três e meio" {
                quantity = 3.5
                wordsConsumed = 3
            }
        }

        // Frações numéricas (ex: "1/2", "1/4", "3/4")
        if quantity == nil, let first = tokens.first {
            if first.contains("/") {
                let parts = first.components(separatedBy: "/")
                if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den > 0 {
                    quantity = num / den
                    wordsConsumed = 1
                }
            } else if let num = Double(first.replacingOccurrences(of: ",", with: ".")) {
                quantity = num
                wordsConsumed = 1
            } else if let wordNum = parseWordNumber(first.lowercased()) {
                quantity = wordNum
                wordsConsumed = 1
            }
        }

        guard let detectedQuantity = quantity, wordsConsumed > 0 else {
            return nil
        }

        let remainingTokens = Array(tokens.dropFirst(wordsConsumed))
        guard !remainingTokens.isEmpty else {
            return ExtractedData(quantity: detectedQuantity, unit: "unidade", foodQuery: "")
        }

        let remainingString = remainingTokens.joined(separator: " ")

        // Detecta se a palavra seguinte é uma medida caseira conhecida
        let measureResult = extractLeadingMeasure(from: remainingString)
        let unit = measureResult.measure ?? "unidade"
        let foodQuery = cleanPrepositions(from: measureResult.remainingFood)

        return ExtractedData(quantity: detectedQuantity, unit: unit, foodQuery: foodQuery)
    }

    /// Trata quantidades colocadas no final da frase (ex: "patinho grelhado 200g", "arroz 4 colheres")
    private func matchSuffix(_ text: String) -> ExtractedData? {
        let pattern = "^(.*)\\s+(\\d+(?:[.,]\\d+)?)\\s*(kg|g|gramas?|ml|l|colher(?:es)?|conchas?|fatias?|fil[eé]s?|unidades?|scoops?)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
              match.numberOfRanges >= 4 else {
            return nil
        }

        let rawFood = (text as NSString).substring(with: match.range(at: 1))
        let rawQty = (text as NSString).substring(with: match.range(at: 2)).replacingOccurrences(of: ",", with: ".")
        let rawUnit = (text as NSString).substring(with: match.range(at: 3)).lowercased()

        guard let qty = Double(rawQty) else { return nil }

        let normalizedUnit: String
        let finalQty: Double

        if rawUnit.starts(with: "k") {
            normalizedUnit = "g"
            finalQty = qty * 1000.0
        } else if rawUnit == "l" {
            normalizedUnit = "ml"
            finalQty = qty * 1000.0
        } else if rawUnit == "g" || rawUnit.starts(with: "gram") {
            normalizedUnit = "g"
            finalQty = qty
        } else if rawUnit == "ml" {
            normalizedUnit = "ml"
            finalQty = qty
        } else {
            normalizedUnit = rawUnit
            finalQty = qty
        }

        return ExtractedData(
            quantity: finalQty,
            unit: normalizedUnit,
            foodQuery: cleanPrepositions(from: rawFood)
        )
    }

    // MARK: - Resolução de Medida e Porção TBCA

    private struct ResolvedCalculation {
        let calculatedGrams: Double
        let matchedPortion: FoodPortion?
        let isMetricGramOrMl: Bool
    }

    private func resolveWeightAndPortion(food: FoodItem, unit: String, quantity: Double) -> ResolvedCalculation {
        let normUnit = FoodSearchEngine.normalize(unit)

        // Se a unidade for peso métrico direto (gramas ou ml)
        if normUnit == "g" || normUnit == "grama" || normUnit == "gramas" ||
           normUnit == "ml" || normUnit == "mililitro" || normUnit == "mililitros" {
            return ResolvedCalculation(
                calculatedGrams: quantity,
                matchedPortion: nil,
                isMetricGramOrMl: true
            )
        }

        // Tenta casar a medida informada com as porções cadastradas no alimento
        // 1. Pass 1: Correspondência direta ou de substring (ex: "colher de sobremesa" deve casar com "Colher de sobremesa" e não "Colher de sopa")
        for portion in food.portions {
            let normPortion = FoodSearchEngine.normalize(portion.name)

            if normPortion == normUnit || normPortion.contains(normUnit) || normUnit.contains(normPortion) {
                return ResolvedCalculation(
                    calculatedGrams: portion.gramWeight * quantity,
                    matchedPortion: portion,
                    isMetricGramOrMl: false
                )
            }
        }

        // 2. Pass 2: Casamento semântico flexível caso não haja correspondência direta
        for portion in food.portions {
            let normPortion = FoodSearchEngine.normalize(portion.name)

            if isPortionSemanticMatch(normUnit: normUnit, normPortion: normPortion) {
                return ResolvedCalculation(
                    calculatedGrams: portion.gramWeight * quantity,
                    matchedPortion: portion,
                    isMetricGramOrMl: false
                )
            }
        }

        // Se a unidade for genérica ("unidade", "un") ou não achou exata, busca porção padrão
        if normUnit == "unidade" || normUnit == "un" || normUnit == "und" {
            // Procura porção que represente unidade ou item inteiro
            if let unitPortion = food.portions.first(where: {
                let n = FoodSearchEngine.normalize($0.name)
                return n.contains("unidade") || n.contains("medio") || n.contains("media") ||
                       n.contains("inteir") || n.contains("posta") || n.contains("bife") ||
                       n.contains("file") || n.contains("fatia") || n.contains("disco")
            }) {
                return ResolvedCalculation(
                    calculatedGrams: unitPortion.gramWeight * quantity,
                    matchedPortion: unitPortion,
                    isMetricGramOrMl: false
                )
            }
        }

        // Fallback: se houver ao menos uma porção cadastrada, adota a primeira
        if let firstPortion = food.portions.first {
            return ResolvedCalculation(
                calculatedGrams: firstPortion.gramWeight * quantity,
                matchedPortion: firstPortion,
                isMetricGramOrMl: false
            )
        }

        // Fallback final: peso da porção base do alimento (geralmente 100g)
        return ResolvedCalculation(
            calculatedGrams: food.servingSize * quantity,
            matchedPortion: nil,
            isMetricGramOrMl: false
        )
    }

    private func isPortionSemanticMatch(normUnit: String, normPortion: String) -> Bool {
        if normUnit.contains("colher") && normPortion.contains("colher") { return true }
        if normUnit.contains("concha") && normPortion.contains("concha") { return true }
        if normUnit.contains("escumadeira") && normPortion.contains("escumadeira") { return true }
        if normUnit.contains("xicara") && normPortion.contains("xicara") { return true }
        if normUnit.contains("copo") && (normPortion.contains("copo") || normPortion.contains("caneca")) { return true }
        if normUnit.contains("fatia") && normPortion.contains("fatia") { return true }
        if normUnit.contains("file") && (normPortion.contains("file") || normPortion.contains("bife")) { return true }
        if normUnit.contains("bife") && (normPortion.contains("bife") || normPortion.contains("file")) { return true }
        if normUnit.contains("scoop") && (normPortion.contains("scoop") || normPortion.contains("dosador")) { return true }
        if normUnit.contains("pote") && normPortion.contains("pote") { return true }
        return false
    }

    // MARK: - Utilitários de Medidas Caseiras

    private struct ExtractedMeasure {
        let measure: String?
        let remainingFood: String
    }

    private func extractLeadingMeasure(from text: String) -> ExtractedMeasure {
        let measuresRegex = [
            "^colher(?:es)?\\s+de\\s+sopa(?:\\s+cheias?)?",
            "^colher(?:es)?\\s+de\\s+sobremesa",
            "^colher(?:es)?\\s+de\\s+ch[aá]",
            "^colher(?:es)?\\s+de\\s+caf[eé]",
            "^colher(?:es)?",
            "^conchas?\\s+(?:m[eé]dias?|pequenas?|grandes?)?",
            "^conchas?",
            "^escumadeiras?\\s+(?:cheias?|m[eé]dias?)?",
            "^escumadeiras?",
            "^x[ií]caras?\\s+(?:de\\s+ch[aá])?",
            "^x[ií]caras?",
            "^copos?\\s+(?:americanos?)?",
            "^copos?",
            "^canecas?",
            "^fatias?\\s+(?:m[eé]dias?|grossas?|finas?)?",
            "^fatias?",
            "^fil[eé]s?\\s+(?:m[eé]dios?|grandes?|pequenos?)?",
            "^fil[eé]s?",
            "^bifes?\\s+(?:m[eé]dios?|grandes?)?",
            "^bifes?",
            "^postas?\\s+(?:m[eé]dias?|grandes?)?",
            "^postas?",
            "^unidades?\\s+(?:m[eé]dias?|grandes?|pequenas?)?",
            "^unidades?",
            "^\\b(?:un|und)\\b",
            "^scoops?\\s+(?:padr[aã]o)?",
            "^scoops?",
            "^dosador(?:es)?",
            "^potes?\\s+(?:individuais?)?",
            "^potes?",
            "^pratos?\\s+(?:de\\s+sobremesa)?(?:\\s+cheios?)?",
            "^latas?\\s+(?:inteiras?|drenadas?|escorridas?)?",
            "^latas?",
            "^discos?\\s+(?:m[eé]dios?)?",
            "^discos?",
            "^peda[cç]os?\\s+(?:m[eé]dios?|grandes?)?",
            "^peda[cç]os?",
            "^ramos?\\s+(?:m[eé]dios?)?",
            "^ramos?",
            "^folhas?\\s+(?:m[eé]dias?)?",
            "^folhas?",
            "^gramas?",
            "^quilos?|quilogramas?",
            "^mililitros?",
            "^litros?"
        ]

        for pattern in measuresRegex {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                let measureText = (text as NSString).substring(with: match.range)
                let remaining = (text as NSString).substring(from: match.range.location + match.range.length)
                return ExtractedMeasure(measure: measureText.trimmingCharacters(in: .whitespaces), remainingFood: remaining)
            }
        }

        return ExtractedMeasure(measure: nil, remainingFood: text)
    }

    // MARK: - Conversão de Numerais em Português

    private func parseWordNumber(_ word: String) -> Double? {
        let clean = word
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()

        switch clean {
        case "meio", "meia": return 0.5
        case "um", "uma": return 1.0
        case "dois", "duas": return 2.0
        case "tres": return 3.0
        case "quatro": return 4.0
        case "cinco": return 5.0
        case "seis": return 6.0
        case "sete": return 7.0
        case "oito": return 8.0
        case "nove": return 9.0
        case "dez": return 10.0
        default: return nil
        }
    }

    // MARK: - Limpeza de Preposições

    private func cleanPrepositions(from text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = ["de ", "do ", "da ", "dos ", "das ", "d'"]
        for prefix in prefixes {
            if str.lowercased().hasPrefix(prefix) {
                str = String(str.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        return str.trimmingCharacters(in: CharacterSet(charactersIn: ",;.- "))
    }
}
