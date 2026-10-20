import Foundation

/// Categorias e departamentos clássicos de supermercado para lista de compras.
public enum GroceryCategory: String, Codable, Sendable, CaseIterable {
    case produce = "Hortifrúti"
    case meatAndEggs = "Carnes e Ovos"
    case dairy = "Laticínios"
    case grocery = "Mercearia"

    public var iconName: String {
        switch self {
        case .produce: return "leaf.fill"
        case .meatAndEggs: return "flame.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .grocery: return "cart.fill"
        }
    }
}

/// Item da lista de compras consolidado por alimento e departamento.
public struct GroceryItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var category: GroceryCategory
    public var totalAmount: Double
    public var unit: String
    public var formattedQuantity: String
    public var isChecked: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        category: GroceryCategory,
        totalAmount: Double,
        unit: String,
        formattedQuantity: String? = nil,
        isChecked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.totalAmount = totalAmount.rounded(to: 1)
        self.unit = unit
        self.isChecked = isChecked
        if let formatted = formattedQuantity {
            self.formattedQuantity = formatted
        } else {
            self.formattedQuantity = Self.formatAmount(totalAmount, unit: unit)
        }
    }

    public static func formatAmount(_ amount: Double, unit: String) -> String {
        let u = unit.lowercased()
        if u == "g" || u == "gramas" {
            if amount >= 1000.0 {
                let kg = amount / 1000.0
                return kg.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(kg)) kg"
                    : String(format: "%.2f kg", kg)
            } else {
                return "\(Int(round(amount))) g"
            }
        } else if u == "ml" || u == "mililitros" {
            if amount >= 1000.0 {
                let l = amount / 1000.0
                return l.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(l)) L"
                    : String(format: "%.1f L", l)
            } else {
                return "\(Int(round(amount))) ml"
            }
        } else {
            return "\(Int(round(amount))) \(unit)"
        }
    }
}

/// Lista de compras consolidada para um ciclo de dias (ex: 7 dias de semana).
public struct GroceryList: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let planId: UUID?
    public let numberOfDays: Int
    public var items: [GroceryItem]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        planId: UUID? = nil,
        numberOfDays: Int = 7,
        items: [GroceryItem]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.planId = planId
        self.numberOfDays = numberOfDays
        self.items = items
    }

    public func items(for category: GroceryCategory) -> [GroceryItem] {
        items.filter { $0.category == category }
    }
}

/// Gerador e consolidador de lista de compras a partir de cardápios semanais do plano alimentar.
public enum GroceryListGenerator {

    /// Consolida todos os ingredientes do cardápio para `numberOfDays` dias, agrupando por departamento de supermercado.
    public static func generateGroceryList(
        from plan: DailyMealPlan,
        numberOfDays: Int = 7
    ) -> GroceryList {
        let days = max(1, numberOfDays)
        var aggregated: [String: (food: FoodItem, totalAmount: Double)] = [:]

        for meal in plan.meals {
            for item in meal.items {
                let key = item.food.name
                let additional = item.amount * Double(days)
                if let existing = aggregated[key] {
                    aggregated[key] = (existing.food, existing.totalAmount + additional)
                } else {
                    aggregated[key] = (item.food, additional)
                }
            }
        }

        var groceryItems: [GroceryItem] = []

        for (_, pair) in aggregated {
            let cat = department(for: pair.food)
            let item = GroceryItem(
                name: pair.food.name,
                category: cat,
                totalAmount: pair.totalAmount,
                unit: pair.food.servingUnit,
                isChecked: false
            )
            groceryItems.append(item)
        }

        // Ordena por departamento e nome
        groceryItems.sort { first, second in
            if first.category.rawValue != second.category.rawValue {
                return first.category.rawValue < second.category.rawValue
            }
            return first.name < second.name
        }

        return GroceryList(
            planId: plan.id,
            numberOfDays: days,
            items: groceryItems
        )
    }

    /// Identifica o departamento de compras apropriado para o alimento.
    public static func department(for food: FoodItem) -> GroceryCategory {
        let name = FoodSearchEngine.normalize(food.name)

        // Hortifrúti (Frutas, verduras, legumes, tubérculos)
        if name.contains("banana") || name.contains("maca") || name.contains("mamao") ||
           name.contains("abacate") || name.contains("tomate") || name.contains("alface") ||
           name.contains("cenoura") || name.contains("brocolis") || name.contains("batata") ||
           name.contains("mandioca") || name.contains("aipim") {
            return .produce
        }

        // Carnes e Ovos
        if name.contains("frango") || name.contains("patinho") || name.contains("carne") ||
           name.contains("tilapia") || name.contains("salmao") || name.contains("atum") ||
           name.contains("ovo") {
            return .meatAndEggs
        }

        // Laticínios
        if name.contains("leite") || name.contains("iogurte") || name.contains("queijo") ||
           name.contains("whey") {
            return .dairy
        }

        // Mercearia (Grãos, cereais, azeite, pão, café, temperos)
        return .grocery
    }
}
