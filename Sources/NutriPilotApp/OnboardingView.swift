import SwiftUI
import NutriPilotCore

public struct OnboardingView: View {
    @Bindable var store: ProfileStore

    @State private var name: String = "João"
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -23, to: Date()) ?? Date()
    @State private var sex: BiologicalSex = .male
    @State private var heightCm: Double = 178
    @State private var weightKg: Double = 78.0
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var goal: NutritionGoal = .recomposition
    @State private var mealsPerDay: Int = 4

    @State private var calculatedResult: NutritionCalculationResult?

    public init(store: ProfileStore = .shared) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Identificação & Biometria") {
                    TextField("Nome ou Apelido", text: $name)

                    DatePicker("Nascimento", selection: $birthDate, displayedComponents: .date)

                    Picker("Sexo Biológico", selection: $sex) {
                        ForEach(BiologicalSex.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }

                    HStack {
                        Text("Altura")
                        Spacer()
                        Text("\(Int(heightCm)) cm")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $heightCm, in: 140...210, step: 1)
                        .onChange(of: heightCm) { _, _ in recalculate() }

                    HStack {
                        Text("Peso Atual")
                        Spacer()
                        Text(String(format: "%.1f kg", weightKg))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $weightKg, in: 40...150, step: 0.5)
                        .onChange(of: weightKg) { _, _ in recalculate() }
                }

                Section("Rotina & Objetivo") {
                    Picker("Nível de Atividade", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .onChange(of: activityLevel) { _, _ in recalculate() }

                    Picker("Objetivo Principal", selection: $goal) {
                        ForEach(NutritionGoal.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    .onChange(of: goal) { _, _ in recalculate() }

                    Stepper("Refeições por dia: \(mealsPerDay)", value: $mealsPerDay, in: 2...6)
                }

                if let res = calculatedResult {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.green)
                                Text("METAS INICIAIS SUGERIDAS")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("\(Int(res.targetCalories)) kcal")
                                    .font(.title2.bold())
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("Água: \(Int(res.targetWaterMl)) ml")
                                    .font(.headline)
                                    .foregroundColor(.cyan)
                            }

                            HStack(spacing: 16) {
                                macroBadge(name: "Proteína", grams: Int(res.targetProteinGrams), color: .blue)
                                macroBadge(name: "Carboidratos", grams: Int(res.targetCarbsGrams), color: .green)
                                macroBadge(name: "Gordura", grams: Int(res.targetFatGrams), color: .purple)
                            }

                            Text("⚠️ Estimativa inicial por Mifflin-St Jeor — será calibrada após 14 dias de registros reais de peso.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Text("Cálculo Imediato")
                    }
                }

                Section {
                    Button(action: finishOnboarding) {
                        Text("Iniciar NutriPilot")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.green)
                }
            }
            .navigationTitle("Configurar Perfil")
            .onAppear {
                recalculate()
            }
        }
    }

    private func macroBadge(name: String, grams: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(grams)g")
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
    }

    private func recalculate() {
        let tempProfile = UserProfile(
            name: name,
            birthDate: birthDate,
            sex: sex,
            heightCm: heightCm,
            currentWeightKg: weightKg,
            activityLevel: activityLevel,
            goal: goal,
            preferredMealsPerDay: mealsPerDay
        )
        calculatedResult = NutritionCalculator.calculateFullTarget(from: tempProfile)
    }

    private func finishOnboarding() {
        let profile = UserProfile(
            name: name,
            birthDate: birthDate,
            sex: sex,
            heightCm: heightCm,
            currentWeightKg: weightKg,
            activityLevel: activityLevel,
            goal: goal,
            preferredMealsPerDay: mealsPerDay
        )
        store.saveProfile(profile)
    }
}
