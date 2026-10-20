import Foundation

public enum MealType: String, Codable, Sendable, CaseIterable {
    case breakfast = "Café da Manhã"
    case morningSnack = "Lanche da Manhã"
    case lunch = "Almoço"
    case afternoonSnack = "Lanche da Tarde"
    case dinner = "Jantar"
    case supper = "Ceia"
}

public enum InputMethod: String, Codable, Sendable {
    case quickText = "Texto Rápido"
    case voice = "Voz"
    case search = "Busca Manual"
    case favorite = "Favorito / Recorrente"
    case photo = "Foto com IA"
}

public struct MealLogItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var foodId: UUID?
    public var name: String
    public var quantity: Double
    public var unit: String
    public var calories: Double
    public var proteinGrams: Double
    public var carbsGrams: Double
    public var fatGrams: Double
    public var fiberGrams: Double

    public init(
        id: UUID = UUID(),
        foodId: UUID? = nil,
        name: String,
        quantity: Double,
        unit: String = "g",
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double = 0.0
    ) {
        self.id = id
        self.foodId = foodId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }
}

public struct MealLog: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var date: Date
    public var mealType: MealType
    public var loggedAt: Date
    public var inputMethod: InputMethod
    public var rawInput: String?
    public var confidence: Double
    public var items: [MealLogItem]
    public var confirmedByUser: Bool

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType,
        loggedAt: Date = Date(),
        inputMethod: InputMethod = .quickText,
        rawInput: String? = nil,
        confidence: Double = 1.0,
        items: [MealLogItem] = [],
        confirmedByUser: Bool = true
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.loggedAt = loggedAt
        self.inputMethod = inputMethod
        self.rawInput = rawInput
        self.confidence = confidence
        self.items = items
        self.confirmedByUser = confirmedByUser
    }

    public var totalCalories: Double {
        items.reduce(0) { $0 + $1.calories }
    }

    public var totalProtein: Double {
        items.reduce(0) { $0 + $1.proteinGrams }
    }

    public var totalCarbs: Double {
        items.reduce(0) { $0 + $1.carbsGrams }
    }

    public var totalFat: Double {
        items.reduce(0) { $0 + $1.fatGrams }
    }

    public var totalFiber: Double {
        items.reduce(0) { $0 + $1.fiberGrams }
    }
}
