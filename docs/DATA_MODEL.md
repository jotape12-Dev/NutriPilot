# NutriPilot — Modelo de Dados (DATA_MODEL.md)

> Entidades centrais do SwiftData / Core para persistência local.

---

## 1. Entidades Principais

### `UserProfile`
- `id: UUID`
- `name: String`
- `birthDate: Date`
- `sex: BiologicalSex` (`male`, `female`)
- `heightCm: Double`
- `activityLevel: ActivityLevel` (`sedentary`, `light`, `moderate`, `intense`, `extreme`)
- `goal: NutritionGoal` (`fatLoss`, `muscleGain`, `recomposition`, `maintenance`, `performance`)
- `dietaryRestrictions: [String]`
- `preferredMealsPerDay: Int`
- `createdAt: Date`

### `NutritionTarget`
- `id: UUID`
- `effectiveFrom: Date`
- `calories: Double`
- `proteinGrams: Double`
- `carbsGrams: Double`
- `fatGrams: Double`
- `fiberGrams: Double`
- `waterMl: Double`
- `source: TargetSource` (`initialCalculation`, `autoCalibrated`, `manualOverride`)
- `isManualLock: Bool`

### `FoodItem`
- `id: UUID`
- `name: String`
- `brand: String?`
- `servingSize: Double` (ex: 100)
- `servingUnit: String` (ex: "g", "ml", "unidade")
- `calories: Double`
- `proteinGrams: Double`
- `carbsGrams: Double`
- `fatGrams: Double`
- `fiberGrams: Double`
- `source: String` (ex: "TBCA", "Custom")

### `MealLog` & `MealLogItem`
- `id: UUID`
- `date: Date`
- `mealType: MealType` (`breakfast`, `morningSnack`, `lunch`, `afternoonSnack`, `dinner`, `supper`)
- `loggedAt: Date`
- `inputMethod: InputMethod` (`quickText`, `voice`, `search`, `favorite`, `photo`)
- `rawInput: String?`
- `items: [MealLogItem]`
- `confirmedByUser: Bool`

### `WaterLog`
- `id: UUID`
- `date: Date`
- `amountMl: Double`
- `loggedAt: Date`

### `BodyMeasurement`
- `id: UUID`
- `measuredAt: Date`
- `weightKg: Double`
- `waistCm: Double?`
- `hipCm: Double?`
- `chestCm: Double?`
- `armCm: Double?`
- `thighCm: Double?`
- `bodyFatPercent: Double?`
- `leanMassKg: Double?`
- `source: MeasurementSource` (`manual`, `smartScale`, `bia`, `dexa`)
- `isReference: Bool`

### `BodyPhoto`
- `id: UUID`
- `capturedAt: Date`
- `pose: PhotoPose` (`front`, `side`, `back`)
- `localFilePath: String`
- `estimatedFatMin: Double?`
- `estimatedFatMax: Double?`
- `confidence: Double?`
- `calibratedWithMeasurementId: UUID?`
