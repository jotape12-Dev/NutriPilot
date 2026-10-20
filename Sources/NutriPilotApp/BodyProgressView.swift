import SwiftUI
import NutriPilotCore

public struct BodyProgressView: View {
    @State private var currentWeight: Double = 78.4
    @State private var weeklyAverage: Double = 78.1
    @State private var bodyFatEstimate: String = "18% - 20%"
    @State private var inputWeightText: String = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Card de Peso e Média Móvel Semanal (Foco em tendência)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Último Peso")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f kg", currentWeight))
                                    .font(.system(size: 36, weight: .bold))
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Média Semanal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f kg", weeklyAverage))
                                    .font(.title2.bold())
                                    .foregroundColor(.green)
                            }
                        }

                        Divider()

                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.green)
                            Text("Tendência: Estável (-0.2 kg nesta semana)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Card de Estimativa de Composição (Sempre em faixa e calibrável)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.purple)
                            Text("COMPOSIÇÃO ESTIMADA")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Gordura Corporal")
                                    .font(.subheadline)
                                Text(bodyFatEstimate)
                                    .font(.title3.bold())
                                    .foregroundColor(.purple)
                            }
                            Spacer()
                            Text("Calibrado via BIA")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Registro Rápido de Peso (< 5s)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Registrar Peso de Hoje")
                            .font(.headline)

                        HStack {
                            TextField("Ex: 78.2", text: $inputWeightText)
                                .padding()
                                .background(Color.appTertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button("Salvar") {
                                if let val = Double(inputWeightText.replacingOccurrences(of: ",", with: ".")) {
                                    currentWeight = val
                                    inputWeightText = ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding(.leading, 8)
                        }
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Evolução Corporal")
            .background(Color.appBackground)
        }
    }
}
