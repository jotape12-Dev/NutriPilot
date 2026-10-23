import Foundation

public struct FoodPortion: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var gramWeight: Double
    public var description: String?

    public init(
        id: UUID = UUID(),
        name: String,
        gramWeight: Double,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.gramWeight = gramWeight
        self.description = description
    }
}

public struct FoodItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var brand: String?
    public var servingSize: Double
    public var servingUnit: String
    public var calories: Double
    public var proteinGrams: Double
    public var carbsGrams: Double
    public var fatGrams: Double
    public var fiberGrams: Double
    public var source: String
    public var portions: [FoodPortion]

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        servingSize: Double = 100.0,
        servingUnit: String = "g",
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double = 0.0,
        source: String = "TBCA",
        portions: [FoodPortion] = []
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.source = source
        self.portions = portions
    }

    public func calculatedFor(amount: Double) -> (calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double) {
        guard servingSize > 0 else { return (0, 0, 0, 0, 0) }
        let ratio = amount / servingSize
        return (
            calories: (calories * ratio).rounded(to: 1),
            protein: (proteinGrams * ratio).rounded(to: 1),
            carbs: (carbsGrams * ratio).rounded(to: 1),
            fat: (fatGrams * ratio).rounded(to: 1),
            fiber: (fiberGrams * ratio).rounded(to: 1)
        )
    }

    public func calculatedFor(portion: FoodPortion, quantity: Double = 1.0) -> (calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double) {
        let totalGrams = portion.gramWeight * quantity
        return calculatedFor(amount: totalGrams)
    }

    /// Retorna a porção de unidade ou medida caseira de referência para alimentos comuns (frutas, ovos, fatias de pão).
    public var referenceUnitPortion: FoodPortion? {
        // 1. Procura primeiro nas porções cadastradas da TBCA por "unidade" ou "fatia"
        if let match = portions.first(where: {
            $0.name.localizedCaseInsensitiveContains("unidade") ||
            $0.name.localizedCaseInsensitiveContains("fatia")
        }) {
            return match
        }

        // 2. Mapeamento heurístico determinístico para frutas e itens tradicionalmente unitários
        let lower = name.lowercased()
        if lower.contains("banana") {
            return FoodPortion(name: "Unidade média", gramWeight: 70.0, description: "1 banana média (70g)")
        } else if lower.contains("maçã") || lower.contains("maca") {
            return FoodPortion(name: "Unidade média", gramWeight: 130.0, description: "1 maçã média (130g)")
        } else if lower.contains("laranja") {
            return FoodPortion(name: "Unidade média", gramWeight: 150.0, description: "1 laranja média (150g)")
        } else if lower.contains("ovo") {
            return FoodPortion(name: "Unidade", gramWeight: 50.0, description: "1 ovo (50g)")
        } else if lower.contains("pão") || lower.contains("pao") {
            if lower.contains("forma") || lower.contains("integral") {
                return FoodPortion(name: "Fatia", gramWeight: 25.0, description: "1 fatia (25g)")
            } else {
                return FoodPortion(name: "Unidade", gramWeight: 50.0, description: "1 pão francês (50g)")
            }
        } else if lower.contains("tomate") {
            return FoodPortion(name: "Unidade média", gramWeight: 100.0, description: "1 tomate médio (100g)")
        } else if lower.contains("tangerina") || lower.contains("mexerica") {
            return FoodPortion(name: "Unidade média", gramWeight: 100.0, description: "1 tangerina média (100g)")
        } else if lower.contains("pera") {
            return FoodPortion(name: "Unidade média", gramWeight: 130.0, description: "1 pera média (130g)")
        } else if lower.contains("kiwi") {
            return FoodPortion(name: "Unidade média", gramWeight: 75.0, description: "1 kiwi médio (75g)")
        }
        return nil
    }

    /// Converte gramatura para o número equivalente de unidades ou fatias.
    public func unitsForAmount(_ amount: Double) -> Double? {
        guard let ref = referenceUnitPortion, ref.gramWeight > 0 else { return nil }
        return (amount / ref.gramWeight).rounded(to: 1)
    }

    /// Formata a quantidade para exibição amigável em unidades ou gramas.
    public func formattedPortion(amount: Double, preferUnits: Bool) -> String {
        if preferUnits, let ref = referenceUnitPortion, ref.gramWeight > 0 {
            let units = (amount / ref.gramWeight)
            let formattedUnits: String
            if abs(units.rounded() - units) < 0.15 {
                formattedUnits = "\(Int(units.rounded()))"
            } else {
                formattedUnits = String(format: "%.1f", units)
            }
            let isSlice = ref.name.localizedCaseInsensitiveContains("fatia")
            let unitLabel = isSlice ? (units > 1.05 ? "fatias" : "fatia") : (units > 1.05 ? "unidades" : "unidade")
            return "\(formattedUnits) \(unitLabel) (\(Int(amount))g)"
        }
        return "\(Int(amount))g"
    }
}

public extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
