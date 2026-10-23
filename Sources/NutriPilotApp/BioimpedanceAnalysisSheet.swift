import SwiftUI
import UniformTypeIdentifiers
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

/// Folha modal de reanálise metabólica inteligente baseada no envio de laudos de bioimpedância em PDF.
public struct BioimpedanceAnalysisSheet: View {
    @Environment(\.dismiss) private var dismiss
    public var profileStore: ProfileStore
    public var bodyStore: BodyMeasurementStore

    @State private var isShowingFileImporter: Bool = false
    @State private var importedFileName: String?
    @State private var parsedData: BioimpedanceParsedData?
    @State private var metabolicBreakdown: MetabolicBreakdown?
    @State private var recalculatedTarget: NutritionCalculationResult?
    @State private var errorMessage: String?
    @State private var hapticTrigger: Int = 0

    public init(
        profileStore: ProfileStore = .shared,
        bodyStore: BodyMeasurementStore = .shared
    ) {
        self.profileStore = profileStore
        self.bodyStore = bodyStore
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Banner de Upload de Laudo
                    uploadSection

                    if let data = parsedData, let breakdown = metabolicBreakdown, let target = recalculatedTarget {
                        // 2. Variáveis Extraídas da Bioimpedância
                        extractedMetricsSection(data: data)

                        // 3. Reanálise Metabólica Aprofundada (TMB Real + Decomposição do Gasto)
                        metabolicDeepDiveSection(breakdown: breakdown)

                        // 4. Proposta de Nova Calibração de Metas
                        recalculatedTargetSection(target: target)

                        // 5. Botão de Aplicação e Persistência
                        applyButton(data: data)
                    } else if let error = errorMessage {
                        errorBanner(error)
                    }
                }
                .padding()
            }
            .navigationTitle("Reanálise por Bioimpedância")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    // MARK: - 1. Seção de Upload

    private var uploadSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 28))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Envio de Laudo de Bioimpedância")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Compatível com InBody, Avanutri, Seca e Tanita")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Button {
                isShowingFileImporter = true
                hapticTrigger += 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc.fill")
                    Text(importedFileName == nil ? "Selecionar PDF do Exame" : "Substituir Laudo PDF")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if let name = importedFileName {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Exame carregado: \(name)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }

    // MARK: - 2. Variáveis Extraídas

    private func extractedMetricsSection(data: BioimpedanceParsedData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DADOS EXTRAÍDOS DO LAUDO")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if let equipment = data.detectedEquipmentOrClinic {
                    Text(equipment)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if let w = data.weightKg {
                    metricBadge(title: "Peso Total", value: String(format: "%.1f kg", w), icon: "scalemass.fill", color: .blue)
                }
                if let lm = data.leanMassKg {
                    metricBadge(title: "Massa Magra", value: String(format: "%.1f kg", lm), icon: "figure.strengthtraining.traditional", color: .green)
                }
                if let bf = data.bodyFatPercentage {
                    metricBadge(title: "Gordura Corporal", value: String(format: "%.1f%%", bf), icon: "percent", color: .purple)
                }
                if let water = data.bodyWaterLitersOrPercentage {
                    metricBadge(title: "Água Corporal", value: String(format: "%.1f L/%%", water), icon: "drop.fill", color: .cyan)
                }
                if let vf = data.visceralFatLevel {
                    metricBadge(title: "Gordura Visceral", value: "Nível \(vf)", icon: "heart.fill", color: .orange)
                }
                if let bmr = data.basalMetabolicRateKcal {
                    metricBadge(title: "TMB Medida", value: "\(Int(bmr)) kcal", icon: "flame.fill", color: .red)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func metricBadge(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 3. Reanálise Metabólica Aprofundada

    private func metabolicDeepDiveSection(breakdown: MetabolicBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.green)
                Text("REANÁLISE METABÓLICA INTELIGENTE")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }

            // Comparativo de TMB
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Taxa Metabólica Basal Real")
                        .font(.subheadline.bold())
                    Text("Calculada via \(breakdown.formulaUsed)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(breakdown.bmr)) kcal")
                        .font(.title3.bold())
                        .foregroundColor(.green)
                    let sign = breakdown.bmrDeltaVsMifflin >= 0 ? "+" : ""
                    Text("\(sign)\(Int(breakdown.bmrDeltaVsMifflin)) kcal vs fórmula cega")
                        .font(.caption2.bold())
                        .foregroundColor(breakdown.bmrDeltaVsMifflin >= 0 ? .green : .orange)
                }
            }
            .padding(12)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Decomposição dos Gastos Diários
            Text("QUANTIFICAÇÃO COMPLETA DO GASTO DIÁRIO (TDEE)")
                .font(.caption2.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                expenditureRow(title: "TMB (Gasto em Repouso Vital)", value: "\(Int(breakdown.bmr)) kcal", icon: "bed.double.fill", color: .blue)
                expenditureRow(title: "NEAT (Atividades Cotidianas)", value: "\(Int(breakdown.neat)) kcal", icon: "figure.walk", color: .teal)
                expenditureRow(title: "EAT (Gasto em Treinos/Exercício)", value: "\(Int(breakdown.eat)) kcal", icon: "figure.run", color: .orange)
                expenditureRow(title: "TEF (Termogênese dos Alimentos)", value: "\(Int(breakdown.tef)) kcal", icon: "fork.knife", color: .purple)
                Divider()
                HStack {
                    Text("Gasto Energético Total Diário")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(Int(breakdown.tdee)) kcal")
                        .font(.headline.bold())
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func expenditureRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
        }
    }

    // MARK: - 4. Proposta de Nova Calibração de Metas

    private func recalculatedTargetSection(target: NutritionCalculationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOVA CALIBRAÇÃO SUGERIDA PARA SEU OBJETIVO")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                targetPill(title: "Calorias", value: "\(Int(target.targetCalories)) kcal", color: .orange)
                targetPill(title: "Proteína", value: "\(Int(target.targetProteinGrams))g", color: .blue)
                targetPill(title: "Carbos", value: "\(Int(target.targetCarbsGrams))g", color: .green)
                targetPill(title: "Gordura", value: "\(Int(target.targetFatGrams))g", color: .purple)
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func targetPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 5. Botão de Aplicação

    private func applyButton(data: BioimpedanceParsedData) -> some View {
        Button {
            applyCalibration(data: data)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Aplicar Nova Calibração e Salvar Exame")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.green.opacity(0.3), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(msg)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Ações e Processamento

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Permissão negada para acessar o arquivo PDF."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                importedFileName = url.lastPathComponent
                let parsed = BioimpedancePDFParser.parse(pdfData: data)
                self.parsedData = parsed

                guard let profile = profileStore.currentProfile else { return }

                // Calcula a decomposição metabólica aprofundada
                let breakdown = NutritionCalculator.calculateMetabolicBreakdown(
                    profile: profile,
                    leanMassKg: parsed.leanMassKg,
                    bodyFatPercentage: parsed.bodyFatPercentage,
                    measuredBMR: parsed.basalMetabolicRateKcal
                )
                self.metabolicBreakdown = breakdown

                // Calcula as novas metas completas
                let newTarget = NutritionCalculator.calculateFullTarget(
                    from: profile,
                    leanMassKg: parsed.leanMassKg,
                    bodyFatPercentage: parsed.bodyFatPercentage
                )
                self.recalculatedTarget = newTarget
                self.errorMessage = nil
            } catch {
                errorMessage = "Erro ao processar o PDF: \(error.localizedDescription)"
            }

        case .failure(let err):
            errorMessage = "Falha ao abrir o arquivo: \(err.localizedDescription)"
        }
    }

    private func applyCalibration(data: BioimpedanceParsedData) {
        guard let profile = profileStore.currentProfile else { return }

        // 1. Atualiza o perfil com o peso do laudo e calibra as metas via Katch-McArdle
        profileStore.updateProfile(
            heightCm: data.heightCm ?? profile.heightCm,
            currentWeightKg: data.weightKg ?? profile.currentWeightKg,
            recalculateTarget: true,
            leanMassKg: data.leanMassKg,
            bodyFatPercentage: data.bodyFatPercentage
        )

        // 2. Salva o registro da bioimpedância no histórico corporal
        if let measurement = data.toBodyMeasurement(date: Date(), source: .bia) {
            _ = bodyStore.addMeasurement(measurement)
        }

        hapticTrigger += 1
        dismiss()
    }
}
