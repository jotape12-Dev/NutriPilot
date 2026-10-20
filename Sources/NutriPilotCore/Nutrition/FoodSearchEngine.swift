import Foundation

/// Resultado detalhado do cálculo de macronutrientes para uma porção ou gramatura de alimento.
public struct MacroBreakdown: Sendable, Equatable {
    public let calories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let fiberGrams: Double

    public init(
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }
}

/// Motor de busca e cálculo nutricional offline-first para o banco de alimentos.
/// Suporta busca insensível a maiúsculas e acentos (diacritic & case insensitive) com ranqueamento de relevância.
public final class FoodSearchEngine: Sendable {
    public static let shared = FoodSearchEngine()

    public let database: [FoodItem]

    public init(database: [FoodItem] = TBCAFoodDatabase.foods) {
        self.database = database
    }

    /// Normaliza uma string removendo diacríticos (acentos, cedilhas) e convertendo para minúsculas.
    public static func normalize(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Executa busca na base de alimentos com ranqueamento inteligente de relevância.
    /// Exemplo: "pao", "pão", "PÃO" encontram "Pão francês" com igual precisão.
    public func search(query: String, limit: Int? = nil) -> [FoodItem] {
        let cleanQuery = Self.normalize(query)
        guard !cleanQuery.isEmpty else { return [] }

        let queryTokens = cleanQuery
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard !queryTokens.isEmpty else { return [] }

        var scoredItems: [(item: FoodItem, score: Int)] = []

        for item in database {
            let normalizedName = Self.normalize(item.name)
            let normalizedBrand = item.brand.map { Self.normalize($0) } ?? ""

            var score = 0

            // 1. Correspondência exata no nome completo
            if normalizedName == cleanQuery {
                score += 1000
            }
            // 2. Prefixo exato no início do nome
            else if normalizedName.hasPrefix(cleanQuery) {
                score += 600
                // Bônus se for palavra isolada logo no início (ex: "pao " em "pao frances")
                if normalizedName.hasPrefix(cleanQuery + " ") {
                    score += 150
                }
            }
            // 3. Contém o termo exato da busca
            else if normalizedName.contains(cleanQuery) {
                score += 400
            }

            // 4. Bônus para nomes mais curtos / concisos quando há correspondência
            if score > 0 {
                score += max(0, 40 - item.name.count)
            }

            // 4. Correspondência de tokens individuais (ex: "arroz" e "branco")
            var matchedTokens = 0
            for token in queryTokens {
                if normalizedName.contains(token) {
                    matchedTokens += 1
                } else if normalizedBrand.contains(token) {
                    matchedTokens += 1
                }
            }

            if matchedTokens == queryTokens.count {
                score += 200 + (matchedTokens * 20)
            } else if matchedTokens > 0 {
                score += (matchedTokens * 30)
            }

            if score > 0 {
                scoredItems.append((item, score))
            }
        }

        // Ordena por maior pontuação e desempata por ordem alfabética do nome
        scoredItems.sort { first, second in
            if first.score != second.score {
                return first.score > second.score
            }
            return first.item.name < second.item.name
        }

        let results = scoredItems.map(\.item)
        if let limit = limit, limit > 0 {
            return Array(results.prefix(limit))
        }
        return results
    }

    /// Calcula os macronutrientes proporcionais para uma quantidade arbitrária (em gramas/ml).
    public func calculateMacros(for food: FoodItem, amount: Double) -> MacroBreakdown {
        let values = food.calculatedFor(amount: amount)
        return MacroBreakdown(
            calories: values.calories,
            proteinGrams: values.protein,
            carbsGrams: values.carbs,
            fatGrams: values.fat,
            fiberGrams: values.fiber
        )
    }

    /// Calcula os macronutrientes para uma porção/medida caseira e seu multiplicador.
    public func calculateMacros(for food: FoodItem, portion: FoodPortion, quantity: Double = 1.0) -> MacroBreakdown {
        let totalWeight = portion.gramWeight * quantity
        return calculateMacros(for: food, amount: totalWeight)
    }

    /// Cria um item pronto para ser registrado em uma refeição a partir de uma quantidade em gramas/ml.
    public func createMealLogItem(from food: FoodItem, amount: Double, customUnit: String? = nil) -> MealLogItem {
        let macros = calculateMacros(for: food, amount: amount)
        return MealLogItem(
            foodId: food.id,
            name: food.name,
            quantity: amount,
            unit: customUnit ?? food.servingUnit,
            calories: macros.calories,
            proteinGrams: macros.proteinGrams,
            carbsGrams: macros.carbsGrams,
            fatGrams: macros.fatGrams,
            fiberGrams: macros.fiberGrams
        )
    }

    /// Cria um item pronto para refeição baseado em uma medida caseira específica.
    public func createMealLogItem(from food: FoodItem, portion: FoodPortion, quantity: Double = 1.0) -> MealLogItem {
        let totalGrams = portion.gramWeight * quantity
        let macros = calculateMacros(for: food, amount: totalGrams)
        let formattedName = quantity == 1.0
            ? "\(food.name) (\(portion.name))"
            : "\(food.name) (\(Int(quantity))x \(portion.name))"

        return MealLogItem(
            foodId: food.id,
            name: formattedName,
            quantity: totalGrams,
            unit: food.servingUnit,
            calories: macros.calories,
            proteinGrams: macros.proteinGrams,
            carbsGrams: macros.carbsGrams,
            fatGrams: macros.fatGrams,
            fiberGrams: macros.fiberGrams
        )
    }
}
