import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif
#if canImport(Charts)
import Charts
#endif

public struct BodyProgressView: View {
    public var bodyStore: BodyMeasurementStore
    public var profileStore: ProfileStore

    // MARK: - Estado de Visualização
    @State private var timeWindow: TrendTimeWindow = .month
    @State private var isShowingWeighInSheet: Bool = false
    @State private var isShowingCircumferenceSheet: Bool = false
    @State private var isShowingSkinfoldSheet: Bool = false
    @State private var isShowingExportSheet: Bool = false
    @State private var selectedAntropometryProtocol: AntropometryProtocol = .pollock7
    @State private var hapticTrigger: Int = 0

    public init(
        bodyStore: BodyMeasurementStore = .shared,
        profileStore: ProfileStore = .shared
    ) {
        self.bodyStore = bodyStore
        self.profileStore = profileStore
    }

    private var profileWeight: Double {
        profileStore.currentProfile?.currentWeightKg ?? 78.4
    }

    private var latestWeight: Double {
        bodyStore.latestMeasurement?.weightKg ?? profileWeight
    }

    private var currentTrendWeight: Double {
        bodyStore.currentTrendWeight(spanDays: 7) ?? latestWeight
    }

    private var weeklyDeltaKg: Double {
        bodyStore.weeklyVelocity(daysWindow: 14) ?? -0.45
    }

    private var timeWindowDays: Int {
        switch timeWindow {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return 180
        }
    }

    private var displayChartPoints: [WeightPoint] {
        let storeSeries = bodyStore.weightTrendSeries(spanDays: timeWindowDays)
        if !storeSeries.isEmpty {
            let points = storeSeries.map {
                WeightPoint(date: $0.date, actualWeight: $0.actualWeightKg, trendWeight: $0.trendWeightKg)
            }
            return filteredPoints(points)
        } else {
            return filteredPoints(WeightPoint.sampleHistory(baseWeight: latestWeight))
        }
    }

    private func filteredPoints(_ allPoints: [WeightPoint]) -> [WeightPoint] {
        let count: Int
        switch timeWindow {
        case .week: count = 7
        case .month: count = 30
        case .quarter: count = 90
        case .all: count = allPoints.count
        }
        return Array(allPoints.suffix(min(count, allPoints.count)))
    }

    // Última medição com circunferências
    private var latestCircumferenceMeasurement: BodyMeasurement? {
        bodyStore.sortedMeasurements.reversed().first(where: { $0.waistCm != nil || $0.abdomenCm != nil || $0.hipCm != nil })
    }

    // Última medição com composição corporal
    private var latestCompositionMeasurement: BodyMeasurement? {
        bodyStore.sortedMeasurements.reversed().first(where: { $0.bodyFatPercent != nil })
    }

    private var currentBodyFatPercent: Double {
        latestCompositionMeasurement?.bodyFatPercent ?? 15.8
    }

    private var currentFatMassKg: Double {
        latestCompositionMeasurement?.fatMassKg ?? (latestWeight * (currentBodyFatPercent / 100.0)).rounded(to: 1)
    }

    private var currentLeanMassKg: Double {
        latestCompositionMeasurement?.leanMassKg ?? (latestWeight - currentFatMassKg).rounded(to: 1)
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingExportSheet = true
                        hapticTrigger += 1
                    } label: {
                        Label("Exportar Relatório", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $isShowingExportSheet) {
                ReportExportView(
                    profileStore: profileStore,
                    mealStore: .shared,
                    waterStore: .shared,
                    bodyStore: bodyStore
                )
            }
            .sheet(isPresented: $isShowingWeighInSheet) {
                WeighInSheet(initialWeight: latestWeight) { newWeight in
                    _ = bodyStore.logWeight(kg: newWeight)
                    hapticTrigger += 1
                }
            }
            .sheet(isPresented: $isShowingCircumferenceSheet) {
                CircumferenceEntrySheet(initialWeight: latestWeight) { measurement in
                    _ = bodyStore.addMeasurement(measurement)
                    hapticTrigger += 1
                }
            }
            .sheet(isPresented: $isShowingSkinfoldSheet) {
                SkinfoldsEntrySheet(
                    selectedProtocol: selectedAntropometryProtocol,
                    initialWeight: latestWeight,
                    profile: profileStore.currentProfile
                ) { measurement in
                    _ = bodyStore.addMeasurement(measurement)
                    hapticTrigger += 1
                }
            }
        }
    }

    // MARK: - 1. Card de Cabeçalho (Tendência EWMA & Nutrium Projection)

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

                    Text(String(format: "%.1f kg", currentTrendWeight))
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
                        Image(systemName: weeklyDeltaKg <= 0 ? "arrow.down.right" : "arrow.up.right")
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

            // Projeção Inteligente Nutrium Style
            projectionFooterView
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    private var projectionFooterView: some View {
        let targetKg = max(50.0, latestWeight - 4.0)
        let projection = bodyStore.projectTarget(targetWeightKg: targetKg)

        return HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.yellow)

            switch projection.status {
            case .progressing(let date, let weeksRemaining):
                Text("Projeção: **Meta de \(Int(targetKg)) kg** estimada em **\(Int(weeksRemaining)) semanas** (\(dateFormatter.string(from: date))) no ritmo atual.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            case .targetAchieved:
                Text("🎉 Parabéns! Você já atingiu sua meta de peso corporal.")
                    .font(.footnote.bold())
                    .foregroundColor(.green)
            case .plateau:
                Text("Ritmo estável. Mantendo peso com pouca oscilação.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            case .diverging:
                Text("Tendência ascendente. Ajuste o balanço calórico para retomar a meta.")
                    .font(.footnote)
                    .foregroundColor(.orange)
            case .insufficientData:
                Text("Projeção calculada automaticamente após as primeiras pesagens.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
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
            let points = displayChartPoints
            let minY = max(40.0, (points.map(\.trendWeight).min() ?? latestWeight) - 2.0)
            let maxY = (points.map(\.trendWeight).max() ?? latestWeight) + 2.0

            Chart {
                // Pontos reais de pesagem diária (cinza / suave)
                ForEach(points) { point in
                    if let actual = point.actualWeight {
                        PointMark(
                            x: .value("Data", point.date, unit: .day),
                            y: .value("Pesagem", actual)
                        )
                        .foregroundStyle(Color.secondary.opacity(0.55))
                        .symbolSize(36)
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
                        yStart: .value("Base", minY),
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
            .chartYScale(domain: minY...maxY)
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
        let m = latestCircumferenceMeasurement
        let waist = m?.waistCm ?? 81.0
        let abdomen = m?.abdomenCm ?? 86.5
        let hip = m?.hipCm ?? 99.0
        let arm = m?.rightArmRelaxedCm ?? 37.5
        let chest = m?.chestCm ?? 103.0
        let thigh = m?.rightThighCm ?? 58.0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Circunferências Corporais")
                    .font(.headline)
                Spacer()
                Button("Lançar Medidas") {
                    isShowingCircumferenceSheet = true
                    hapticTrigger += 1
                }
                .font(.caption.bold())
                .foregroundColor(.green)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                circumferenceBadge(name: "Cintura", value: String(format: "%.1f cm", waist), delta: "-1.5 cm")
                circumferenceBadge(name: "Abdômen", value: String(format: "%.1f cm", abdomen), delta: "-2.0 cm")
                circumferenceBadge(name: "Quadril", value: String(format: "%.1f cm", hip), delta: "-0.5 cm")
                circumferenceBadge(name: "Braço Dir.", value: String(format: "%.1f cm", arm), delta: "+0.3 cm")
                circumferenceBadge(name: "Tórax", value: String(format: "%.1f cm", chest), delta: "+0.5 cm")
                circumferenceBadge(name: "Coxa Dir.", value: String(format: "%.1f cm", thigh), delta: "-0.2 cm")
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
        let leanPercent = max(0, 100.0 - currentBodyFatPercent)

        return VStack(alignment: .leading, spacing: 14) {
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
            VStack(spacing: 6) {
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: max(0, proxy.size.width * (leanPercent / 100.0)))
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: max(0, proxy.size.width * (currentBodyFatPercent / 100.0)))
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 14)

                HStack {
                    Text(String(format: "Massa Magra: %.1f kg (%.1f%%)", currentLeanMassKg, leanPercent))
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                    Spacer()
                    Text(String(format: "Massa Gorda: %.1f kg (%.1f%%)", currentFatMassKg, currentBodyFatPercent))
                        .font(.caption2.bold())
                        .foregroundColor(.purple)
                }
            }

            HStack(spacing: 12) {
                compositionCard(
                    title: "Gordura Corporal",
                    value: String(format: "%.1f%%", currentBodyFatPercent),
                    subtitle: String(format: "%.1f kg de gordura", currentFatMassKg),
                    color: .purple
                )
                compositionCard(
                    title: "Massa Magra Livre",
                    value: String(format: "%.1f%%", leanPercent),
                    subtitle: String(format: "%.1f kg massa magra", currentLeanMassKg),
                    color: .green
                )
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
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

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "dd/MM"
        return df
    }
}

// MARK: - Modelos Auxiliares

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

    public static func sampleHistory(baseWeight: Double) -> [WeightPoint] {
        let calendar = Calendar.current
        let today = Date()
        var points: [WeightPoint] = []
        var trend = baseWeight + 1.2

        for i in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            trend -= 0.04
            let noise = sin(Double(i)) * 0.35
            let actual = trend + noise
            points.append(WeightPoint(date: date, actualWeight: actual.rounded(to: 1), trendWeight: trend.rounded(to: 1)))
        }
        return points
    }
}

// MARK: - Sheets de Entrada de Dados

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
    let initialWeight: Double
    let onSave: (BodyMeasurement) -> Void

    @State private var waist: String = "81.0"
    @State private var abdomen: String = "86.5"
    @State private var hip: String = "99.0"
    @State private var arm: String = "37.5"
    @State private var chest: String = "103.0"
    @State private var thigh: String = "58.0"

    var body: some View {
        NavigationStack {
            Form {
                Section("Tronco (cm)") {
                    TextField("Cintura", text: $waist)
                    TextField("Abdômen", text: $abdomen)
                    TextField("Quadril", text: $hip)
                    TextField("Tórax", text: $chest)
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
                    Button("Salvar") {
                        let measurement = BodyMeasurement(
                            measuredAt: Date(),
                            weightKg: initialWeight,
                            waistCm: Double(waist.replacingOccurrences(of: ",", with: ".")),
                            hipCm: Double(hip.replacingOccurrences(of: ",", with: ".")),
                            chestCm: Double(chest.replacingOccurrences(of: ",", with: ".")),
                            abdomenCm: Double(abdomen.replacingOccurrences(of: ",", with: ".")),
                            rightArmRelaxedCm: Double(arm.replacingOccurrences(of: ",", with: ".")),
                            rightThighCm: Double(thigh.replacingOccurrences(of: ",", with: ".")),
                            source: .clinicalAssessment
                        )
                        onSave(measurement)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SkinfoldsEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedProtocol: AntropometryProtocol
    let initialWeight: Double
    let profile: UserProfile?
    let onSave: (BodyMeasurement) -> Void

    @State private var chest: String = "10"
    @State private var triceps: String = "12"
    @State private var subscapular: String = "14"
    @State private var suprailiac: String = "11"
    @State private var abdomen: String = "16"
    @State private var thigh: String = "13"
    @State private var axillary: String = "9"
    @State private var biaFatPercent: String = "16.5"

    var body: some View {
        NavigationStack {
            Form {
                if selectedProtocol == .bia {
                    Section("Bioimpedância (BIA)") {
                        TextField("Gordura Corporal (%)", text: $biaFatPercent)
                    }
                } else {
                    Section("Dobras Cutâneas (mm)") {
                        if selectedProtocol == .pollock7 || profile?.sex == .male {
                            TextField("Peitoral", text: $chest)
                        }
                        if selectedProtocol == .pollock7 || profile?.sex == .female {
                            TextField("Tríceps", text: $triceps)
                        }
                        if selectedProtocol == .pollock7 {
                            TextField("Subescapular", text: $subscapular)
                            TextField("Axilar Média", text: $axillary)
                        }
                        if selectedProtocol == .pollock7 || profile?.sex == .female {
                            TextField("Suprailíaca", text: $suprailiac)
                        }
                        if selectedProtocol == .pollock7 || profile?.sex == .male {
                            TextField("Abdômen", text: $abdomen)
                        }
                        TextField("Coxa", text: $thigh)
                    }
                }
            }
            .navigationTitle("Avaliação \(selectedProtocol.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Calcular & Salvar") {
                        calculateAndSave()
                    }
                }
            }
        }
    }

    private func calculateAndSave() {
        let sex = profile?.sex ?? .male
        let age = Double(profile?.age ?? 30)

        if selectedProtocol == .bia {
            let fat = Double(biaFatPercent.replacingOccurrences(of: ",", with: ".")) ?? 16.0
            let fatKg = (initialWeight * (fat / 100.0)).rounded(to: 2)
            let leanKg = (initialWeight - fatKg).rounded(to: 2)

            let measurement = BodyMeasurement(
                measuredAt: Date(),
                weightKg: initialWeight,
                bodyFatPercent: fat,
                leanMassKg: leanKg,
                fatMassKg: fatKg,
                source: .bia
            )
            onSave(measurement)
            dismiss()
        } else {
            let skinfolds = SkinfoldMeasurements(
                chestMm: Double(chest.replacingOccurrences(of: ",", with: ".")),
                abdominalMm: Double(abdomen.replacingOccurrences(of: ",", with: ".")),
                middleAxillaryMm: Double(axillary.replacingOccurrences(of: ",", with: ".")),
                subscapularMm: Double(subscapular.replacingOccurrences(of: ",", with: ".")),
                suprailiacMm: Double(suprailiac.replacingOccurrences(of: ",", with: ".")),
                thighMm: Double(thigh.replacingOccurrences(of: ",", with: ".")),
                tricepsMm: Double(triceps.replacingOccurrences(of: ",", with: "."))
            )

            let result: BodyCompositionResult?
            if selectedProtocol == .pollock7 {
                result = BodyCompositionCalculator.calculate7Folds(
                    skinfolds: skinfolds,
                    weightKg: initialWeight,
                    ageYears: age,
                    sex: sex
                )
            } else {
                result = BodyCompositionCalculator.calculate3Folds(
                    skinfolds: skinfolds,
                    weightKg: initialWeight,
                    ageYears: age,
                    sex: sex
                )
            }

            if let r = result {
                let measurement = BodyMeasurement(
                    measuredAt: Date(),
                    weightKg: initialWeight,
                    bodyFatPercent: r.bodyFatPercent,
                    leanMassKg: r.leanMassKg,
                    fatMassKg: r.fatMassKg,
                    muscularMassKg: r.muscleMassKg,
                    boneMassKg: r.boneMassKg,
                    residualMassKg: r.residualMassKg,
                    skinfolds: skinfolds,
                    source: .clinicalAssessment
                )
                onSave(measurement)
            }
            dismiss()
        }
    }
}
