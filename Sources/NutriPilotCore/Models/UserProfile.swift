import Foundation

public enum BiologicalSex: String, Codable, Sendable, CaseIterable {
    case male = "Masculino"
    case female = "Feminino"
}

public enum ActivityLevel: String, Codable, Sendable, CaseIterable {
    case sedentary = "Sedentário (pouco ou nenhum exercício)"
    case light = "Leve (exercício 1-3 dias/sem)"
    case moderate = "Moderado (exercício 3-5 dias/sem)"
    case intense = "Intenso (exercício 6-7 dias/sem)"
    case extreme = "Muito intenso (2x ao dia ou trabalho pesado)"

    public var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .intense: return 1.725
        case .extreme: return 1.9
        }
    }
}

public enum NutritionGoal: String, Codable, Sendable, CaseIterable {
    case fatLoss = "Perda de Gordura (Déficit)"
    case muscleGain = "Ganho de Massa (Superávit)"
    case recomposition = "Recomposição Corporal"
    case maintenance = "Manutenção"
    case performance = "Performance Esportiva"

    public var calorieAdjustmentPercent: Double {
        switch self {
        case .fatLoss: return -0.20 // -20%
        case .muscleGain: return 0.10 // +10%
        case .recomposition: return -0.05 // -5% ou neutro
        case .maintenance: return 0.0
        case .performance: return 0.05 // +5%
        }
    }
}

public struct UserProfile: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var birthDate: Date
    public var sex: BiologicalSex
    public var heightCm: Double
    public var currentWeightKg: Double
    public var activityLevel: ActivityLevel
    public var goal: NutritionGoal
    public var dietaryRestrictions: [String]
    public var preferredMealsPerDay: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        sex: BiologicalSex,
        heightCm: Double,
        currentWeightKg: Double,
        activityLevel: ActivityLevel,
        goal: NutritionGoal,
        dietaryRestrictions: [String] = [],
        preferredMealsPerDay: Int = 4,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.sex = sex
        self.heightCm = heightCm
        self.currentWeightKg = currentWeightKg
        self.activityLevel = activityLevel
        self.goal = goal
        self.dietaryRestrictions = dietaryRestrictions
        self.preferredMealsPerDay = preferredMealsPerDay
        self.createdAt = createdAt
    }

    public var age: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return max(0, ageComponents.year ?? 0)
    }
}
