import SwiftUI
import NutriPilotCore

public struct FoodLoggingView: View {
    @State private var quickTextInput: String = ""
    @State private var selectedMeal: MealType = .lunch
    @State private var logs: [MealLog] = []

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Seletor de refeição
                Picker("Refeição", selection: $selectedMeal) {
                    ForEach(MealType.allCases, id: \.self) { meal in
                        Text(meal.rawValue).tag(meal)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Campo de registro por texto rápido
                HStack {
                    Image(systemName: "pencil.and.outline")
                        .foregroundColor(.green)
                    TextField("Ex: 200g frango, 150g arroz e salada", text: $quickTextInput)
                        .onSubmit {
                            submitQuickLog()
                        }
                    if !quickTextInput.isEmpty {
                        Button(action: submitQuickLog) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color.appCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                // Lista de Refeições do Dia
                List {
                    Section("Registrados Hoje") {
                        if logs.isEmpty {
                            Text("Nenhuma refeição registrada ainda hoje.")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(logs) { log in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(log.mealType.rawValue)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(Int(log.totalCalories)) kcal")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.orange)
                                    }
                                    if let raw = log.rawInput {
                                        Text(raw)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Text("Proteína: \(Int(log.totalProtein))g | Carbs: \(Int(log.totalCarbs))g | Gord: \(Int(log.totalFat))g")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Refeições")
            .background(Color.appBackground)
        }
    }

    private func submitQuickLog() {
        guard !quickTextInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let newLog = MealLog(
            mealType: selectedMeal,
            inputMethod: .quickText,
            rawInput: quickTextInput,
            items: [
                MealLogItem(name: quickTextInput, quantity: 1, unit: "porção", calories: 550, proteinGrams: 45, carbsGrams: 50, fatGrams: 12)
            ]
        )
        logs.insert(newLog, at: 0)
        quickTextInput = ""
    }
}
