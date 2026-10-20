import SwiftUI
import NutriPilotCore
#if canImport(Charts)
import Charts
#endif

public struct BodyProgressView: View {
    // MARK: - Estado de Visualização
    @State private var timeWindow: TrendTimeWindow = .month
    @State private var inputWeight: Double = 78.4
    @State private var isShowingWeighInSheet: Bool = false
    @State private var isShowingCircumferenceSheet: Bool = false
    @State private var isShowingSkinfoldSheet: Bool = false
    @State private var selectedAntropometryProtocol: AntropometryProtocol = .pollock7
    @State private var hapticTrigger: Int = 0

    // Dados de exemplo / base de preparação para plugar o BodyMeasurementStore
    @State private var weightHistory: [WeightPoint] = WeightPoint.sampleHistory

    public init() {}

    private var latestWeight: Double {
        weightHistory.last?.actualWeight ?? 78.4
    }

    private var trendWeight: Double {
        weightHistory.last?.trendWeight ?? 78.1
    }

    private var weeklyDeltaKg: Double {
        -0.45 // Exemplo de ritmo de perda saudável
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Header com Peso de Tendência vs Última Pesagem
                    trendHeaderCard

                    // 2. Gráfico Interativo com Swift Charts (Diário + EWMA)
                    trendChartSection

                    // 3. Ações Rápidas: Pesar Hoje e Medidas
                    quickActionButtonsRow

                    // 4. Seção Modular de Circunferências Corporais
                    circumferencesSection

                    // 5. Avaliação Antropométrica (Pollock 3/7 ou Bioimpedância)
                    antropometrySection
                }
                .padding()
            }
            .navigationTitle("Evolução Corporal")
            .background(Color.appBackground)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .sheet(isPresented: $isShowingWeighInSheet) {
                WeighInSheet(initialWeight: latestWeight) { newWeight in
                    registerWeighIn(newWeight)
                }
            }
            .sheet(isPresented: $isShowingCircumferenceSheet) {
                CircumferenceEntrySheet()
            }
            .sheet(isPresented: $isShowingSkinfoldSheet) {
                SkinfoldsEntrySheet(selectedProtocol: selectedAntropometryProtocol)
            }
        }
    }

    // MARK: - 1. Card de Cabeçalho (Tendência EWMA)

    private var trendHeaderCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.green)
                            .font(.caption.bold())
                        Text("PESO DE TENDÊNCIA (EWMA)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    }

                    Text(String(format: "%.1f kg", trendWeight))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Filtra flutuações diárias de água e glicogênio")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("ÚLTIMA PESAGEM")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f kg", latestWeight))
                        .font(.title2.bold())
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: weeklyDeltaKg < 0 ? "arrow.down.right" : "arrow.up.right")
                        Text(String(format: "%+.2f kg/sem", weeklyDeltaKg))
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(weeklyDeltaKg <= 0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(weeklyDeltaKg <= 0 ? .green : .orange)
                    .clipShape(Capsule())
                }
            }

            Divider()

            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Projeção: **Meta de 75 kg** estimada para **14 de Dezembro** no ritmo atual.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    // MARK: - 2. Gráfico Interativo com Swift Charts

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Curva de Tendência")
                    .font(.headline)
                Spacer()

                Picker("Janela", selection: $timeWindow) {
                    ForEach(TrendTimeWindow.allCases, id: \.self) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            #if canImport(Charts)
            Chart {
                // Pontos reais de pesagem diária (cinza / suave)
                ForEach(filteredHistory) { point in
                    if let actual = point.actualWeight {
                        PointMark(
                            x: .value("Data", point.date, unit: .day),
                            y: .value("Pesagem", actual)
                        )
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .symbolSize(32)
                    }

                    // Linha contínua da tendência EWMA (verde viva)
                    LineMark(
                        x: .value("Data", point.date, unit: .day),
                        y: .value("Tendência", point.trendWeight)
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    AreaMark(
                        x: .value("Data", point.date, unit: .day),
                        yStart: .value("Base", 70.0),
                        yEnd: .value("Tendência", point.trendWeight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green.opacity(0.18), Color.green.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartYScale(domain: 74...80)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .frame(height: 220)
            #else
            Text("Gráficos suportados no iOS 16+")
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .background(Color.appCardBackground)
            #endif

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(Color.secondary.opacity(0.6)).frame(width: 8, height: 8)
                    Text("Pesagens diárias").font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.green).frame(width: 14, height: 4)
                    Text("Tendência filtrada (EWMA)").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    private var filteredHistory: [WeightPoint] {
        let count: Int
        switch timeWindow {
        case .week: count = 7
        case .month: count = 30
        case .quarter: count = 60
        case .all: count = weightHistory.count
        }
        return Array(weightHistory.suffix(min(count, weightHistory.count)))
    }

    // MARK: - 3. Botões Rápidos de Ação

    private var quickActionButtonsRow: some View {
        HStack(spacing: 12) {
            Button {
                isShowingWeighInSheet = true
                hapticTrigger += 1
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Pesar Hoje")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.green.opacity(0.3), radius: 5, y: 2)
            }
            .buttonStyle(.plain)

            Button {
                isShowingCircumferenceSheet = true
                hapticTrigger += 1
            } label: {
                HStack {
                    Image(systemName: "ruler.fill")
                        .font(.subheadline)
                    Text("Circunferências")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 4. Seção Modular de Circunferências

    private var circumferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Circunferências Corporais")
                    .font(.headline)
                Spacer()
                Button("Ver Histórico") {}
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                circumferenceBadge(name: "Cintura", value: "81.0 cm", delta: "-1.5 cm")
                circumferenceBadge(name: "Abdômen", value: "86.5 cm", delta: "-2.0 cm")
                circumferenceBadge(name: "Quadril", value: "99.0 cm", delta: "-0.5 cm")
                circumferenceBadge(name: "Braço Dir.", value: "37.5 cm", delta: "+0.3 cm")
                circumferenceBadge(name: "Tórax", value: "103.0 cm", delta: "+0.5 cm")
                circumferenceBadge(name: "Coxa Dir.", value: "58.0 cm", delta: "-0.2 cm")
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    private func circumferenceBadge(name: String, value: String, delta: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
            Text(delta)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(delta.hasPrefix("-") ? .green : .blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 5. Avaliação Antropométrica (Pollock / BIA)

    private var antropometrySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Composição Antropométrica")
                    .font(.headline)
                Spacer()
                Button("Lançar Dobras") {
                    isShowingSkinfoldSheet = true
                    hapticTrigger += 1
                }
                .font(.caption.bold())
                .foregroundColor(.green)
            }

            // Alternância de Protocolos (Pollock 3/7 / Bioimpedância)
            Picker("Protocolo", selection: $selectedAntropometryProtocol) {
                ForEach(AntropometryProtocol.allCases, id: \.self) { proto in
                    Text(proto.rawValue).tag(proto)
                }
            }
            .pickerStyle(.segmented)

            // Barra Visual de Fracionamento (Massa Magra vs Massa Gorda)
            compositionBarView

            HStack(spacing: 12) {
                compositionCard(title: "Gordura Corporal", value: "15.8%", subtitle: "12.4 kg de gordura", color: .purple)
                compositionCard(title: "Massa Magra", value: "84.2%", subtitle: "66.0 kg de massa livre", color: .green)
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    private var compositionBarView: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: proxy.size.width * 0.842)
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: proxy.size.width * 0.158)
                }
                .clipShape(Capsule())
            }
            .frame(height: 14)

            HStack {
                Text("Massa Magra: 66.0 kg (84.2%)")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
                Spacer()
                Text("Massa Gorda: 12.4 kg (15.8%)")
                    .font(.caption2.bold())
                    .foregroundColor(.purple)
            }
        }
    }

    private func compositionCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func registerWeighIn(_ weight: Double) {
        let today = Date()
        let lastTrend = weightHistory.last?.trendWeight ?? weight
        // Fórmula básica de EWMA alpha 0.1 para transição imediata
        let alpha = 0.1
        let newTrend = (weight * alpha) + (lastTrend * (1.0 - alpha))

        let newPoint = WeightPoint(date: today, actualWeight: weight, trendWeight: newTrend.rounded(to: 2))
        weightHistory.append(newPoint)
        hapticTrigger += 1
    }
}

// MARK: - Modelos Auxiliares de Preparação

public enum TrendTimeWindow: String, CaseIterable, Sendable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case all = "Tudo"
}

public enum AntropometryProtocol: String, CaseIterable, Sendable {
    case pollock7 = "Pollock 7D"
    case pollock3 = "Pollock 3D"
    case bia = "Bioimpedância"
}

public struct WeightPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let actualWeight: Double?
    public let trendWeight: Double

    public static var sampleHistory: [WeightPoint] {
        let calendar = Calendar.current
        let today = Date()
        var points: [WeightPoint] = []
        var baseTrend = 79.5

        for i in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            baseTrend -= 0.045
            // Simula variação natural diária de +/- 0.4kg
            let noise = sin(Double(i)) * 0.35
            let actual = baseTrend + noise
            points.append(WeightPoint(date: date, actualWeight: actual.rounded(to: 1), trendWeight: baseTrend.rounded(to: 1)))
        }
        return points
    }
}

// MARK: - Sheets Auxiliares

private struct WeighInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double

    let onSave: (Double) -> Void

    init(initialWeight: Double, onSave: @escaping (Double) -> Void) {
        self._weight = State(initialValue: initialWeight)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Selecione sua pesagem de hoje")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text(String(format: "%.1f", weight))
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                    Text("kg")
                        .font(.title2.bold())
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Button("-0.5") { weight -= 0.5 }.buttonStyle(.bordered)
                    Button("-0.1") { weight -= 0.1 }.buttonStyle(.bordered)
                    Button("+0.1") { weight += 0.1 }.buttonStyle(.bordered)
                    Button("+0.5") { weight += 0.5 }.buttonStyle(.bordered)
                }

                Button {
                    onSave(weight)
                    dismiss()
                } label: {
                    Text("Salvar Pesagem")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 30)
            .navigationTitle("Pesar Hoje")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .background(Color.appBackground)
        }
        .presentationDetents([.fraction(0.45)])
    }
}

private struct CircumferenceEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var waist: String = "81.0"
    @State private var abdomen: String = "86.5"
    @State private var hip: String = "99.0"
    @State private var arm: String = "37.5"
    @State private var thigh: String = "58.0"

    var body: some View {
        NavigationStack {
            Form {
                Section("Tronco (cm)") {
                    TextField("Cintura", text: $waist)
                    TextField("Abdômen", text: $abdomen)
                    TextField("Quadril", text: $hip)
                }
                Section("Membros (cm)") {
                    TextField("Braço relaxado", text: $arm)
                    TextField("Coxa média", text: $thigh)
                }
            }
            .navigationTitle("Circunferências")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { dismiss() }
                }
            }
        }
    }
}

private struct SkinfoldsEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedProtocol: AntropometryProtocol

    @State private var chest: String = "10"
    @State private var triceps: String = "12"
    @State private var subscapular: String = "14"
    @State private var suprailiac: String = "11"
    @State private var abdomen: String = "16"
    @State private var thigh: String = "13"
    @State private var axillary: String = "9"

    var body: some View {
        NavigationStack {
            Form {
                Section("Dobras Cutâneas (mm)") {
                    TextField("Peitoral", text: $chest)
                    TextField("Tríceps", text: $triceps)
                    TextField("Subescapular", text: $subscapular)
                    TextField("Axilar Média", text: $axillary)
                    TextField("Suprailíaca", text: $suprailiac)
                    TextField("Abdômen", text: $abdomen)
                    TextField("Coxa", text: $thigh)
                }
            }
            .navigationTitle("Protocolo \(selectedProtocol.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Calcular") { dismiss() }
                }
            }
        }
    }
}
