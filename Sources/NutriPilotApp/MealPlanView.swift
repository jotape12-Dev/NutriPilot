import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif
import UniformTypeIdentifiers

public struct MealPlanView: View {
    public var targetCalories: Double
    public var mealStore: MealStore
    public var waterStore: WaterStore
    public var profileStore: ProfileStore
    public var planStore: MealPlanStore

    @State private var selectedSegment: PlanViewSegment = .plan
    @State private var itemToSubstitute: SubstitutionTarget?
    @State private var isShowingImportSheet: Bool = false
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
            .toolbar {
                if selectedSegment == .plan && planStore.activePlan != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    planStore.generateAndSetActivePlan(target: currentEffectiveTarget)
                                    hapticTrigger += 1
                                }
                            } label: {
                                Label("Gerar Novo Plano com Base nas Metas", systemImage: "sparkles")
                            }

                            Button {
                                isShowingImportSheet = true
                                hapticTrigger += 1
                            } label: {
                                Label("Importar Outro Plano", systemImage: "doc.badge.plus")
                            }

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    planStore.autoRebalanceActivePlan(target: currentEffectiveTarget)
                                    hapticTrigger += 1
                                }
                            } label: {
                                Label("Calibrar Todas as Refeições", systemImage: "sparkles.rectangle.stack")
                            }

                            Divider()

                            Button(role: .destructive) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    planStore.clear()
                                    hapticTrigger += 1
                                }
                            } label: {
                                Label("Excluir Plano Atual", systemImage: "trash")
                            }
                        } label: {
                            Label("Opções do Plano", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $itemToSubstitute) { target in
                FoodSubstitutionSheet(target: target, planStore: planStore) { newItem in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        planStore.replaceItem(mealId: target.mealId, oldItemId: target.item.id, with: newItem)
                        hapticTrigger += 1
                    }
                }
            }
            .sheet(isPresented: $isShowingImportSheet) {
                MealPlanImportSheet(planStore: planStore) {
                    hapticTrigger += 1
                }
            }
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

    private var planComplianceReport: PlanComplianceReport? {
        guard let plan = planStore.activePlan else { return nil }
        let target = currentEffectiveTarget
        let goal = profileStore.currentProfile?.goal
        let weight = profileStore.currentProfile?.currentWeightKg
        return MealPlanComplianceEvaluator.evaluate(
            plan: plan,
            target: target,
            goal: goal,
            currentWeightKg: weight
        )
    }

    private var planAdjustmentSuggestions: [PlanAdjustmentSuggestion] {
        guard let plan = planStore.activePlan else { return [] }
        return MealPlanAdjustmentEngine.generateSuggestions(
            plan: plan,
            target: currentEffectiveTarget,
            goal: profileStore.currentProfile?.goal,
            currentWeightKg: profileStore.currentProfile?.currentWeightKg
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

                    // Avaliação e Conformidade Nutricional do Plano
                    if let report = planComplianceReport {
                        planComplianceCard(report: report)
                    }

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
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .padding(.top, 8)

            Text("Nenhum Plano Alimentar Salvo")
                .font(.title3.bold())
                .foregroundColor(.primary)

            Text("Você ainda não possui um plano alimentar ativo. Você pode gerar um plano proporcional automaticamente com base nas suas metas nutricionais ou importar a dieta que você já tem do seu nutricionista.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        planStore.generateAndSetActivePlan(target: currentEffectiveTarget)
                        hapticTrigger += 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Gerar Plano com Base nas Metas")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.green.opacity(0.3), radius: 5, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    isShowingImportSheet = true
                    hapticTrigger += 1
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                        Text("Importar Meu Plano Existente")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.blue.opacity(0.35), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
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
                Menu {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            planStore.generateAndSetActivePlan(target: currentEffectiveTarget)
                            hapticTrigger += 1
                        }
                    } label: {
                        Label("Gerar Novo Plano com Base nas Metas", systemImage: "sparkles")
                    }

                    Button {
                        isShowingImportSheet = true
                        hapticTrigger += 1
                    } label: {
                        Label("Importar Outro Plano", systemImage: "doc.badge.plus")
                    }

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            planStore.autoRebalanceActivePlan(target: currentEffectiveTarget)
                            hapticTrigger += 1
                        }
                    } label: {
                        Label("Calibrar Todas as Refeições", systemImage: "sparkles.rectangle.stack")
                    }

                    Divider()

                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            planStore.clear()
                            hapticTrigger += 1
                        }
                    } label: {
                        Label("Excluir Plano Atual", systemImage: "trash")
                    }
                } label: {
                    Label("Opções do Plano", systemImage: "ellipsis.circle")
                        .font(.subheadline.bold())
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

    // MARK: - Avaliação Clínica do Plano (Conformidade Nutricional)

    private func planComplianceCard(report: PlanComplianceReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Cabeçalho com Título e Nível Geral
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                        .font(.caption.bold())
                    Text("AVALIAÇÃO CLÍNICA DO PLANO")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                Spacer()
                overallBadge(level: report.overallLevel)
            }

            // Veredito Clínico
            Text(report.summaryVerdict)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(2)

            Divider()

            // Comparativo de Macros (Calorias, Proteína, Carboidratos, Gordura)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                macroComplianceCard(metric: report.calories)
                let gKgText = report.proteinGramsPerKg != nil ? String(format: "%.1f g/kg", report.proteinGramsPerKg!) : nil
                macroComplianceCard(metric: report.protein, extraBadge: gKgText)
                macroComplianceCard(metric: report.carbs)
                macroComplianceCard(metric: report.fat)
            }

            // Alertas Dinâmicos (Déficit agressivo, superávits, remoção/adição de comida)
            if !report.alerts.isEmpty {
                VStack(spacing: 6) {
                    ForEach(report.alerts) { alert in
                        alertBannerView(alert: alert)
                    }
                }
                .padding(.top, 2)
            }

            // Ação Mestra: Calibração Automática de Todas as Refeições do Dia
            if report.overallLevel != .optimal {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        planStore.autoRebalanceActivePlan(target: currentEffectiveTarget)
                        hapticTrigger += 1
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calibrar Todas as Refeições Automaticamente")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("Equilibra arroz, proteínas e gorduras no dia para bater 100% da meta")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(
                        LinearGradient(colors: [Color.green, Color.mint], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.green.opacity(0.25), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            // Sugestões Clínicas de Ajuste para Bater a Meta
            let suggestions = planAdjustmentSuggestions
            if !suggestions.isEmpty {
                Divider()
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.green)
                            .font(.caption.bold())
                        Text("SUGESTÕES DE AJUSTE PARA BATER A META")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }

                    ForEach(suggestions) { suggestion in
                        adjustmentSuggestionCard(suggestion: suggestion)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }

    private func adjustmentSuggestionCard(suggestion: PlanAdjustmentSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)

                    Text(suggestion.explanation)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(suggestion.badgeLabel)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    if suggestion.actionType == .autoRebalance {
                        planStore.autoRebalanceActivePlan(target: currentEffectiveTarget)
                    } else {
                        planStore.applyAdjustment(suggestion)
                    }
                    hapticTrigger += 1
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: suggestion.actionType == .autoRebalance ? "sparkles" : "plus.circle.fill")
                    Text(suggestion.buttonLabel)
                }
                .font(.footnote.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(12)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func overallBadge(level: ComplianceLevel) -> some View {
        let (icon, color): (String, Color) = {
            switch level {
            case .optimal:
                return ("checkmark.seal.fill", .green)
            case .acceptable:
                return ("checkmark.circle", .teal)
            case .below, .above:
                return ("exclamationmark.triangle.fill", .orange)
            case .critical:
                return ("xmark.octagon.fill", .red)
            }
        }()

        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(level.rawValue)
        }
        .font(.caption2.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    private func complianceColor(for level: ComplianceLevel) -> Color {
        switch level {
        case .optimal: return .green
        case .acceptable: return .blue
        case .below, .above: return .orange
        case .critical: return .red
        }
    }

    private func macroComplianceCard(metric: MetricCompliance, extraBadge: String? = nil) -> some View {
        let levelColor = complianceColor(for: metric.level)
        let progress = min(1.5, max(0.0, metric.percentage / 100.0))

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(metric.name)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if let extraBadge {
                    Text(extraBadge)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if metric.unit == "kcal" {
                    Text("\(Int(metric.planned))")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("/ \(Int(metric.target)) \(metric.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(Int(metric.planned))g")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("/ \(Int(metric.target))g")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            ProgressView(value: min(1.0, progress))
                .tint(levelColor)
                .scaleEffect(x: 1, y: 0.8, anchor: .center)

            HStack {
                Text(metric.formattedDelta)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(levelColor)
                Spacer()
                Text(String(format: "%.0f%%", metric.percentage))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func alertBannerView(alert: PlanComplianceAlert) -> some View {
        let (bgColor, fgColor, icon): (Color, Color, String) = {
            switch alert.severity {
            case .danger:
                return (Color.red.opacity(0.12), Color.red, "xmark.octagon.fill")
            case .warning:
                return (Color.orange.opacity(0.12), Color.orange, "exclamationmark.triangle.fill")
            case .info:
                return (Color.blue.opacity(0.12), Color.blue, "info.circle.fill")
            }
        }()

        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundColor(fgColor)
                .padding(.top, 2)

            Text(alert.message)
                .font(.footnote)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                                Image(systemName: "slider.horizontal.3")
                                Text("Ajustar / Substituir")
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
                if planStore.activePlan == nil {
                    emptyGroceriesNoPlanView
                } else if let list = planStore.groceryList, !list.items.isEmpty {
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

    private var emptyGroceriesNoPlanView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 54))
                .foregroundColor(.secondary)
                .padding(.top, 8)

            Text("Nenhum Plano Alimentar Ativo")
                .font(.headline)

            Text("Cadastre ou gere um plano alimentar na aba 'Plano Diário' para gerar automaticamente sua lista de compras da semana.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedSegment = .plan
                    hapticTrigger += 1
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("Ir para Plano Diário")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    planStore.generateGroceryList(numberOfDays: 7)
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

// MARK: - Sheet de Substituição e Controle Granular de Porções

private struct FoodSubstitutionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let target: SubstitutionTarget
    let planStore: MealPlanStore
    let onConfirm: (PlannedMealItem) -> Void

    private enum SheetMode: String, CaseIterable, Identifiable {
        case adjustPortion = "Ajustar Porção"
        case substitute = "Substituir Alimento"

        var id: String { rawValue }
    }

    @State private var mode: SheetMode = .adjustPortion
    @State private var currentGrams: Double
    @State private var selectedIndex: Int = 0
    @State private var substituteGrams: Double = 0.0
    @State private var substitutes: [SubstitutionResult] = []

    init(
        target: SubstitutionTarget,
        planStore: MealPlanStore = .shared,
        onConfirm: @escaping (PlannedMealItem) -> Void
    ) {
        self.target = target
        self.planStore = planStore
        self.onConfirm = onConfirm
        self._currentGrams = State(initialValue: target.item.amount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Picker de Segmento no topo
                    Picker("Ação", selection: $mode) {
                        ForEach(SheetMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    switch mode {
                    case .adjustPortion:
                        adjustPortionSection
                    case .substitute:
                        substituteSection
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(mode == .adjustPortion ? "Ajustar Porção" : "Substituir Alimento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .background(Color.appBackground)
            .onAppear {
                substitutes = FoodSubstitutionEngine.availableSubstitutes(
                    for: target.item.food,
                    amount: target.item.amount
                )
                if let first = substitutes.first {
                    substituteGrams = first.equivalentAmount
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Segmento 1: Ajustar Porção Atual

    private var adjustPortionSection: some View {
        let macros = target.item.food.calculatedFor(amount: currentGrams)

        return VStack(spacing: 16) {
            // Card do Alimento Atual
            VStack(alignment: .leading, spacing: 10) {
                Text("ALIMENTO SELECIONADO")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.item.food.name)
                            .font(.headline)
                        Text("Porção de referência: \(Int(target.item.amount))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(Int(currentGrams))g")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                }

                Divider()

                // Macros Recalculados em Tempo Real
                HStack(spacing: 12) {
                    macroBadge(title: "Calorias", value: "\(Int(macros.calories)) kcal", color: .orange)
                    macroBadge(title: "Proteína", value: String(format: "%.1fg", macros.protein), color: .blue)
                    macroBadge(title: "Carbos", value: String(format: "%.1fg", macros.carbs), color: .green)
                    macroBadge(title: "Gorduras", value: String(format: "%.1fg", macros.fat), color: .purple)
                }
            }
            .padding(16)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)

            // Controle Granular da Quantidade
            VStack(spacing: 14) {
                Text("CONTROLE GRANULAR DA QUANTIDADE")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("Quantidade:")
                        .font(.subheadline)
                    Spacer()
                    Button {
                        currentGrams = max(5.0, currentGrams - 5.0)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Text(String(format: "%.0fg", currentGrams))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .frame(minWidth: 80)
                        .multilineTextAlignment(.center)

                    Button {
                        currentGrams += 5.0
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)

                // Botões Rápidos de Ajuste
                HStack(spacing: 10) {
                    quickAdjustButton(delta: -50)
                    quickAdjustButton(delta: -20)
                    quickAdjustButton(delta: +20)
                    quickAdjustButton(delta: +50)
                }
            }
            .padding(16)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)

            // Botão Salvar Nova Quantidade
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    planStore.updateItemAmount(
                        mealId: target.mealId,
                        itemId: target.item.id,
                        newAmount: currentGrams
                    )
                }
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Salvar Nova Quantidade (\(Int(currentGrams))g)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }

    private func quickAdjustButton(delta: Double) -> some View {
        Button {
            currentGrams = max(5.0, currentGrams + delta)
        } label: {
            Text(delta > 0 ? "+\(Int(delta))g" : "\(Int(delta))g")
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.appBackground)
                .foregroundColor(delta > 0 ? .green : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Segmento 2: Substituir Alimento

    private var substituteSection: some View {
        VStack(spacing: 16) {
            // Item Original (Referência)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ORIGINAL: \(target.item.food.name)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("\(Int(target.item.amount))g • \(Int(target.item.calories)) kcal")
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
                Spacer()
                if let first = substitutes.first {
                    Text(first.group.anchorMacroDescription)
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Lista de Substitutos Equivalentes
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
                            substituteGrams = sub.equivalentAmount
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.substituteFood.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    let pText = sub.suggestedPortion ?? "\(Int(sub.equivalentAmount)) \(sub.unit)"
                                    Text("Equivalência: \(pText) (\(Int(sub.equivalentAmount))g)")
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

                // Ajuste Granular da Quantidade do Substituto Selecionado
                if selectedIndex < substitutes.count {
                    let chosen = substitutes[selectedIndex]
                    let chosenMacros = chosen.substituteFood.calculatedFor(amount: substituteGrams)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CALIBRAR QUANTIDADE DO SUBSTITUTO")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chosen.substituteFood.name)
                                    .font(.subheadline.bold())
                                Text("Ajuste a gramatura desejada:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                substituteGrams = max(5.0, substituteGrams - 10.0)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)

                            Text(String(format: "%.0fg", substituteGrams))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .frame(minWidth: 70)
                                .multilineTextAlignment(.center)

                            Button {
                                substituteGrams += 10.0
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider()

                        // Macros em tempo real para a quantidade customizada do substituto
                        HStack(spacing: 8) {
                            macroBadge(title: "Calorias", value: "\(Int(chosenMacros.calories)) kcal", color: .orange)
                            macroBadge(title: "Proteína", value: String(format: "%.1fg", chosenMacros.protein), color: .blue)
                            macroBadge(title: "Carbos", value: String(format: "%.1fg", chosenMacros.carbs), color: .green)
                            macroBadge(title: "Gorduras", value: String(format: "%.1fg", chosenMacros.fat), color: .purple)
                        }
                    }
                    .padding(14)
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Botão Confirmar Substituição
                    Button {
                        let macros = chosen.substituteFood.calculatedFor(amount: substituteGrams)
                        let pText = chosen.suggestedPortion ?? "\(Int(substituteGrams)) \(chosen.unit)"
                        let newItem = PlannedMealItem(
                            food: chosen.substituteFood,
                            amount: substituteGrams,
                            unit: chosen.unit,
                            portionName: pText,
                            calories: macros.calories,
                            proteinGrams: macros.protein,
                            carbsGrams: macros.carbs,
                            fatGrams: macros.fat,
                            fiberGrams: macros.fiber
                        )
                        onConfirm(newItem)
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.2.squarepath")
                            Text("Confirmar Substituição (\(Int(substituteGrams))g)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }

    private func macroBadge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Folha Modal de Importação de Plano Existente

public struct MealPlanImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    public var planStore: MealPlanStore
    public var onSaved: () -> Void

    public enum ImportMode: String, CaseIterable, Identifiable {
        case pasteText = "Colar Texto"
        case uploadPDF = "Subir PDF"

        public var id: String { rawValue }
    }

    @State private var importMode: ImportMode = .pasteText
    @State private var planText: String = ""
    @State private var showFileImporter: Bool = false
    @State private var selectedPDFData: Data? = nil
    @State private var selectedPDFFileName: String? = nil
    @State private var errorMessage: String? = nil
    @State private var isProcessing: Bool = false

    public init(planStore: MealPlanStore = .shared, onSaved: @escaping () -> Void = {}) {
        self.planStore = planStore
        self.onSaved = onSaved
    }

    private var canSubmit: Bool {
        switch importMode {
        case .pasteText:
            return !planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .uploadPDF:
            return selectedPDFData != nil
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Segment Picker
                Picker("Modo de Importação", selection: $importMode) {
                    ForEach(ImportMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)

                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                        Button {
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Conteúdo baseado no modo selecionado
                switch importMode {
                case .pasteText:
                    pasteTextModeView
                case .uploadPDF:
                    uploadPDFModeView
                }

                Spacer()

                // Botão de Ação "Processar e Salvar Plano"
                Button {
                    processAndSave()
                } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Processar e Salvar Plano")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSubmit ? Color.green : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: canSubmit ? Color.green.opacity(0.3) : Color.clear, radius: 4, y: 2)
                }
                .disabled(!canSubmit || isProcessing)
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Importar Plano")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImportResult(result)
            }
        }
    }

    private var pasteTextModeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cole aqui a prescrição ou cardápio enviado pelo seu nutricionista:")
                .font(.footnote)
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $planText)
                    .padding(8)
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                if planText.isEmpty {
                    Text("Exemplo:\nCafé da manhã (07:30):\n• 2 ovos mexidos\n• 2 fatias de pão integral\n• 1 xícara de café com leite\n\nAlmoço (12:30):\n• 150g de peito de frango grelhado\n• 150g de arroz branco cozido\n• 100g de feijão preto\n• Salada à vontade")
                        .font(.footnote)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxHeight: 280)

            Text("O NutriPilot detecta automaticamente horários, refeições e cruza alimentos com a tabela TBCA.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    private var uploadPDFModeView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Selecione o PDF da sua Dieta")
                    .font(.headline)

                Text("Compatível com PDFs prescritos por nutricionistas, clínicas ou aplicativos como Dietbox, Webdiet e Nutrium.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    showFileImporter = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text(selectedPDFFileName == nil ? "Escolher Arquivo PDF" : "Substituir Arquivo PDF")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if let name = selectedPDFFileName, let data = selectedPDFData {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(String(format: "%.1f KB", Double(data.count) / 1024.0))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        selectedPDFData = nil
                        selectedPDFFileName = nil
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(Color.appCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Permissão negada para acessar o arquivo selecionado."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                self.selectedPDFData = data
                self.selectedPDFFileName = url.lastPathComponent
                self.errorMessage = nil
            } catch {
                self.errorMessage = "Falha ao ler o arquivo PDF: \(error.localizedDescription)"
            }
        case .failure(let error):
            self.errorMessage = "Erro ao selecionar arquivo: \(error.localizedDescription)"
        }
    }

    private func processAndSave() {
        isProcessing = true
        errorMessage = nil

        let imported: MealPlan
        switch importMode {
        case .pasteText:
            imported = MealPlanImportEngine.importPlan(text: planText)
        case .uploadPDF:
            guard let data = selectedPDFData else {
                isProcessing = false
                return
            }
            imported = MealPlanImportEngine.importPlan(pdfData: data)
        }

        if imported.meals.isEmpty {
            isProcessing = false
            errorMessage = "Não foi possível extrair refeições válidas. Certifique-se de que o texto ou PDF contenha alimentos com quantidades."
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            planStore.setActivePlan(imported)
        }
        onSaved()
        isProcessing = false
        dismiss()
    }
}
