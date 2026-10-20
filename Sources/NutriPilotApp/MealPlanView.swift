import SwiftUI
import NutriPilotCore

public struct MealPlanView: View {
    public var targetCalories: Double
    public var mealStore: MealStore
    public var waterStore: WaterStore
    public var profileStore: ProfileStore

    @State private var selectedSegment: PlanViewSegment = .plan
    @State private var planMeals: [PlannedMeal] = PlannedMeal.samplePlan
    @State private var groceryCategories: [GroceryCategory] = GroceryCategory.sampleCategories
    @State private var selectedItemForSubstitution: PlannedFoodItem?
    @State private var assistantMessages: [AssistantChatMessage] = AssistantChatMessage.sampleMessages
    @State private var assistantInput: String = ""
    @State private var hapticTrigger: Int = 0

    public init(
        targetCalories: Double = 2500,
        mealStore: MealStore = .shared,
        waterStore: WaterStore = .shared,
        profileStore: ProfileStore = .shared
    ) {
        self.targetCalories = targetCalories
        self.mealStore = mealStore
        self.waterStore = waterStore
        self.profileStore = profileStore
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header com Segment Control (3 Modos)
                segmentPickerHeader
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.appCardBackground)

                Divider()

                // Conteúdo do Segmento Ativo
                Group {
                    switch selectedSegment {
                    case .plan:
                        dailyPlanView
                    case .groceries:
                        groceriesView
                    case .assistant:
                        succinctAssistantView
                    }
                }
            }
            .navigationTitle("Plano Alimentar")
            .background(Color.appBackground)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .sheet(item: $selectedItemForSubstitution) { item in
                FoodSubstitutionSheet(baseItem: item) { substitute in
                    applySubstitution(baseItem: item, with: substitute)
                }
            }
        }
    }

    // MARK: - 1. Segment Picker Header

    private var segmentPickerHeader: some View {
        Picker("Visualização", selection: $selectedSegment) {
            ForEach(PlanViewSegment.allCases) { segment in
                Label(segment.rawValue, systemImage: segment.icon)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 2. Plano Diário (Cards por Refeição com Botão 'Substituir')

    private var dailyPlanView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Card de Resumo de Metas do Plano
                planSummaryHeader

                // Lista de Refeições Planejadas
                ForEach(planMeals) { meal in
                    mealCardView(meal: meal)
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
    }

    private var planSummaryHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLANO NUTRICIONAL CALCULADO")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("\(Int(targetCalories)) kcal planejadas")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        planMeals = PlannedMeal.samplePlan
                        hapticTrigger += 1
                    }
                } label: {
                    Label("Regenerar", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                macroTargetBadge(title: "Proteína", value: "190g", color: .blue)
                macroTargetBadge(title: "Carbos", value: "260g", color: .green)
                macroTargetBadge(title: "Gorduras", value: "65g", color: .purple)
                macroTargetBadge(title: "Fibras", value: "32g", color: .brown)
            }
        }
        .padding(14)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }

    private func macroTargetBadge(title: String, value: String, color: Color) -> some View {
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

    private func mealCardView(meal: PlannedMeal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.mealType.rawValue)
                        .font(.headline)
                    Text("\(meal.suggestedTime) • \(meal.percentageOfDaily)% do dia")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(meal.totalCalories)) kcal")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                    Text("P: \(Int(meal.totalProtein))g | C: \(Int(meal.totalCarbs))g | G: \(Int(meal.totalFat))g")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(spacing: 8) {
                ForEach(meal.items) { item in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                            Text("\(item.portionDescription) (\(Int(item.weightGrams))g) • \(Int(item.calories)) kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            selectedItemForSubstitution = item
                            hapticTrigger += 1
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.2.squarepath")
                                Text("Substituir")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }

    // MARK: - 3. Lista de Compras (Hortifrúti, Carnes, Mercearia, Laticínios)

    private var groceriesView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Barra de Progresso do Mercado
                groceryProgressBar

                // Categorias por Departamento
                ForEach(groceryCategories.indices, id: \.self) { catIdx in
                    let category = groceryCategories[catIdx]
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.green)
                            Text(category.name.uppercased())
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(category.items.filter(\.isChecked).count)/\(category.items.count)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 8) {
                            ForEach(category.items.indices, id: \.self) { itemIdx in
                                let item = category.items[itemIdx]
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        groceryCategories[catIdx].items[itemIdx].isChecked.toggle()
                                        hapticTrigger += 1
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(item.isChecked ? .green : .secondary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.subheadline.weight(item.isChecked ? .regular : .semibold))
                                                .strikethrough(item.isChecked)
                                                .foregroundColor(item.isChecked ? .secondary : .primary)
                                            Text(item.quantity)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.appCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
    }

    private var groceryProgressBar: some View {
        let totalItems = groceryCategories.reduce(0) { $0 + $1.items.count }
        let checkedItems = groceryCategories.reduce(0) { $0 + $1.items.filter(\.isChecked).count }
        let progress = totalItems > 0 ? Double(checkedItems) / Double(totalItems) : 0.0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progresso das Compras")
                    .font(.headline)
                Spacer()
                Text("\(checkedItems) de \(totalItems) itens no carrinho")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }

            ProgressView(value: progress)
                .tint(.green)

            HStack {
                Text(String(format: "%.0f%% concluído", progress * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Desmarcar Todos") {
                    for i in groceryCategories.indices {
                        for j in groceryCategories[i].items.indices {
                            groceryCategories[i].items[j].isChecked = false
                        }
                    }
                    hapticTrigger += 1
                }
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 4. Assistente Sucinto (Respostas em até 4 Linhas com Próxima Ação)

    private var succinctAssistantView: some View {
        VStack(spacing: 0) {
            // Conversas anteriores
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        // Chips de Perguntas Rápidas Prontas
                        assistantPromptChips

                        // Balões de Mensagem
                        ForEach(assistantMessages) { msg in
                            assistantMessageBubble(msg: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: assistantMessages.count) { _, _ in
                    if let last = assistantMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Barra de Envio
            HStack(spacing: 10) {
                TextField("Pergunte ao assistente sucinto...", text: $assistantInput)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        submitAssistantPrompt(assistantInput)
                    }

                Button {
                    submitAssistantPrompt(assistantInput)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(assistantInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .green)
                }
                .disabled(assistantInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(Color.appCardBackground)
        }
    }

    private var assistantPromptChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text("PERGUNTAS FREQUENTES (1 TOQUE)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    assistantChip(text: "Como está meu dia?")
                    assistantChip(text: "O que comer no jantar?")
                    assistantChip(text: "Vou comer pizza hoje")
                    assistantChip(text: "Lanche proteico rápido")
                }
            }
        }
        .padding(12)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func assistantChip(text: String) -> some View {
        Button {
            submitAssistantPrompt(text)
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
                Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func assistantMessageBubble(msg: AssistantChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer() }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 6) {
                if !msg.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("NutriPilot AI (Máx 4 linhas)")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                }

                Text(msg.text)
                    .font(.subheadline)
                    .foregroundColor(msg.isUser ? .white : .primary)
                    .lineLimit(msg.isUser ? nil : 4) // Regra estrita de até 4 linhas

                if let nextAction = msg.nextAction {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                        Text("Próxima Ação: \(nextAction)")
                            .font(.caption2.bold())
                            .foregroundColor(msg.isUser ? .white.opacity(0.9) : .green)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(msg.isUser ? Color.green : Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)

            if !msg.isUser { Spacer() }
        }
    }

    private func submitAssistantPrompt(_ prompt: String) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // Mensagem do usuário
        assistantMessages.append(AssistantChatMessage(text: clean, isUser: true))
        assistantInput = ""
        hapticTrigger += 1

        // Geração sucinta contextual de até 4 linhas
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let reply = generateSuccinctReply(for: clean)
            assistantMessages.append(reply)
            hapticTrigger += 1
        }
    }

    private func generateSuccinctReply(for prompt: String) -> AssistantChatMessage {
        let lower = prompt.lowercased()
        let todayTotals = mealStore.dailyTotals(for: Date())
        let waterTotal = waterStore.totalWater(for: Date())
        let targetProt = profileStore.currentTarget?.proteinGrams ?? 180.0
        let remainingProt = max(0, targetProt - todayTotals.proteinGrams)

        if lower.contains("como está") || lower.contains("meu dia") {
            return AssistantChatMessage(
                text: "Você consumiu \(Int(todayTotals.calories)) kcal (\(Int(todayTotals.proteinGrams))g proteína) e \(Int(waterTotal)) ml de água.\nSeu ritmo está dentro do planejado para o objetivo de recomposição.\nFaltam \(Int(remainingProt))g de proteína para fechar a meta do dia.",
                isUser: false,
                nextAction: "Planejar jantar proteico e beber 400ml de água"
            )
        } else if lower.contains("jantar") || lower.contains("comer") {
            let chicken = Int((remainingProt / 0.315).rounded())
            return AssistantChatMessage(
                text: "Para fechar sua meta com precisão, monte seu prato com:\n• \(chicken)g de filé de frango grelhado ou 150g de patinho moído;\n• 120g de arroz ou batata e salada verde à vontade com azeite.",
                isUser: false,
                nextAction: "Registrar o jantar com o botão de texto rápido"
            )
        } else if lower.contains("pizza") {
            return AssistantChatMessage(
                text: "Sem problemas! Limite a 2 fatias finas à noite.\nReduza os carboidratos da tarde e garanta sua proteína mais cedo.\nBeba 500ml extras de água para combater a retenção de sódio.",
                isUser: false,
                nextAction: "Fazer lanche da tarde só com whey e água"
            )
        } else {
            return AssistantChatMessage(
                text: "Opção rápida: 1 scoop de Whey (30g) + 1 banana média ou 3 ovos mexidos.\nFornece 25g a 30g de proteína de alto valor biológico em menos de 3 minutos.\nIdeal para manter o ritmo sem ultrapassar a meta de gordura.",
                isUser: false,
                nextAction: "Consumir a proteína agora para manter o pacing"
            )
        }
    }

    private func applySubstitution(baseItem: PlannedFoodItem, with substitute: PlannedFoodItem) {
        for mIdx in planMeals.indices {
            if let itemIdx = planMeals[mIdx].items.firstIndex(where: { $0.id == baseItem.id }) {
                planMeals[mIdx].items[itemIdx] = substitute
                hapticTrigger += 1
                break
            }
        }
    }
}

// MARK: - Modelos de Dados da Tela

public enum PlanViewSegment: String, CaseIterable, Identifiable {
    case plan = "Plano Diário"
    case groceries = "Lista de Compras"
    case assistant = "Assistente Sucinto"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .plan: return "fork.knife"
        case .groceries: return "cart.fill"
        case .assistant: return "sparkles"
        }
    }
}

public struct PlannedFoodItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var portionDescription: String
    public var weightGrams: Double
    public var calories: Double
    public var proteinGrams: Double
    public var carbsGrams: Double
    public var fatGrams: Double

    public init(
        id: UUID = UUID(),
        name: String,
        portionDescription: String,
        weightGrams: Double,
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double
    ) {
        self.id = id
        self.name = name
        self.portionDescription = portionDescription
        self.weightGrams = weightGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
    }
}

public struct PlannedMeal: Identifiable, Sendable {
    public let id: UUID = UUID()
    public var mealType: MealType
    public var suggestedTime: String
    public var percentageOfDaily: Int
    public var items: [PlannedFoodItem]

    public var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    public var totalProtein: Double { items.reduce(0) { $0 + $1.proteinGrams } }
    public var totalCarbs: Double { items.reduce(0) { $0 + $1.carbsGrams } }
    public var totalFat: Double { items.reduce(0) { $0 + $1.fatGrams } }

    public static var samplePlan: [PlannedMeal] {
        [
            PlannedMeal(
                mealType: .breakfast,
                suggestedTime: "07:30",
                percentageOfDaily: 25,
                items: [
                    PlannedFoodItem(name: "Ovo de galinha cozido/mexido", portionDescription: "3 unidades", weightGrams: 150, calories: 219, proteinGrams: 20, carbsGrams: 1, fatGrams: 14),
                    PlannedFoodItem(name: "Pão francês", portionDescription: "1 unidade", weightGrams: 50, calories: 150, proteinGrams: 4, carbsGrams: 29, fatGrams: 1),
                    PlannedFoodItem(name: "Café sem açúcar", portionDescription: "1 xícara", weightGrams: 100, calories: 2, proteinGrams: 0, carbsGrams: 0, fatGrams: 0)
                ]
            ),
            PlannedMeal(
                mealType: .lunch,
                suggestedTime: "12:30",
                percentageOfDaily: 35,
                items: [
                    PlannedFoodItem(name: "Peito de frango grelhado", portionDescription: "1 filé grande", weightGrams: 160, calories: 260, proteinGrams: 50, carbsGrams: 0, fatGrams: 5),
                    PlannedFoodItem(name: "Arroz branco cozido", portionDescription: "4 colheres de sopa", weightGrams: 140, calories: 180, proteinGrams: 3, carbsGrams: 39, fatGrams: 0),
                    PlannedFoodItem(name: "Feijão carioca cozido", portionDescription: "1 concha média", weightGrams: 130, calories: 99, proteinGrams: 6, carbsGrams: 18, fatGrams: 1)
                ]
            ),
            PlannedMeal(
                mealType: .afternoonSnack,
                suggestedTime: "16:00",
                percentageOfDaily: 15,
                items: [
                    PlannedFoodItem(name: "Whey Protein Concentrado", portionDescription: "1 scoop", weightGrams: 30, calories: 120, proteinGrams: 24, carbsGrams: 2, fatGrams: 1.5),
                    PlannedFoodItem(name: "Banana prata", portionDescription: "1 unidade média", weightGrams: 90, calories: 88, proteinGrams: 1, carbsGrams: 23, fatGrams: 0)
                ]
            ),
            PlannedMeal(
                mealType: .dinner,
                suggestedTime: "20:00",
                percentageOfDaily: 25,
                items: [
                    PlannedFoodItem(name: "Patinho bovino moído grelhado", portionDescription: "1 porção média", weightGrams: 150, calories: 290, proteinGrams: 42, carbsGrams: 0, fatGrams: 12),
                    PlannedFoodItem(name: "Batata inglesa cozida", portionDescription: "2 unidades médias", weightGrams: 180, calories: 144, proteinGrams: 3, carbsGrams: 32, fatGrams: 0)
                ]
            )
        ]
    }
}

public struct GroceryItem: Identifiable, Sendable {
    public let id: UUID = UUID()
    public var name: String
    public var quantity: String
    public var isChecked: Bool = false
}

public struct GroceryCategory: Identifiable, Sendable {
    public let id: UUID = UUID()
    public var name: String
    public var icon: String
    public var items: [GroceryItem]

    public static var sampleCategories: [GroceryCategory] {
        [
            GroceryCategory(
                name: "Hortifrúti",
                icon: "carrot.fill",
                items: [
                    GroceryItem(name: "Bananas prata", quantity: "1 dúzia (1 kg)"),
                    GroceryItem(name: "Batata inglesa", quantity: "1.5 kg"),
                    GroceryItem(name: "Tomate e alface", quantity: "1 maço + 4 unid")
                ]
            ),
            GroceryCategory(
                name: "Carnes & Ovos",
                icon: "fork.knife",
                items: [
                    GroceryItem(name: "Peito de frango filé", quantity: "1.2 kg"),
                    GroceryItem(name: "Patinho bovino moído", quantity: "1.0 kg"),
                    GroceryItem(name: "Ovos brancos", quantity: "2 dúzias (24 unid)")
                ]
            ),
            GroceryCategory(
                name: "Mercearia",
                icon: "bag.fill",
                items: [
                    GroceryItem(name: "Arroz branco ou integral", quantity: "1 pacote (1 kg)"),
                    GroceryItem(name: "Feijão carioca", quantity: "1 pacote (1 kg)"),
                    GroceryItem(name: "Pão francês ou integral", quantity: "1 pacote")
                ]
            ),
            GroceryCategory(
                name: "Laticínios & Suplementos",
                icon: "cup.and.saucer.fill",
                items: [
                    GroceryItem(name: "Whey Protein Concentrado", quantity: "1 pote (900g)")
                ]
            )
        ]
    }
}

public struct AssistantChatMessage: Identifiable, Sendable {
    public let id: UUID = UUID()
    public var text: String
    public var isUser: Bool
    public var nextAction: String?

    public static var sampleMessages: [AssistantChatMessage] {
        [
            AssistantChatMessage(
                text: "Olá! Sou seu assistente de bolso NutriPilot.\nRespondo qualquer dúvida em no máximo 4 linhas diretas.\nSeu foco hoje é bater a meta de proteínas sem estourar calorias.",
                isUser: false,
                nextAction: "Consultar seu status de hoje ou conferir o plano"
            )
        ]
    }
}

// MARK: - Sheet de Substituição Equivalente (Dietbox / Avanutri Style)

private struct FoodSubstitutionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let baseItem: PlannedFoodItem
    let onConfirm: (PlannedFoodItem) -> Void

    @State private var selectedIndex: Int = 0

    private var substitutes: [PlannedFoodItem] {
        generateSubstitutes(for: baseItem)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Item Original
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ALIMENTO ORIGINAL NO PLANO")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(baseItem.name)
                                    .font(.headline)
                                Text("\(baseItem.portionDescription) (\(Int(baseItem.weightGrams))g)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(baseItem.calories)) kcal")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text("P: \(Int(baseItem.proteinGrams))g | C: \(Int(baseItem.carbsGrams))g")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Equivalências Calculadas (Dietbox/Avanutri)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("SUBSTITUTOS EQUIVALENTES CALCULADOS")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Mesmos macronutrientes")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }

                        VStack(spacing: 8) {
                            ForEach(substitutes.indices, id: \.self) { idx in
                                let sub = substitutes[idx]
                                Button {
                                    selectedIndex = idx
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sub.name)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.primary)
                                            Text("\(sub.portionDescription) (\(Int(sub.weightGrams))g)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(Int(sub.calories)) kcal")
                                                .font(.subheadline.bold())
                                                .foregroundColor(.orange)
                                            Text("P: \(Int(sub.proteinGrams))g | C: \(Int(sub.carbsGrams))g")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        Image(systemName: selectedIndex == idx ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedIndex == idx ? .green : .secondary)
                                            .padding(.leading, 6)
                                    }
                                    .padding(12)
                                    .background(Color.appCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedIndex == idx ? Color.green : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Botão de Confirmação
                    Button {
                        if selectedIndex < substitutes.count {
                            onConfirm(substitutes[selectedIndex])
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.2.squarepath")
                            Text("Confirmar Substituição no Plano")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .navigationTitle("Substituir Alimento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .background(Color.appBackground)
        }
        .presentationDetents([.medium, .large])
    }

    private func generateSubstitutes(for item: PlannedFoodItem) -> [PlannedFoodItem] {
        let nameLower = item.name.lowercased()

        if nameLower.contains("frango") {
            return [
                PlannedFoodItem(name: "Patinho bovino grelhado", portionDescription: "1 bife médio", weightGrams: item.weightGrams * 0.95, calories: 240, proteinGrams: 48, carbsGrams: 0, fatGrams: 6),
                PlannedFoodItem(name: "Tilápia grelhada", portionDescription: "1 filé grande", weightGrams: item.weightGrams * 1.2, calories: 230, proteinGrams: 49, carbsGrams: 0, fatGrams: 3),
                PlannedFoodItem(name: "Ovos inteiros cozidos", portionDescription: "4 unidades", weightGrams: 200, calories: 290, proteinGrams: 26, carbsGrams: 1, fatGrams: 19)
            ]
        } else if nameLower.contains("arroz") {
            return [
                PlannedFoodItem(name: "Batata doce cozida", portionDescription: "1 unidade grande", weightGrams: item.weightGrams * 1.35, calories: 175, proteinGrams: 2, carbsGrams: 40, fatGrams: 0),
                PlannedFoodItem(name: "Mandioca (aipim) cozida", portionDescription: "2 pedaços médios", weightGrams: item.weightGrams * 0.9, calories: 185, proteinGrams: 2, carbsGrams: 41, fatGrams: 0),
                PlannedFoodItem(name: "Macarrão cozido", portionDescription: "1 xícara", weightGrams: item.weightGrams * 0.95, calories: 180, proteinGrams: 6, carbsGrams: 37, fatGrams: 1)
            ]
        } else if nameLower.contains("pão") {
            return [
                PlannedFoodItem(name: "Tapioca (goma hidratada)", portionDescription: "3 colheres de sopa", weightGrams: 60, calories: 145, proteinGrams: 0, carbsGrams: 35, fatGrams: 0),
                PlannedFoodItem(name: "Aveia em flocos finos", portionDescription: "4 colheres de sopa", weightGrams: 40, calories: 155, proteinGrams: 6, carbsGrams: 26, fatGrams: 3),
                PlannedFoodItem(name: "Cuscuz de milho cozido", portionDescription: "1 fatia média", weightGrams: 100, calories: 115, proteinGrams: 2, carbsGrams: 25, fatGrams: 0)
            ]
        } else {
            return [
                PlannedFoodItem(name: "Opção Equilibrada 1", portionDescription: "1 porção equivalente", weightGrams: item.weightGrams, calories: item.calories, proteinGrams: item.proteinGrams, carbsGrams: item.carbsGrams, fatGrams: item.fatGrams),
                PlannedFoodItem(name: "Opção Equilibrada 2", portionDescription: "1 porção equivalente", weightGrams: item.weightGrams * 1.1, calories: item.calories, proteinGrams: item.proteinGrams, carbsGrams: item.carbsGrams, fatGrams: item.fatGrams)
            ]
        }
    }
}
