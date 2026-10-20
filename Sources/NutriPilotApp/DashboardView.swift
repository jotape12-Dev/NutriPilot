import SwiftUI
import NutriPilotCore

public struct DashboardView: View {
    public let profile: UserProfile
    public let target: NutritionTarget

    @State private var consumedCalories: Double = 0
    @State private var consumedProtein: Double = 0
    @State private var consumedWaterMl: Double = 0

    public init(profile: UserProfile, target: NutritionTarget) {
        self.profile = profile
        self.target = target
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Card da Próxima Ação (Core differentiator)
                    nextActionCard

                    // Resumo Rápido de Macros & Calorias com dados reais
                    macroSummarySection

                    // Barra Rápida de Água
                    waterQuickProgress

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Olá, \(profile.name)")
            .background(Color.appBackground)
        }
    }

    private var remainingProtein: Double {
        max(0, target.proteinGrams - consumedProtein)
    }

    private var remainingWater: Double {
        max(0, target.waterMl - consumedWaterMl)
    }

    private var nextActionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("PRÓXIMA AÇÃO RECOMENDADA")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            if remainingProtein > 0 || remainingWater > 0 {
                Text("Faltam **\(Int(remainingProtein))g de proteína** e **\(Int(remainingWater)) ml de água**.")
                    .font(.headline)

                Text("💡 Priorize **150g de filé de frango** ou **3 ovos com whey**, e beba 500ml de água na próxima hora para manter o ritmo.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("🎉 Metas do dia batidas com sucesso!")
                    .font(.headline)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1.5)
        )
    }

    private var macroSummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Metas Diárias (\(target.source.rawValue))")
                .font(.headline)

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
                    current: "0g",
                    target: "\(Int(target.carbsGrams))g",
                    progress: 0,
                    color: .green
                )

                metricCard(
                    title: "Gorduras",
                    current: "0g",
                    target: "\(Int(target.fatGrams))g",
                    progress: 0,
                    color: .purple
                )
            }
        }
    }

    private var waterQuickProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hidratação")
                    .font(.headline)
                Spacer()
                Text("\(Int(consumedWaterMl)) / \(Int(target.waterMl)) ml")
                    .font(.subheadline.bold())
                    .foregroundColor(.cyan)
            }

            ProgressView(value: min(1.0, consumedWaterMl / max(1, target.waterMl)))
                .tint(.cyan)

            HStack {
                Button("+250ml") {
                    consumedWaterMl += 250
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan.opacity(0.8))

                Button("+500ml") {
                    consumedWaterMl += 500
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
    }
}
