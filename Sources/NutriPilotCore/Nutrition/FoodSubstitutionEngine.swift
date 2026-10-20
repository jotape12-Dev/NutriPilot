import Foundation

/// Grupo macronutricional para fins de equivalência de substituição (estilo Dietbox / Avanutri).
public enum SubstitutionGroup: String, Codable, Sendable, CaseIterable {
    case carbohydrates = "Carboidratos"
    case proteins = "Proteínas"
    case fats = "Gorduras"
    case fruits = "Frutas"
    case dairy = "Laticínios"

    public var anchorMacroDescription: String {
        switch self {
        case .carbohydrates: return "Carboidratos idênticos"
        case .proteins: return "Proteínas idênticas"
        case .fats: return "Gorduras idênticas"
        case .fruits: return "Carboidratos/Calorias de frutas"
        case .dairy: return "Proteínas de laticínios"
        }
    }
}

/// Resultado detalhado de uma substituição equivalente.
public struct SubstitutionResult: Sendable, Equatable {
    public let originalFood: FoodItem
    public let originalAmount: Double
    public let substituteFood: FoodItem
    public let equivalentAmount: Double
    public let unit: String
    public let suggestedPortion: String?
    public let originalCalories: Double
    public let substituteCalories: Double
    public let deltaCalories: Double
    public let anchorMacroGrams: Double
    public let group: SubstitutionGroup

    public init(
        originalFood: FoodItem,
        originalAmount: Double,
        substituteFood: FoodItem,
        equivalentAmount: Double,
        unit: String,
        suggestedPortion: String? = nil,
        originalCalories: Double,
        substituteCalories: Double,
        deltaCalories: Double,
        anchorMacroGrams: Double,
        group: SubstitutionGroup
    ) {
        self.originalFood = originalFood
        self.originalAmount = originalAmount.rounded(to: 1)
        self.substituteFood = substituteFood
        self.equivalentAmount = equivalentAmount.rounded(to: 1)
        self.unit = unit
        self.suggestedPortion = suggestedPortion
        self.originalCalories = originalCalories.rounded(to: 1)
        self.substituteCalories = substituteCalories.rounded(to: 1)
        self.deltaCalories = deltaCalories.rounded(to: 1)
        self.anchorMacroGrams = anchorMacroGrams.rounded(to: 1)
        self.group = group
    }
}

/// Motor de substituição e equivalência nutricional baseado nos grupos da TBCA.
/// Garante que ao trocar um carboidrato por outro, a carga de carboidratos permaneça idêntica,
/// e analogamente para proteínas e gorduras, preservando a aderência do plano alimentar.
public enum FoodSubstitutionEngine {

    // MARK: - Classificação por Grupos

    /// Identifica o grupo macronutricional principal do alimento.
    public static func group(for food: FoodItem) -> SubstitutionGroup? {
        let name = FoodSearchEngine.normalize(food.name)

        // Gorduras
        if name.contains("azeite") || name.contains("amendoim") || name.contains("castanha") {
            return .fats
        }

        // Laticínios
        if name.contains("leite") || name.contains("iogurte") || name.contains("queijo") {
            return .dairy
        }

        // Frutas
        if name.contains("banana") || name.contains("maca") || name.contains("mamao") || name.contains("abacate") {
            return .fruits
        }

        // Proteínas
        if name.contains("frango") || name.contains("patinho") || name.contains("carne") ||
           name.contains("tilapia") || name.contains("salmao") || name.contains("atum") ||
           name.contains("ovo") || name.contains("whey") {
            return .proteins
        }

        // Carboidratos
        if name.contains("arroz") || name.contains("batata") || name.contains("mandioca") ||
           name.contains("aipim") || name.contains("aveia") || name.contains("tapioca") ||
           name.contains("pao") || name.contains("feijao") {
            return .carbohydrates
        }

        // Fallback pelos macros predominantes por 100g
        if food.proteinGrams > 15.0 { return .proteins }
        if food.fatGrams > 20.0 { return .fats }
        if food.carbsGrams > 15.0 { return .carbohydrates }

        return nil
    }

    // MARK: - Cálculo de Equivalência

    /// Calcula a gramatura exata do alimento substituto para manter o macronutriente âncora idêntico.
    public static func substitute(
        originalFood: FoodItem,
        originalAmount: Double,
        substituteFood: FoodItem
    ) -> SubstitutionResult? {
        guard originalAmount > 0 else { return nil }

        let originalGroup = group(for: originalFood)
        let substituteGroup = group(for: substituteFood)

        // Devem pertencer ao mesmo grupo de equivalência (ou ambos serem fontes do mesmo macro)
        let effectiveGroup: SubstitutionGroup
        if let g1 = originalGroup, let g2 = substituteGroup, g1 == g2 {
            effectiveGroup = g1
        } else if let g = originalGroup {
            effectiveGroup = g
        } else {
            effectiveGroup = .carbohydrates
        }

        let originalMacros = originalFood.calculatedFor(amount: originalAmount)
        let equivalentAmount: Double
        let anchorValue: Double

        switch effectiveGroup {
        case .carbohydrates, .fruits:
            anchorValue = originalMacros.carbs
            guard substituteFood.carbsGrams > 0 else { return nil }
            let carbsPerGram = substituteFood.carbsGrams / substituteFood.servingSize
            equivalentAmount = anchorValue / carbsPerGram

        case .proteins, .dairy:
            anchorValue = originalMacros.protein
            guard substituteFood.proteinGrams > 0 else { return nil }
            let proteinPerGram = substituteFood.proteinGrams / substituteFood.servingSize
            equivalentAmount = anchorValue / proteinPerGram

        case .fats:
            anchorValue = originalMacros.fat
            guard substituteFood.fatGrams > 0 else { return nil }
            let fatPerGram = substituteFood.fatGrams / substituteFood.servingSize
            equivalentAmount = anchorValue / fatPerGram
        }

        let substituteMacros = substituteFood.calculatedFor(amount: equivalentAmount)
        let deltaCalories = substituteMacros.calories - originalMacros.calories

        // Encontra a medida caseira mais próxima no alimento substituto
        let suggestedPortion = findBestMatchingPortion(food: substituteFood, amount: equivalentAmount)

        return SubstitutionResult(
            originalFood: originalFood,
            originalAmount: originalAmount,
            substituteFood: substituteFood,
            equivalentAmount: equivalentAmount,
            unit: substituteFood.servingUnit,
            suggestedPortion: suggestedPortion,
            originalCalories: originalMacros.calories,
            substituteCalories: substituteMacros.calories,
            deltaCalories: deltaCalories,
            anchorMacroGrams: anchorValue,
            group: effectiveGroup
        )
    }

    /// Retorna todos os substitutos equivalentes disponíveis na base para determinado alimento.
    public static func availableSubstitutes(
        for food: FoodItem,
        amount: Double,
        database: [FoodItem] = TBCAFoodDatabase.foods
    ) -> [SubstitutionResult] {
        guard let foodGroup = group(for: food) else { return [] }

        var results: [SubstitutionResult] = []

        for candidate in database {
            // Não sugere o mesmo alimento
            guard candidate.id != food.id && candidate.name != food.name else { continue }

            if group(for: candidate) == foodGroup {
                if let sub = substitute(originalFood: food, originalAmount: amount, substituteFood: candidate) {
                    results.append(sub)
                }
            }
        }

        // Ordena pela menor variação calórica em relação ao prato original
        return results.sorted { abs($0.deltaCalories) < abs($1.deltaCalories) }
    }

    // MARK: - Auxiliares de Porção

    private static func findBestMatchingPortion(food: FoodItem, amount: Double) -> String? {
        guard !food.portions.isEmpty else { return nil }

        for portion in food.portions {
            if portion.gramWeight > 0 {
                let ratio = amount / portion.gramWeight
                if abs(ratio - 1.0) <= 0.2 {
                    return "Aprox. 1 \(portion.name)"
                } else if abs(ratio - round(ratio)) <= 0.15 && ratio >= 1.5 && ratio <= 6.0 {
                    return "Aprox. \(Int(round(ratio)))x \(portion.name)"
                }
            }
        }

        return nil
    }
}
