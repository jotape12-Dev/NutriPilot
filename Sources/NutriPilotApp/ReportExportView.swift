import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Tela modal para pré-visualização e exportação de relatórios clínicos e backups
/// para compartilhamento com nutricionistas via WhatsApp, AirDrop, E-mail ou Arquivos.
public struct ReportExportView: View {
    public var profileStore: ProfileStore
    public var mealStore: MealStore
    public var waterStore: WaterStore
    public var bodyStore: BodyMeasurementStore

    @Environment(\.dismiss) private var dismiss
    @State private var previewMode: PreviewMode = .visual
    @State private var copiedTrigger: Int = 0
    @State private var isCopiedBannerVisible: Bool = false
    @State private var hapticTrigger: Int = 0

    public enum PreviewMode: String, CaseIterable, Identifiable {
        case visual = "Resumo Clínico"
        case markdown = "Documento Markdown"

        public var id: String { rawValue }
    }

    public init(
        profileStore: ProfileStore = .shared,
        mealStore: MealStore = .shared,
        waterStore: WaterStore = .shared,
        bodyStore: BodyMeasurementStore = .shared
    ) {
        self.profileStore = profileStore
        self.mealStore = mealStore
        self.waterStore = waterStore
        self.bodyStore = bodyStore
    }

    private var report: PatientReport {
        ReportExporter.buildReport(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore
        )
    }

    private var markdownText: String {
        ReportExporter.exportMarkdownReport(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore
        )
    }

    private var jsonData: Data {
        ReportExporter.exportJSON(
            profileStore: profileStore,
            mealStore: mealStore,
            waterStore: waterStore,
            bodyStore: bodyStore
        )
    }

    private var patientNameSanitized: String {
        let raw = report.profile?.name ?? "Paciente"
        let allowed = CharacterSet.alphanumerics
        return raw.components(separatedBy: allowed.inverted).joined()
    }

    private var reportFileURL: URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Relatorio_Clinico_NutriPilot_\(patientNameSanitized).md"
        let url = tempDir.appendingPathComponent(fileName)
        try? markdownText.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private var backupFileURL: URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "NutriPilot_Backup_\(patientNameSanitized).json"
        let url = tempDir.appendingPathComponent(fileName)
        try? jsonData.write(to: url)
        return url
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header de Status e Emissão
                    clinicalHeaderBanner

                    // Botões de Ação Rápida (ShareLink do SwiftUI)
                    exportActionButtonsSection

                    // Seletor de Modo de Visualização
                    Picker("Modo de Exibição", selection: $previewMode) {
                        ForEach(PreviewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Conteúdo da Pré-visualização
                    if previewMode == .visual {
                        visualPreviewCards
                    } else {
                        markdownPreviewView
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appBackground)
            .navigationTitle("Exportar Relatório")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .sensoryFeedback(.success, trigger: copiedTrigger)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .overlay(alignment: .top) {
                if isCopiedBannerVisible {
                    copiedFeedbackBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Banner de Cabeçalho Clínico

    private var clinicalHeaderBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("NutriPilot Clinical Engine", systemImage: "cross.case.fill")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)

                Spacer()

                Text("Adesão 7 Dias")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }

            Text("Relatório Nutricional Consolidado")
                .font(.title3.bold())

            Text("Pronto para compartilhamento direto com seu nutricionista por WhatsApp, AirDrop ou E-mail.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Botões de Exportação com ShareLink

    private var exportActionButtonsSection: some View {
        VStack(spacing: 12) {
            // Botão Principal: Relatório Clínico (.md / .txt / envio direto)
            ShareLink(
                item: reportFileURL,
                preview: SharePreview(
                    "Relatório Clínico - \(report.profile?.name ?? "NutriPilot")",
                    image: Image(systemName: "doc.text.fill")
                )
            ) {
                HStack {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exportar Relatório Clínico (.txt / .md / .pdf)")
                            .font(.headline)
                        Text("WhatsApp, AirDrop, E-mail ou Impressão")
                            .font(.caption)
                            .opacity(0.85)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(14)
            }

            // Botão Secundário: Backup de Dados (.json)
            ShareLink(
                item: backupFileURL,
                preview: SharePreview(
                    "Backup de Dados NutriPilot - \(report.profile?.name ?? "JSON")",
                    image: Image(systemName: "arrow.down.doc.fill")
                )
            ) {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exportar Backup de Dados (.json)")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Text("Estrutura completa de perfil, pesagens e medições")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appCardBackground)
                .cornerRadius(14)
            }

            // Botão de Cópia Rápida de Texto Clínico
            Button {
                copyReportToClipboard()
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.subheadline)
                    Text("Copiar Texto do Relatório para Área de Transferência")
                        .font(.subheadline.bold())
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundColor(.primary)
                .background(Color.appCardBackground)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Cards de Pré-Visualização Visual

    private var visualPreviewCards: some View {
        VStack(spacing: 16) {
            // Card 1: Perfil do Paciente
            patientProfileCard

            // Card 2: Metas Nutricionais Diárias
            targetsCard

            // Card 3: Médias dos Últimos 7 Dias
            sevenDayAveragesCard

            // Card 4: Evolução Corporal e Antropometria
            bodyEvolutionCard
        }
        .padding(.horizontal)
    }

    // Card 1: Dados do Paciente
    private var patientProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("1. Identificação do Paciente", systemImage: "person.crop.circle.fill")
                .font(.headline)
                .foregroundColor(.green)

            Divider()

            if let p = report.profile {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Nome:").font(.subheadline).foregroundColor(.secondary)
                        Text(p.name).font(.subheadline.bold())
                    }
                    GridRow {
                        Text("Idade / Sexo:").font(.subheadline).foregroundColor(.secondary)
                        Text("\(p.age) anos • \(p.sex.rawValue)").font(.subheadline)
                    }
                    GridRow {
                        Text("Estatura:").font(.subheadline).foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", p.heightCm)) cm").font(.subheadline)
                    }
                    GridRow {
                        Text("Peso Inicial:").font(.subheadline).foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", p.currentWeightKg)) kg").font(.subheadline)
                    }
                    GridRow {
                        Text("Objetivo:").font(.subheadline).foregroundColor(.secondary)
                        Text(p.goal.rawValue).font(.subheadline.bold()).foregroundColor(.green)
                    }
                }
            } else {
                Text("Perfil não preenchido.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .cornerRadius(14)
    }

    // Card 2: Metas Planejadas
    private var targetsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("2. Metas Nutricionais Estabelecidas", systemImage: "target")
                .font(.headline)
                .foregroundColor(.orange)

            Divider()

            if let t = report.target {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    targetMetricBadge(title: "Calorias", value: "\(Int(t.calories)) kcal", icon: "flame.fill", color: .orange)
                    targetMetricBadge(title: "Proteína", value: "\(Int(t.proteinGrams))g", icon: "shield.fill", color: .red)
                    targetMetricBadge(title: "Carboidratos", value: "\(Int(t.carbsGrams))g", icon: "bolt.fill", color: .green)
                    targetMetricBadge(title: "Gorduras", value: "\(Int(t.fatGrams))g", icon: "circle.circle.fill", color: .yellow)
                    targetMetricBadge(title: "Fibras", value: "\(Int(t.fiberGrams))g", icon: "leaf.fill", color: .mint)
                    targetMetricBadge(title: "Água Diária", value: "\(Int(t.waterMl)) ml", icon: "drop.fill", color: .blue)
                }
            } else {
                Text("Nenhuma meta cadastrada.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .cornerRadius(14)
    }

    private func targetMetricBadge(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption.bold())
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // Card 3: Médias dos Últimos 7 Dias
    private var sevenDayAveragesCard: some View {
        let summary = report.sevenDayNutrition
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("3. Médias de Consumo (7 Dias)", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Text("Últimos 7 dias")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calorias Médias")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(summary.averageCalories)) kcal")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }

                Divider().frame(height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hidratação Média")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(summary.averageWaterMl)) ml")
                        .font(.title3.bold())
                        .foregroundColor(.blue)
                }

                Divider().frame(height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Proteína Média")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(summary.averageProteinGrams))g")
                        .font(.title3.bold())
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Carboidratos: \(Int(summary.averageCarbsGrams))g")
                Text("•")
                Text("Gorduras: \(Int(summary.averageFatGrams))g")
                Text("•")
                Text("Fibras: \(Int(summary.averageFiberGrams))g")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .cornerRadius(14)
    }

    // Card 4: Evolução Corporal e Antropometria
    private var bodyEvolutionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("4. Evolução Antropométrica", systemImage: "figure.walk")
                .font(.headline)
                .foregroundColor(.purple)

            Divider()

            if let pred = report.weightPrediction {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peso de Tendência (EWMA)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", pred.currentTrendWeightKg)) kg")
                            .font(.headline.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Ritmo Semanal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(pred.statusDescription)
                            .font(.caption.bold())
                            .foregroundColor(pred.weeklyVelocityKg != nil ? .purple : .secondary)
                    }
                }
                .padding(8)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(8)
            }

            if let circ = report.latestCircumferences {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Circunferências Mais Recentes:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack {
                        if let w = circ.waistCm { Text("Cintura: \(String(format: "%.1f", w))cm") }
                        if let h = circ.hipCm { Text("• Quadril: \(String(format: "%.1f", h))cm") }
                        if let rcq = circ.waistToHipRatio { Text("• RCQ: \(String(format: "%.2f", rcq))") }
                    }
                    .font(.caption)
                }
            }

            if let comp = report.bodyComposition {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("% Gordura (\(comp.protocolUsed))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", comp.bodyFatPercent))%")
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Massa Magra")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", comp.leanMassKg)) kg")
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Massa Gorda")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", comp.fatMassKg)) kg")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .cornerRadius(14)
    }

    // MARK: - Pré-visualização do Documento Markdown

    private var markdownPreviewView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Código Markdown Formatado")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    copyReportToClipboard()
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(markdownText)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appTertiaryBackground)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(14)
        .padding(.horizontal)
    }

    // MARK: - Banner de Confirmação de Cópia

    private var copiedFeedbackBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Relatório copiado para a Área de Transferência!")
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 8)
        .padding(.top, 8)
    }

    // MARK: - Ações

    private func copyReportToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = markdownText
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdownText, forType: .string)
        #endif

        copiedTrigger += 1
        hapticTrigger += 1

        withAnimation(.spring()) {
            isCopiedBannerVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut) {
                isCopiedBannerVisible = false
            }
        }
    }
}
