import SwiftUI
import NutriPilotCore

public struct MealParserConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let initialMeal: ParsedMeal
    @State private var items: [ParsedMealItem]
    @State private var selectedMealType: MealType
    public var mealStore: MealStore
    public var searchEngine: FoodSearchEngine
    public var onConfirmed: (() -> Void)?

    @State private var hapticTrigger: Int = 0

    public init(
        parsedMeal: ParsedMeal,
        defaultMealType: MealType = .lunch,
        mealStore: MealStore = .shared,
        searchEngine: FoodSearchEngine = .shared,
        onConfirmed: (() -> Void)? = nil
    ) {
        self.initialMeal = parsedMeal
        self._items = State(initialValue: parsedMeal.items)
        self._selectedMealType = State(initialValue: defaultMealType)
        self.mealStore = mealStore
        self.searchEngine = searchEngine
        self.onConfirmed = onConfirmed
    }

    private var totalCalories: Double {
        items.reduce(0.0) { $0 + $1.macros.calories }.rounded(to: 1)
    }

    private var totalProtein: Double {
        items.reduce(0.0) { $0 + $1.macros.proteinGrams }.rounded(to: 1)
    }

    private var totalCarbs: Double {
        items.reduce(0.0) { $0 + $1.macros.carbsGrams }.rounded(to: 1)
    }

    private var totalFat: Double {
        items.reduce(0.0) { $0 + $1.macros.fatGrams }.rounded(to: 1)
    }

    private var totalFiber: Double {
        items.reduce(0.0) { $0 + $1.macros.fiberGrams }.rounded(to: 1)
    }

    private var overallConfidence: ParseConfidence {
        if items.isEmpty {
            return .low
        } else if items.allSatisfy({ $0.confidence == .high }) {
            return .high
        } else if items.contains(where: { $0.confidence == .low }) {
            return .low
        } else {
            return .medium
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header de Confiança e Frase Original
                    headerSection

                    // Seletor de Refeição
                    mealTypeSelector

                    // Card de Macros Consolidados
                    macrosConsolidatedCard

                    // Lista de Itens Identificados
                    itemsListSection

                    // Botão de Confirmação em 1 Toque
                    confirmButtonSection
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Confirmar Refeição")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .background(Color.appBackground)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 10) {
            confidenceBadge(confidence: overallConfidence)

            if !initialMeal.rawInput.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(initialMeal.rawInput)
                        .font(.subheadline.italic())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Image(systemName: "quote.closing")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 12)
    }

    private func confidenceBadge(confidence: ParseConfidence) -> some View {
        HStack(spacing: 6) {
            switch confidence {
            case .high:
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Text("Alta Confiança • Alimentos Identificados")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            case .medium:
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                Text("Média Confiança • Verifique as Porções")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            case .low:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Baixa Confiança • Ajuste os Itens")
                    .font(.caption.bold())
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(confidenceColor(confidence).opacity(0.12))
        )
    }

    private func confidenceColor(_ confidence: ParseConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }

    private var mealTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Registrar em:")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Picker("Refeição", selection: $selectedMealType) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }

    private var macrosConsolidatedCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("TOTAIS DA REFEIÇÃO")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(totalCalories)) kcal")
                    .font(.title3.bold())
                    .foregroundColor(.orange)
            }

            Divider()

            HStack(spacing: 12) {
                macroItem(title: "Proteína", value: "\(Int(totalProtein))g", color: .blue)
                macroItem(title: "Carbos", value: "\(Int(totalCarbs))g", color: .green)
                macroItem(title: "Gorduras", value: "\(Int(totalFat))g", color: .purple)
                macroItem(title: "Fibras", value: "\(Int(totalFiber))g", color: .brown)
            }
        }
        .padding(14)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func macroItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var itemsListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ITENS IDENTIFICADOS (\(items.count))")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("Toque em +/- para ajustar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if items.isEmpty {
                Text("Nenhum item restante para registrar.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(items.indices, id: \.self) { idx in
                        let item = items[idx]
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(item.food?.name ?? item.rawText)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)

                                        confidenceTag(confidence: item.confidence)
                                    }

                                    if let portion = item.matchedPortion {
                                        Text("\(portion.name) (\(Int(item.calculatedWeightGrams))g)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(Int(item.calculatedWeightGrams))g")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    withAnimation {
                                        items.remove(at: idx)
                                        hapticTrigger += 1
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                                .buttonStyle(.borderless)
                            }

                            HStack {
                                // Macros do item
                                HStack(spacing: 8) {
                                    Text("\(Int(item.macros.calories)) kcal")
                                        .font(.caption.bold())
                                        .foregroundColor(.orange)
                                    Text("P: \(Int(item.macros.proteinGrams))g")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    Text("C: \(Int(item.macros.carbsGrams))g")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("G: \(Int(item.macros.fatGrams))g")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                }

                                Spacer()

                                // Controles de Quantidade
                                HStack(spacing: 8) {
                                    Button {
                                        decrementQuantity(at: idx)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)

                                    let qtyText = item.detectedQuantity.truncatingRemainder(dividingBy: 1) == 0
                                        ? "\(Int(item.detectedQuantity))"
                                        : String(format: "%.1f", item.detectedQuantity)
                                    Text(qtyText)
                                        .font(.subheadline.bold())
                                        .frame(minWidth: 26)

                                    Button {
                                        incrementQuantity(at: idx)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.green)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func confidenceTag(confidence: ParseConfidence) -> some View {
        Text(confidence == .high ? "OK" : (confidence == .medium ? "Médio" : "Verificar"))
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidenceColor(confidence).opacity(0.15))
            .foregroundColor(confidenceColor(confidence))
            .clipShape(Capsule())
    }

    private var confirmButtonSection: some View {
        Button {
            guard !items.isEmpty else { return }
            let mealLogItems = items.map { $0.toMealLogItem() }
            let mealLog = MealLog(
                date: Date(),
                mealType: selectedMealType,
                loggedAt: Date(),
                inputMethod: .quickText,
                rawInput: initialMeal.rawInput,
                confidence: overallConfidence == .high ? 1.0 : (overallConfidence == .medium ? 0.75 : 0.4),
                items: mealLogItems,
                confirmedByUser: true
            )
            _ = mealStore.addMeal(mealLog)
            hapticTrigger += 1
            onConfirmed?()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.headline)
                Text("Confirmar e Registrar no \(selectedMealType.rawValue)")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(items.isEmpty ? Color.gray : Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.green.opacity(items.isEmpty ? 0 : 0.3), radius: 6, y: 3)
        }
        .disabled(items.isEmpty)
        .padding(.horizontal)
    }

    // MARK: - Ajustes de Quantidade

    private func incrementQuantity(at index: Int) {
        guard index < items.count else { return }
        var item = items[index]
        let step = (item.detectedUnit.lowercased() == "g" || item.detectedUnit.lowercased() == "ml") ? 50.0 : 1.0
        item.detectedQuantity += step
        recalculateItem(&item)
        items[index] = item
        hapticTrigger += 1
    }

    private func decrementQuantity(at index: Int) {
        guard index < items.count else { return }
        var item = items[index]
        let step = (item.detectedUnit.lowercased() == "g" || item.detectedUnit.lowercased() == "ml") ? 50.0 : 1.0
        guard item.detectedQuantity > step else { return }
        item.detectedQuantity -= step
        recalculateItem(&item)
        items[index] = item
        hapticTrigger += 1
    }

    private func recalculateItem(_ item: inout ParsedMealItem) {
        if let portion = item.matchedPortion, let food = item.food {
            item.calculatedWeightGrams = portion.gramWeight * item.detectedQuantity
            item.macros = searchEngine.calculateMacros(for: food, portion: portion, quantity: item.detectedQuantity)
        } else if let food = item.food {
            item.calculatedWeightGrams = item.detectedQuantity
            item.macros = searchEngine.calculateMacros(for: food, amount: item.calculatedWeightGrams)
        }
    }
}
