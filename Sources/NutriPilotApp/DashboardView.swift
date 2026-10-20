import SwiftUI
import NutriPilotCore

public struct DashboardView: View {
    public let profile: UserProfile
    public let target: NutritionTarget
    public var waterStore: WaterStore
    public var mealStore: MealStore

    @State private var hapticTrigger: Int = 0

    public init(
        profile: UserProfile,
        target: NutritionTarget,
        waterStore: WaterStore = .shared,
        mealStore: MealStore = .shared
    ) {
        self.profile = profile
        self.target = target
        self.waterStore = waterStore
        self.mealStore = mealStore
    }

    private var todayTotals: DayNutritionTotals {
        mealStore.dailyTotals(for: Date())
    }

    private var consumedCalories: Double { todayTotals.calories }
    private var consumedProtein: Double { todayTotals.proteinGrams }
    private var consumedCarbs: Double { todayTotals.carbsGrams }
    private var consumedFat: Double { todayTotals.fatGrams }
    private var consumedWaterMl: Double { waterStore.totalWaterMl(for: Date()) }

    private var remainingCalories: Double { max(0, target.calories - consumedCalories) }
    private var remainingProtein: Double { max(0, target.proteinGrams - consumedProtein) }
    private var remainingCarbs: Double { max(0, target.carbsGrams - consumedCarbs) }
    private var remainingFat: Double { max(0, target.fatGrams - consumedFat) }
    private var remainingWater: Double { max(0, target.waterMl - consumedWaterMl) }

    private var waterPacingStatus: WaterReminderStatus {
        waterStore.reminderStatus(at: Date(), targetWaterMl: target.waterMl)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Card da Próxima Ação Recomendada (Inteligência Dinâmica)
                    nextActionCard

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
        }
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
                        _ = waterStore.addLog(amountMl: 250)
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
                        _ = waterStore.addLog(amountMl: 500)
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
