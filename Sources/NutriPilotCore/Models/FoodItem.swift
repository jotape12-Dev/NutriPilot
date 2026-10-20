import Foundation

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
        source: String = "TBCA"
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
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
