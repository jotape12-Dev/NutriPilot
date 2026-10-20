import SwiftUI
import NutriPilotCore

public struct WaterView: View {
    @State private var totalWaterMl: Double = 1800
    @State private var targetWaterMl: Double = 3200
    @State private var logs: [WaterLog] = []

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progresso Circular
                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 20)
                    Circle()
                        .trim(from: 0, to: min(1.0, totalWaterMl / max(1, targetWaterMl)))
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: totalWaterMl)

                    VStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.cyan)
                        Text("\(Int(totalWaterMl))")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("de \(Int(targetWaterMl)) ml")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 220, height: 220)
                .padding(.top, 20)

                // Botões Rápidos de 1 Toque
                Text("REGISTRO RÁPIDO")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    quickWaterButton(amount: 150, label: "+150 ml")
                    quickWaterButton(amount: 250, label: "+250 ml")
                    quickWaterButton(amount: 350, label: "+350 ml")
                    quickWaterButton(amount: 500, label: "+500 ml")
                    quickWaterButton(amount: 750, label: "+750 ml")
                    quickWaterButton(amount: 1000, label: "+1.0 L")
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Hidratação")
            .background(Color.appBackground)
        }
    }

    private func quickWaterButton(amount: Double, label: String) -> some View {
        Button {
            addWater(amount)
        } label: {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appCardBackground)
                .foregroundColor(.cyan)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        }
    }

    private func addWater(_ amount: Double) {
        totalWaterMl += amount
        logs.insert(WaterLog(amountMl: amount), at: 0)
    }
}
