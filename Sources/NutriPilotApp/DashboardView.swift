import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

public struct DashboardView: View {
    public let profile: UserProfile
    public let target: NutritionTarget
    public var waterStore: WaterStore
    public var mealStore: MealStore
    public var bodyStore: BodyMeasurementStore
    public var parserEngine: MealParserEngine

    @State private var isShowingTextLogModal: Bool = false
    @State private var isShowingExportSheet: Bool = false
    @State private var isShowingProfileSettings: Bool = false
    @State private var hapticTrigger: Int = 0

    public init(
        profile: UserProfile,
        target: NutritionTarget,
        waterStore: WaterStore = .shared,
        mealStore: MealStore = .shared,
        bodyStore: BodyMeasurementStore = .shared,
        parserEngine: MealParserEngine = .shared
    ) {
        self.profile = profile
        self.target = target
        self.waterStore = waterStore
        self.mealStore = mealStore
        self.bodyStore = bodyStore
        self.parserEngine = parserEngine
    }

    private var todayTotals: DayNutritionTotals {
        mealStore.todayTotals()
    }

    private var consumedCalories: Double { todayTotals.calories }
    private var consumedProtein: Double { todayTotals.proteinGrams }
    private var consumedCarbs: Double { todayTotals.carbsGrams }
    private var consumedFat: Double { todayTotals.fatGrams }
    private var consumedWaterMl: Double { waterStore.totalWater(for: Date()) }

    private var remainingCalories: Double { max(0, target.calories - consumedCalories) }
    private var remainingProtein: Double { max(0, target.proteinGrams - consumedProtein) }
    private var remainingCarbs: Double { max(0, target.carbsGrams - consumedCarbs) }
    private var remainingFat: Double { max(0, target.fatGrams - consumedFat) }
    private var remainingWater: Double { max(0, target.waterMl - consumedWaterMl) }

    private var waterPacingStatus: WaterReminderStatus {
        waterStore.reminderStatus(at: Date(), targetWaterMl: target.waterMl)
    }

    private var currentTrendWeight: Double {
        bodyStore.currentTrendWeight(spanDays: 7) ?? profile.currentWeightKg
    }

    private var weeklyWeightDelta: Double? {
        bodyStore.weeklyVelocity(daysWindow: 14)
    }

    private var latestWeight: Double {
        bodyStore.latestMeasurement?.weightKg ?? profile.currentWeightKg
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Card de Peso de Tendência (EWMA) & Ritmo Semanal (Fase 4)
                    weightTrendSummaryCard

                    // Card da Próxima Ação Recomendada (Inteligência Dinâmica)
                    nextActionCard

                    // Atalho Rápido para Registro por Texto/Voz (Fase 3)
                    quickMealShortcutCard

                    // Resumo Real de Calorias & Macronutrientes
                    macroSummarySection

                    // Barra Rápida de Água com 1 Toque
                    waterQuickProgress

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Olá, \(profile.name)")
            .background(Color.appBackground)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 14) {
                        Button {
                            isShowingProfileSettings = true
                            hapticTrigger += 1
                        } label: {
                            Label("Perfil e Rotina", systemImage: "person.crop.circle")
                        }

                        Button {
                            isShowingExportSheet = true
                            hapticTrigger += 1
                        } label: {
                            Label("Exportar Relatório", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            isShowingTextLogModal = true
                            hapticTrigger += 1
                        } label: {
                            Label("Registro Rápido", systemImage: "sparkles")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingProfileSettings) {
                ProfileSettingsView(
                    profileStore: ProfileStore.shared,
                    bodyStore: bodyStore
                )
            }
            .sheet(isPresented: $isShowingExportSheet) {
                ReportExportView(
                    profileStore: ProfileStore.shared,
                    mealStore: mealStore,
                    waterStore: waterStore,
                    bodyStore: bodyStore
                )
            }
            .sheet(isPresented: $isShowingTextLogModal) {
                DashboardQuickMealModal(
                    parserEngine: parserEngine,
                    mealStore: mealStore
                )
            }
        }
    }

    // MARK: - Card de Peso de Tendência (EWMA) & Ritmo Semanal

    private var weightTrendSummaryCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.green)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("PESO DE TENDÊNCIA")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f kg", currentTrendWeight))
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    Text("última: \(String(format: "%.1f kg", latestWeight))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let delta = weeklyWeightDelta {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("RITMO")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)

                    HStack(spacing: 3) {
                        Image(systemName: delta <= 0 ? "arrow.down.right" : "arrow.up.right")
                        Text(String(format: "%+.1f kg/sem", delta))
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(delta <= 0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(delta <= 0 ? .green : .orange)
                    .clipShape(Capsule())
                }
            } else {
                Text("Estável")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }

    // MARK: - Card da Próxima Ação

    private var nextActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("PRÓXIMA AÇÃO RECOMENDADA")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }

            if remainingProtein <= 0 && remainingWater <= 0 && remainingCalories <= 100 {
                // Todas as metas batidas
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎉 Metas do dia batidas com sucesso!")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("Você atingiu o consumo ideal de água e proteínas planejados para hoje. Excelente disciplina!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Recomendações dinâmicas contextuais
                VStack(alignment: .leading, spacing: 10) {
                    // Alerta de Água (Nutrium-style)
                    if case .reminderNeeded(_, _, let deficit) = waterPacingStatus {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "drop.triangle.fill")
                                .foregroundColor(.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Atenção à Hidratação")
                                    .font(.subheadline.bold())
                                Text("Você está **\(Int(deficit)) ml abaixo do ritmo** esperado para este horário. Beba um copo de 250ml agora para retomar o pacing.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Divider()
                    }

                    // Recomendação de Macronutrientes / Proteína
                    if remainingProtein > 0 {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "fork.knife.circle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Faltam **\(Int(remainingProtein))g de proteína** no dia")
                                    .font(.subheadline.bold())

                                if remainingProtein >= 30 {
                                    let chickenGrams = Int((remainingProtein / 0.315).rounded())
                                    Text("💡 Priorize **\(chickenGrams)g de filé de frango grelhado** ou 2 scoops de Whey Protein na próxima refeição.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                } else {
                                    let eggs = max(2, Int((remainingProtein / 6.0).rounded()))
                                    Text("💡 Sugestão leve: **\(eggs) ovos mexidos** ou 1 fatia de queijo com aveia para bater a meta sem estourar calorias.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else if remainingCalories > 200 {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "leaf.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Proteína batida! Restam \(Int(remainingCalories)) kcal")
                                    .font(.subheadline.bold())
                                Text("Complete a energia com carboidratos complexos (frutas ou arroz integral).")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    // MARK: - Atalho Rápido de Refeição (Texto / Voz)

    private var quickMealShortcutCard: some View {
        Button {
            isShowingTextLogModal = true
            hapticTrigger += 1
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: "sparkles")
                        .foregroundColor(.green)
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Registro Rápido em Linguagem Natural")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "mic.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text("Fale ou digite: \"2 filés de frango e 4 colheres de arroz\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }
            .padding(14)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resumo de Macronutrientes

    private var macroSummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Metas Diárias (\(target.source.rawValue))")
                    .font(.headline)
                Spacer()
                Text("\(Int(consumedCalories)) / \(Int(target.calories)) kcal")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
            }

            HStack(spacing: 12) {
                metricCard(
                    title: "Calorias",
                    current: "\(Int(consumedCalories))",
                    target: "\(Int(target.calories)) kcal",
                    progress: consumedCalories / max(1, target.calories),
                    color: .orange
                )

                metricCard(
                    title: "Proteína",
                    current: "\(Int(consumedProtein))g",
                    target: "\(Int(target.proteinGrams))g",
                    progress: consumedProtein / max(1, target.proteinGrams),
                    color: .blue
                )
            }

            HStack(spacing: 12) {
                metricCard(
                    title: "Carboidratos",
                    current: "\(Int(consumedCarbs))g",
                    target: "\(Int(target.carbsGrams))g",
                    progress: consumedCarbs / max(1, target.carbsGrams),
                    color: .green
                )

                metricCard(
                    title: "Gorduras",
                    current: "\(Int(consumedFat))g",
                    target: "\(Int(target.fatGrams))g",
                    progress: consumedFat / max(1, target.fatGrams),
                    color: .purple
                )
            }
        }
    }

    // MARK: - Barra Rápida de Água

    private var waterQuickProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hidratação")
                        .font(.headline)
                    waterPacingSubtitle
                }
                Spacer()
                Text("\(Int(consumedWaterMl)) / \(Int(target.waterMl)) ml")
                    .font(.subheadline.bold())
                    .foregroundColor(.cyan)
            }

            ProgressView(value: min(1.0, consumedWaterMl / max(1, target.waterMl)))
                .tint(.cyan)

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        _ = waterStore.addWater(amount: 250)
                        hapticTrigger += 1
                    }
                } label: {
                    Label("+250 ml", systemImage: "plus")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan.opacity(0.85))

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        _ = waterStore.addWater(amount: 500)
                        hapticTrigger += 1
                    }
                } label: {
                    Label("+500 ml", systemImage: "plus")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    private var waterPacingSubtitle: some View {
        Group {
            switch waterPacingStatus {
            case .targetAchieved:
                Text("Meta batida!")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
            case .onTrack:
                Text("No ritmo ideal")
                    .font(.caption2.bold())
                    .foregroundColor(.blue)
            case .reminderNeeded(_, _, let deficit):
                Text("Abaixo do ritmo (-\(Int(deficit))ml)")
                    .font(.caption2.bold())
                    .foregroundColor(.orange)
            case .outsideWindow, .disabled:
                Text("Meta: \(Int(target.waterMl)) ml/dia")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func metricCard(title: String, current: String, target: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(current)
                .font(.title2.bold())
            ProgressView(value: min(1.0, progress))
                .tint(color)
            Text("meta: \(target)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }
}

// MARK: - Modal de Registro Rápido do Dashboard

private struct DashboardQuickMealModal: View {
    @Environment(\.dismiss) private var dismiss

    let parserEngine: MealParserEngine
    let mealStore: MealStore

    @State private var inputText: String = ""
    @State private var parsedMealToConfirm: ParsedMeal?
    @State private var hapticTrigger: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text("DESCREVA SUA REFEIÇÃO")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "mic.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }

                        HStack(spacing: 8) {
                            TextField("Ex: 2 filés de frango e 4 colheres de arroz", text: $inputText)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .onSubmit {
                                    analyze(text: inputText)
                                }

                            if !inputText.isEmpty {
                                Button {
                                    inputText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            analyze(text: inputText)
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Analisar e Decompor Refeição")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Sugestões Rápidas de Exemplos
                    VStack(alignment: .leading, spacing: 10) {
                        Text("OU ESCOLHA UM EXEMPLO BRASILEIRO")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            exampleRow(text: "2 filés de frango e 4 colheres de arroz")
                            exampleRow(text: "1 scoop de whey e 1 banana")
                            exampleRow(text: "3 ovos mexidos e 2 fatias de pão")
                            exampleRow(text: "1 concha de feijão e 1 bife de patinho")
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .navigationTitle("Registro Rápido")
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .sheet(item: $parsedMealToConfirm) { meal in
                MealParserConfirmationSheet(
                    parsedMeal: meal,
                    defaultMealType: .lunch,
                    mealStore: mealStore
                ) {
                    dismiss()
                }
            }
        }
    }

    private func exampleRow(text: String) -> some View {
        Button {
            inputText = text
            analyze(text: text)
        } label: {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func analyze(text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let parsed = parserEngine.parse(text: clean)
        parsedMealToConfirm = parsed
        hapticTrigger += 1
    }
}
