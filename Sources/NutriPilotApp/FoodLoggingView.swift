import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

public struct FoodLoggingView: View {
    public var mealStore: MealStore
    public var searchEngine: FoodSearchEngine
    public var parserEngine: MealParserEngine

    @State private var selectedMeal: MealType = .lunch
    @State private var searchQuery: String = ""
    @State private var naturalLanguageInput: String = ""
    @State private var parsedMealToConfirm: ParsedMeal?
    @State private var selectedFoodForPortion: FoodItem?
    @State private var hapticTrigger: Int = 0

    public init(
        mealStore: MealStore = .shared,
        searchEngine: FoodSearchEngine = .shared,
        parserEngine: MealParserEngine = .shared
    ) {
        self.mealStore = mealStore
        self.searchEngine = searchEngine
        self.parserEngine = parserEngine
    }

    private var searchResults: [FoodItem] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Array(TBCAFoodDatabase.foods.prefix(12))
        } else {
            return searchEngine.search(query: searchQuery, limit: 25)
        }
    }

    private var todayMeals: [MealLog] {
        mealStore.meals(for: Date()).reversed()
    }

    private var todayTotals: DayNutritionTotals {
        mealStore.dailyTotals(for: Date())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Resumo Nutricional Rápido do Dia
                    dailyMacroBanner

                    // Registro Rápido (Texto ou Voz / NLP)
                    quickTextOrVoiceSection

                    // Seletor de Refeição Ativa
                    mealTypePicker

                    // Seção de Favoritos / Recorrentes (1 Toque)
                    favoritesSection

                    // Barra de Busca TBCA em Tempo Real
                    searchBarView

                    // Lista de Alimentos Encontrados / Sugestões
                    foodResultsSection

                    // Refeições Já Registradas Hoje
                    todayRegisteredMealsSection
                }
                .padding(.bottom, 28)
            }
            .navigationTitle("Refeições")
            .background(Color.appBackground)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .sheet(item: $parsedMealToConfirm) { meal in
                MealParserConfirmationSheet(
                    parsedMeal: meal,
                    defaultMealType: selectedMeal,
                    mealStore: mealStore,
                    searchEngine: searchEngine
                ) {
                    naturalLanguageInput = ""
                }
            }
            .sheet(item: $selectedFoodForPortion) { food in
                FoodPortionSheet(
                    food: food,
                    mealType: selectedMeal,
                    searchEngine: searchEngine
                ) { mealLogItem, targetMeal in
                    addMealItem(mealLogItem, to: targetMeal)
                }
            }
        }
    }

    // MARK: - Subviews

    private var dailyMacroBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Text("CONSUMO TOTAL HOJE")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(todayTotals.calories)) kcal")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            HStack(spacing: 12) {
                macroPill(title: "Proteína", value: "\(Int(todayTotals.proteinGrams))g", color: .blue)
                macroPill(title: "Carboidratos", value: "\(Int(todayTotals.carbsGrams))g", color: .green)
                macroPill(title: "Gorduras", value: "\(Int(todayTotals.fatGrams))g", color: .purple)
                macroPill(title: "Fibras", value: "\(Int(todayTotals.fiberGrams))g", color: .brown)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var quickTextOrVoiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("REGISTRO RÁPIDO (TEXTO OU VOZ)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Campo de Entrada com Botão de Ação Rápida
            HStack(spacing: 8) {
                TextField("Ex: 2 filés de frango e 4 colheres de arroz", text: $naturalLanguageInput)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        analyzeMeal(text: naturalLanguageInput)
                    }

                if !naturalLanguageInput.isEmpty {
                    Button {
                        naturalLanguageInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    analyzeMeal(text: naturalLanguageInput)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Analisar")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.green)
                    .clipShape(Capsule())
                }
                .disabled(naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Chips com Exemplos Tocáveis Rápidos
            VStack(alignment: .leading, spacing: 6) {
                Text("Exemplos prontos (1 toque para testar):")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        exampleChip(text: "2 filés de frango e 4 colheres de arroz")
                        exampleChip(text: "1 scoop de whey e 1 banana")
                        exampleChip(text: "3 ovos mexidos e 2 fatias de pão")
                        exampleChip(text: "1 concha de feijão e 1 bife de patinho")
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
        .padding(.horizontal)
    }

    private func exampleChip(text: String) -> some View {
        Button {
            naturalLanguageInput = text
            analyzeMeal(text: text)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text(text)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.appBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func analyzeMeal(text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let parsed = parserEngine.parse(text: clean)
        parsedMealToConfirm = parsed
        hapticTrigger += 1
    }

    private func macroPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mealTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MealType.allCases, id: \.self) { meal in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMeal = meal
                            hapticTrigger += 1
                        }
                    } label: {
                        Text(meal.rawValue)
                            .font(.subheadline.weight(selectedMeal == meal ? .bold : .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedMeal == meal ? Color.green : Color.appCardBackground)
                            .foregroundColor(selectedMeal == meal ? .white : .primary)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(selectedMeal == meal ? 0.08 : 0.02), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FAVORITOS & RECORRENTES (1 TOQUE)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if mealStore.favoriteMeals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        sampleFavoriteButton(
                            name: "Frango + Arroz + Feijão",
                            mealType: .lunch,
                            items: [
                                MealLogItem(name: "Peito de frango grelhado (1 filé médio)", quantity: 100, unit: "g", calories: 163, proteinGrams: 31.5, carbsGrams: 0, fatGrams: 3.2),
                                MealLogItem(name: "Arroz branco cozido (4 colheres)", quantity: 100, unit: "g", calories: 128, proteinGrams: 2.5, carbsGrams: 28.1, fatGrams: 0.2),
                                MealLogItem(name: "Feijão carioca (1 concha média)", quantity: 130, unit: "g", calories: 99, proteinGrams: 6.2, carbsGrams: 17.7, fatGrams: 0.7)
                            ]
                        )

                        sampleFavoriteButton(
                            name: "Ovos Mexidos + Aveia",
                            mealType: .breakfast,
                            items: [
                                MealLogItem(name: "Ovo de galinha cozido/mexido (2 unid)", quantity: 100, unit: "g", calories: 146, proteinGrams: 13.3, carbsGrams: 0.6, fatGrams: 9.5),
                                MealLogItem(name: "Aveia em flocos (2 colheres)", quantity: 30, unit: "g", calories: 118, proteinGrams: 4.2, carbsGrams: 20.0, fatGrams: 2.6)
                            ]
                        )
                    }
                    .padding(.horizontal)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(mealStore.favoriteMeals) { fav in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    _ = mealStore.logMeal(from: fav, overrideMealType: selectedMeal)
                                    hapticTrigger += 1
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(fav.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                        Text("\(Int(fav.totalCalories)) kcal • \(fav.items.count) itens")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.appCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func sampleFavoriteButton(name: String, mealType: MealType, items: [MealLogItem]) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                let meal = MealLog(
                    date: Date(),
                    mealType: selectedMeal,
                    loggedAt: Date(),
                    inputMethod: .favorite,
                    rawInput: name,
                    items: items,
                    confirmedByUser: true
                )
                mealStore.addMeal(meal)
                hapticTrigger += 1
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    let totalKcal = Int(items.reduce(0) { $0 + $1.calories })
                    Text("\(totalKcal) kcal • Sugestão rápida")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.green)

            TextField("Buscar alimento TBCA (ex: arroz, frango, feijão...)", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var foodResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(searchQuery.isEmpty ? "ALIMENTOS BRASILEIROS SUGERIDOS (TBCA)" : "RESULTADOS DA BUSCA (\(searchResults.count))")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            if searchResults.isEmpty {
                Text("Nenhum alimento encontrado para \"\(searchQuery)\".")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(searchResults) { food in
                        Button {
                            selectedFoodForPortion = food
                            hapticTrigger += 1
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(food.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)

                                    HStack(spacing: 8) {
                                        Text("\(Int(food.calories)) kcal")
                                            .font(.caption.bold())
                                            .foregroundColor(.orange)

                                        Text("P: \(String(format: "%.1f", food.proteinGrams))g")
                                            .font(.caption)
                                            .foregroundColor(.blue)

                                        Text("C: \(String(format: "%.1f", food.carbsGrams))g")
                                            .font(.caption)
                                            .foregroundColor(.green)

                                        Text("G: \(String(format: "%.1f", food.fatGrams))g")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }

                                    if !food.portions.isEmpty {
                                        Text("Medidas: \(food.portions.map(\.name).joined(separator: ", "))")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.appCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var todayRegisteredMealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REGISTRADOS HOJE (\(todayMeals.count))")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if todayMeals.isEmpty {
                Text("Nenhuma refeição registrada ainda hoje.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(todayMeals) { meal in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(meal.mealType.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(meal.totalCalories)) kcal")
                                    .font(.headline)
                                    .foregroundColor(.orange)

                                Button {
                                    withAnimation {
                                        _ = mealStore.saveMealAsFavorite(meal)
                                        hapticTrigger += 1
                                    }
                                } label: {
                                    Image(systemName: "star")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                                .buttonStyle(.borderless)
                                .padding(.leading, 6)
                                .help("Salvar como favorito")

                                Button {
                                    withAnimation {
                                        mealStore.deleteMeal(id: meal.id)
                                        hapticTrigger += 1
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                                .buttonStyle(.borderless)
                                .padding(.leading, 6)
                            }

                            ForEach(meal.items) { item in
                                HStack {
                                    Text("• \(item.name)")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(Int(item.quantity))\(item.unit) | \(Int(item.calories)) kcal")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack(spacing: 10) {
                                Text("P: \(Int(meal.totalProtein))g")
                                    .font(.caption2.bold())
                                    .foregroundColor(.blue)
                                Text("C: \(Int(meal.totalCarbs))g")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                                Text("G: \(Int(meal.totalFat))g")
                                    .font(.caption2.bold())
                                    .foregroundColor(.purple)
                                Spacer()
                                Text(timeFormatter.string(from: meal.loggedAt))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func addMealItem(_ item: MealLogItem, to mealType: MealType) {
        let today = Date()

        // Verifica se já existe uma refeição deste tipo hoje para anexar o item, ou cria uma nova
        if let existingMeal = mealStore.meals(for: today, type: mealType).first {
            mealStore.addItem(to: existingMeal.id, item: item)
        } else {
            let newMeal = MealLog(
                date: today,
                mealType: mealType,
                loggedAt: today,
                inputMethod: .search,
                rawInput: item.name,
                items: [item],
                confirmedByUser: true
            )
            mealStore.addMeal(newMeal)
        }
        hapticTrigger += 1
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

// MARK: - Sheet de Seleção de Porções e Medidas Caseiras

private struct FoodPortionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem
    @State var mealType: MealType
    let searchEngine: FoodSearchEngine
    let onConfirm: (MealLogItem, MealType) -> Void

    @State private var usePortionMode: Bool = true
    @State private var selectedPortionIndex: Int = 0
    @State private var portionMultiplier: Double = 1.0
    @State private var customGrams: Double = 100.0

    init(food: FoodItem, mealType: MealType, searchEngine: FoodSearchEngine, onConfirm: @escaping (MealLogItem, MealType) -> Void) {
        self.food = food
        self._mealType = State(initialValue: mealType)
        self.searchEngine = searchEngine
        self.onConfirm = onConfirm
        self._usePortionMode = State(initialValue: !food.portions.isEmpty)
        if let firstPortion = food.portions.first {
            self._customGrams = State(initialValue: firstPortion.gramWeight)
        }
    }

    private var currentMacros: MacroBreakdown {
        if usePortionMode, !food.portions.isEmpty {
            let portion = food.portions[selectedPortionIndex]
            return searchEngine.calculateMacros(for: food, portion: portion, quantity: portionMultiplier)
        } else {
            return searchEngine.calculateMacros(for: food, amount: customGrams)
        }
    }

    private var currentWeightGrams: Double {
        if usePortionMode, !food.portions.isEmpty {
            let portion = food.portions[selectedPortionIndex]
            return portion.gramWeight * portionMultiplier
        } else {
            return customGrams
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Cabeçalho do Alimento
                    VStack(spacing: 6) {
                        Text(food.name)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)

                        Text("Fonte: \(food.source)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)

                    // Seletor de Refeição Destino
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Adicionar em:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        Picker("Refeição", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    // Alternador: Medida Caseira vs Gramas Diretos
                    if !food.portions.isEmpty {
                        Picker("Modo", selection: $usePortionMode) {
                            Text("Medidas Caseiras").tag(true)
                            Text("Gramas exatos").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }

                    // Controle de Quantidade
                    if usePortionMode && !food.portions.isEmpty {
                        portionSelectorSection
                    } else {
                        gramsSelectorSection
                    }

                    // Card de Macros Calculados em Tempo Real
                    calculatedMacrosCard

                    // Botão de Confirmação em 1 Toque
                    Button {
                        let item: MealLogItem
                        if usePortionMode && !food.portions.isEmpty {
                            let portion = food.portions[selectedPortionIndex]
                            item = searchEngine.createMealLogItem(from: food, portion: portion, quantity: portionMultiplier)
                        } else {
                            item = searchEngine.createMealLogItem(from: food, amount: customGrams)
                        }
                        onConfirm(item, mealType)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Registrar \(Int(currentMacros.calories)) kcal no \(mealType.rawValue)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.green.opacity(0.3), radius: 6, y: 3)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Definir Porção")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .background(Color.appBackground)
        }
        .presentationDetents([.medium, .large])
    }

    private var portionSelectorSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                ForEach(food.portions.indices, id: \.self) { idx in
                    let portion = food.portions[idx]
                    Button {
                        selectedPortionIndex = idx
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(portion.name)
                                    .font(.subheadline.bold())
                                if let desc = portion.description {
                                    Text(desc)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(Int(portion.gramWeight))g")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            Image(systemName: selectedPortionIndex == idx ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedPortionIndex == idx ? .green : .secondary)
                        }
                        .padding()
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedPortionIndex == idx ? Color.green : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            // Multiplicador da porção
            HStack {
                Text("Quantidade:")
                    .font(.subheadline)
                Spacer()
                Button("-") {
                    if portionMultiplier > 0.5 {
                        portionMultiplier -= 0.5
                    }
                }
                .buttonStyle(.bordered)

                Text(String(format: "%.1fx", portionMultiplier))
                    .font(.headline)
                    .frame(minWidth: 44)

                Button("+") {
                    portionMultiplier += 0.5
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
    }

    private var gramsSelectorSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Peso total:")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(customGrams)) g")
                    .font(.title2.bold())
                    .foregroundColor(.green)
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                quickWeightButton(grams: 50)
                quickWeightButton(grams: 100)
                quickWeightButton(grams: 150)
                quickWeightButton(grams: 200)
                quickWeightButton(grams: 300)
            }
            .padding(.horizontal)

            Stepper("Ajuste fino: \(Int(customGrams))g", value: $customGrams, in: 5...1000, step: 10)
                .padding(.horizontal)
        }
    }

    private func quickWeightButton(grams: Double) -> some View {
        Button("\(Int(grams))g") {
            customGrams = grams
        }
        .buttonStyle(.bordered)
        .tint(customGrams == grams ? .green : .secondary)
    }

    private var calculatedMacrosCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("VALORES NUTRICIONAIS (\(Int(currentWeightGrams))g)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(currentMacros.calories)) kcal")
                    .font(.title3.bold())
                    .foregroundColor(.orange)
            }

            Divider()

            HStack(spacing: 12) {
                macroValueColumn(title: "Proteína", value: String(format: "%.1f", currentMacros.proteinGrams), unit: "g", color: .blue)
                macroValueColumn(title: "Carboidratos", value: String(format: "%.1f", currentMacros.carbsGrams), unit: "g", color: .green)
                macroValueColumn(title: "Gorduras", value: String(format: "%.1f", currentMacros.fatGrams), unit: "g", color: .purple)
                macroValueColumn(title: "Fibras", value: String(format: "%.1f", currentMacros.fiberGrams), unit: "g", color: .brown)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func macroValueColumn(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
