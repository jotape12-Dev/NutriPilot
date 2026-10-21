import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

public struct MealPlanView: View {
    public var targetCalories: Double
    public var mealStore: MealStore
    public var waterStore: WaterStore
    public var profileStore: ProfileStore
    public var planStore: MealPlanStore

    @State private var selectedSegment: PlanViewSegment = .plan
    @State private var itemToSubstitute: SubstitutionTarget?
    @State private var assistantMessages: [AssistantChatMessage] = [
        AssistantChatMessage(
            text: "Sou o assistente de bolso NutriPilot.\nRespondo qualquer dúvida em no máximo 4 linhas diretas.\nSeu foco hoje é bater a meta de proteínas sem estourar calorias.",
            isUser: false,
            nextAction: "Consultar seu status de hoje ou conferir o plano"
        )
    ]
    @State private var assistantInput: String = ""
    @State private var hapticTrigger: Int = 0

    public init(
        targetCalories: Double = 0,
        mealStore: MealStore = .shared,
        waterStore: WaterStore = .shared,
        profileStore: ProfileStore = .shared,
        planStore: MealPlanStore = .shared
    ) {
        self.targetCalories = targetCalories
        self.mealStore = mealStore
        self.waterStore = waterStore
        self.profileStore = profileStore
        self.planStore = planStore
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
            .sheet(item: $itemToSubstitute) { target in
                FoodSubstitutionSheet(target: target) { newItem in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        planStore.replaceItem(mealId: target.mealId, oldItemId: target.item.id, with: newItem)
                        hapticTrigger += 1
                    }
                }
            }
            .onAppear {
                ensureActivePlanExists()
            }
        }
    }

    private func ensureActivePlanExists() {
        if planStore.activePlan == nil {
            let target = currentEffectiveTarget
            planStore.generateAndSetActivePlan(target: target)
        }
    }

    private var currentEffectiveTarget: NutritionTarget {
        if let target = profileStore.currentTarget {
            return target
        }
        if let profile = profileStore.currentProfile {
            let calc = NutritionCalculator.calculateFullTarget(from: profile)
            return NutritionTarget(
                calories: calc.targetCalories,
                proteinGrams: calc.targetProteinGrams,
                carbsGrams: calc.targetCarbsGrams,
                fatGrams: calc.targetFatGrams,
                fiberGrams: calc.targetFiberGrams,
                waterMl: calc.targetWaterMl,
                source: .initialCalculation
            )
        }
        let calories = targetCalories > 0 ? targetCalories : 2000.0
        return NutritionTarget(
            calories: calories,
            proteinGrams: (calories * 0.25 / 4.0).rounded(),
            carbsGrams: (calories * 0.50 / 4.0).rounded(),
            fatGrams: (calories * 0.25 / 9.0).rounded(),
            waterMl: NutritionCalculator.calculateWaterMl(weightKg: 70, activityLevel: .moderate)
        )
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
                if let plan = planStore.activePlan {
                    // Card de Resumo de Metas do Plano
                    planSummaryHeader(plan: plan)

                    // Lista de Refeições Planejadas do Core
                    ForEach(plan.meals) { meal in
                        mealCardView(meal: meal)
                    }
                } else {
                    emptyPlanView
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
    }

    private var emptyPlanView: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Nenhum plano alimentar ativo")
                .font(.headline)
            Text("Gere um cardápio diário estruturado e balanceado com base nas suas metas nutricionais.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    planStore.generateAndSetActivePlan(target: currentEffectiveTarget)
                    hapticTrigger += 1
                }
            } label: {
                Label("Gerar Plano Diário", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func planSummaryHeader(plan: DailyMealPlan) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLANO NUTRICIONAL TBCA CALCULADO")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("\(Int(plan.totalCalories)) kcal planejadas")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        planStore.generateAndSetActivePlan(target: currentEffectiveTarget)
                        hapticTrigger += 1
                    }
                } label: {
                    Label("Regenerar", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                macroTargetBadge(title: "Proteína", value: "\(Int(plan.totalProtein))g", color: .blue)
                macroTargetBadge(title: "Carbos", value: "\(Int(plan.totalCarbs))g", color: .green)
                macroTargetBadge(title: "Gorduras", value: "\(Int(plan.totalFat))g", color: .purple)
                macroTargetBadge(title: "Fibras", value: "\(Int(plan.totalFiber))g", color: .brown)
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
                    Text(meal.name.isEmpty ? meal.mealType.rawValue : meal.name)
                        .font(.headline)
                    Text("\(meal.suggestedTime) • Meta: \(Int(meal.targetCalories)) kcal")
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

            VStack(spacing: 10) {
                ForEach(meal.items) { item in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.food.name)
                                .font(.subheadline.weight(.medium))
                            let portionText = item.portionName ?? "\(Int(item.amount)) \(item.unit)"
                            Text("\(portionText) (\(Int(item.amount))g) • \(Int(item.calories)) kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            itemToSubstitute = SubstitutionTarget(mealId: meal.id, item: item)
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

    // MARK: - 3. Lista de Compras (Hortifrúti, Carnes e Ovos, Laticínios, Mercearia)

    private var groceriesView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let list = planStore.groceryList, !list.items.isEmpty {
                    // Barra de Progresso do Mercado
                    groceryProgressBar(list: list)

                    // Categorias por Departamento do Core
                    ForEach(GroceryCategory.allCases, id: \.self) { category in
                        let items = list.items.filter { $0.category == category }
                        if !items.isEmpty {
                            groceryCategorySection(category: category, items: items)
                        }
                    }
                } else {
                    emptyGroceriesView
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
    }

    private var emptyGroceriesView: some View {
        VStack(spacing: 14) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Lista de compras vazia")
                .font(.headline)
            Text("Consolide todos os ingredientes do seu plano alimentar semanal com um único toque.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    if planStore.activePlan == nil {
                        planStore.generateAndSetActivePlan(target: currentEffectiveTarget)
                    } else {
                        planStore.generateGroceryList(numberOfDays: 7)
                    }
                    hapticTrigger += 1
                }
            } label: {
                Label("Gerar Lista Semanal (7 dias)", systemImage: "cart.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func groceryProgressBar(list: GroceryList) -> some View {
        let totalItems = list.items.count
        let checkedItems = list.items.filter(\.isChecked).count
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        planStore.uncheckAllGroceryItems()
                        hapticTrigger += 1
                    }
                }
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func groceryCategorySection(category: GroceryCategory, items: [GroceryItem]) -> some View {
        let checkedCount = items.filter(\.isChecked).count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: category.iconName)
                    .foregroundColor(.green)
                Text(category.rawValue.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(checkedCount)/\(items.count)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            planStore.toggleGroceryItem(id: item.id)
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
                                Text(item.formattedQuantity)
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
                Text("PERGUNTAS RÁPIDAS (1 TOQUE)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    assistantChip(text: "Como está meu dia?")
                    assistantChip(text: "O que comer agora?")
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

        // Invocação ao motor SuccinctAssistantEngine do Core com limite de 4 linhas
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let answer = SuccinctAssistantEngine.shared.answer(
                query: clean,
                profileStore: profileStore,
                mealStore: mealStore,
                waterStore: waterStore
            )
            assistantMessages.append(
                AssistantChatMessage(
                    text: answer.fullText,
                    isUser: false,
                    nextAction: answer.nextAction
                )
            )
            hapticTrigger += 1
        }
    }
}

// MARK: - Modelos de Dados e Auxiliares da Tela

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

public struct AssistantChatMessage: Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var isUser: Bool
    public var nextAction: String?

    public init(id: UUID = UUID(), text: String, isUser: Bool, nextAction: String? = nil) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.nextAction = nextAction
    }
}

public struct SubstitutionTarget: Identifiable, Sendable {
    public let mealId: UUID
    public let item: PlannedMealItem

    public var id: UUID { item.id }

    public init(mealId: UUID, item: PlannedMealItem) {
        self.mealId = mealId
        self.item = item
    }
}

// MARK: - Sheet de Substituição Equivalente (Dietbox / Avanutri Style)

private struct FoodSubstitutionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let target: SubstitutionTarget
    let onConfirm: (PlannedMealItem) -> Void

    @State private var selectedIndex: Int = 0
    @State private var substitutes: [SubstitutionResult] = []

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
                                Text(target.item.food.name)
                                    .font(.headline)
                                let desc = target.item.portionName ?? "\(Int(target.item.amount)) \(target.item.unit)"
                                Text("\(desc) (\(Int(target.item.amount))g)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(target.item.calories)) kcal")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text("P: \(Int(target.item.proteinGrams))g | C: \(Int(target.item.carbsGrams))g | G: \(Int(target.item.fatGrams))g")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Equivalências Calculadas pelo FoodSubstitutionEngine da TBCA
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("SUBSTITUTOS EQUIVALENTES CALCULADOS")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            if let first = substitutes.first {
                                Text(first.group.anchorMacroDescription)
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                            }
                        }

                        if substitutes.isEmpty {
                            VStack(spacing: 8) {
                                Text("Nenhum substituto exato do mesmo grupo nutricional encontrado na TBCA.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.appCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 8) {
                                ForEach(substitutes.indices, id: \.self) { idx in
                                    let sub = substitutes[idx]
                                    Button {
                                        selectedIndex = idx
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(sub.substituteFood.name)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.primary)
                                                let pText = sub.suggestedPortion ?? "\(Int(sub.equivalentAmount)) \(sub.unit)"
                                                Text("\(pText) (\(Int(sub.equivalentAmount))g)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("\(Int(sub.substituteCalories)) kcal")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.orange)
                                                let deltaSign = sub.deltaCalories >= 0 ? "+" : ""
                                                Text("Δ \(deltaSign)\(Int(sub.deltaCalories)) kcal")
                                                    .font(.caption2)
                                                    .foregroundColor(abs(sub.deltaCalories) <= 30 ? .green : .secondary)
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
                    }

                    // Botão de Confirmação
                    if !substitutes.isEmpty {
                        Button {
                            if selectedIndex < substitutes.count {
                                let chosen = substitutes[selectedIndex]
                                let macros = chosen.substituteFood.calculatedFor(amount: chosen.equivalentAmount)
                                let newItem = PlannedMealItem(
                                    food: chosen.substituteFood,
                                    amount: chosen.equivalentAmount,
                                    unit: chosen.unit,
                                    portionName: chosen.suggestedPortion,
                                    calories: chosen.substituteCalories,
                                    proteinGrams: macros.protein,
                                    carbsGrams: macros.carbs,
                                    fatGrams: macros.fat,
                                    fiberGrams: macros.fiber
                                )
                                onConfirm(newItem)
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
            .onAppear {
                substitutes = FoodSubstitutionEngine.availableSubstitutes(
                    for: target.item.food,
                    amount: target.item.amount
                )
            }
        }
        .presentationDetents([.medium, .large])
    }
}
