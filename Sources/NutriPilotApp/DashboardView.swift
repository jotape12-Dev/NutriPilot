import SwiftUI
import NutriPilotCore

public struct DashboardView: View {
    @State private var consumedCalories: Double = 1750
    @State private var targetCalories: Double = 2500
    @State private var consumedProtein: Double = 142
    @State private var targetProtein: Double = 170
    @State private var consumedWaterMl: Double = 2200
    @State private var targetWaterMl: Double = 3200

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Card da Próxima Ação (Core differentiator)
                    nextActionCard

                    // Resumo Rápido de Macros & Calorias
                    macroSummarySection

                    // Barra Rápida de Água
                    waterQuickProgress

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Hoje")
            .background(Color.appBackground)
        }
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

            Text("Faltam **28g de proteína** e **1.000 ml de água**.")
                .font(.headline)

            Text("💡 No jantar, priorize **150g de filé de frango** ou **3 ovos com queijo**, e beba 500ml de água na próxima hora.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
            Text("Metas do Dia")
                .font(.headline)

            HStack(spacing: 12) {
                metricCard(
                    title: "Calorias",
                    current: "\(Int(consumedCalories))",
                    target: "\(Int(targetCalories)) kcal",
                    progress: consumedCalories / max(1, targetCalories),
                    color: .orange
                )

                metricCard(
                    title: "Proteína",
                    current: "\(Int(consumedProtein))g",
                    target: "\(Int(targetProtein))g",
                    progress: consumedProtein / max(1, targetProtein),
                    color: .blue
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
                Text("\(Int(consumedWaterMl)) / \(Int(targetWaterMl)) ml")
                    .font(.subheadline.bold())
                    .foregroundColor(.cyan)
            }

            ProgressView(value: min(1.0, consumedWaterMl / max(1, targetWaterMl)))
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
