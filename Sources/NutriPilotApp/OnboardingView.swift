import SwiftUI
import UniformTypeIdentifiers
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

public struct OnboardingView: View {
    @Bindable var store: ProfileStore

    @State private var name: String = "João"
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -23, to: Date()) ?? Date()
    @State private var sex: BiologicalSex = .male
    @State private var heightCm: Double = 178
    @State private var weightKg: Double = 78.0
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var goal: NutritionGoal = .recomposition
    @State private var mealsPerDay: Int = 4

    // MARK: - Estado de Importação de Bioimpedância (PDF)
    @State private var showFileImporter: Bool = false
    @State private var importedReportName: String?
    @State private var bodyFatPercentage: Double?
    @State private var leanMassKg: Double?
    @State private var visceralFatLevel: Int?
    @State private var bodyWaterPercent: Double?
    @State private var importSuccessBanner: String?

    @State private var calculatedResult: NutritionCalculationResult?

    public init(store: ProfileStore = .shared) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // 1. Destaque: Autofill Inteligente via PDF de Bioimpedância
                autofillSection

                // 2. Identificação & Biometria (Editáveis a qualquer momento)
                Section("Identificação & Biometria") {
                    TextField("Nome ou Apelido", text: $name)

                    DatePicker("Nascimento", selection: $birthDate, displayedComponents: .date)
                        .onChange(of: birthDate) { _, _ in recalculate() }

                    Picker("Sexo Biológico", selection: $sex) {
                        ForEach(BiologicalSex.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .onChange(of: sex) { _, _ in recalculate() }

                    HStack {
                        Text("Altura")
                        Spacer()
                        Text("\(Int(heightCm)) cm")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $heightCm, in: 140...210, step: 1)
                        .onChange(of: heightCm) { _, _ in recalculate() }

                    HStack {
                        Text("Peso Atual")
                        Spacer()
                        Text(String(format: "%.1f kg", weightKg))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $weightKg, in: 40...150, step: 0.5)
                        .onChange(of: weightKg) { _, _ in recalculate() }
                }

                // 3. Métricas de Bioimpedância (se extraídas pelo PDF ou inseridas)
                if bodyFatPercentage != nil || leanMassKg != nil {
                    bioimpedanceSection
                }

                // 4. Rotina & Objetivo
                Section("Rotina & Objetivo") {
                    Picker("Nível de Atividade", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .onChange(of: activityLevel) { _, _ in recalculate() }

                    Picker("Objetivo Principal", selection: $goal) {
                        ForEach(NutritionGoal.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    .onChange(of: goal) { _, _ in recalculate() }

                    Stepper("Refeições por dia: \(mealsPerDay)", value: $mealsPerDay, in: 2...6)
                }

                // 5. Metas Sugeridas com Destaque para Fórmula Katch-McArdle ou Mifflin-St Jeor
                if let res = calculatedResult {
                    suggestedTargetsSection(result: res)
                }

                // 6. Botão de Início
                Section {
                    Button(action: finishOnboarding) {
                        Text("Iniciar NutriPilot")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.green)
                }
            }
            .navigationTitle("Configurar Perfil")
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImportResult(result)
            }
            .onAppear {
                recalculate()
            }
        }
    }

    // MARK: - Seção de Autofill com PDF

    private var autofillSection: some View {
        Section {
            Button {
                showFileImporter = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "doc.badge.plus")
                            .font(.title3.bold())
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Importar Exame de Bioimpedância")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Text("Preenchimento automático via PDF (InBody, Tanita, Avanutri, Laudos)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let banner = importSuccessBanner {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Laudo Importado com Sucesso")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        Text(banner)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Autofill Inteligente (Opcional)")
        }
    }

    // MARK: - Seção de Bioimpedância Editável

    private var bioimpedanceSection: some View {
        Section("Métricas de Bioimpedância (Editáveis)") {
            if let bf = bodyFatPercentage {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("% de Gordura Corporal")
                        Spacer()
                        Text(String(format: "%.1f%%", bf))
                            .foregroundColor(.orange)
                            .font(.subheadline.bold())
                    }
                    Slider(
                        value: Binding(
                            get: { bodyFatPercentage ?? 15.0 },
                            set: {
                                bodyFatPercentage = $0
                                recalculate()
                            }
                        ),
                        in: 3...55,
                        step: 0.1
                    )
                }
            }

            if let lm = leanMassKg {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Massa Magra Livre")
                        Spacer()
                        Text(String(format: "%.1f kg", lm))
                            .foregroundColor(.green)
                            .font(.subheadline.bold())
                    }
                    Slider(
                        value: Binding(
                            get: { leanMassKg ?? 50.0 },
                            set: {
                                leanMassKg = $0
                                recalculate()
                            }
                        ),
                        in: 20...120,
                        step: 0.1
                    )
                }
            }

            if let vf = visceralFatLevel {
                Stepper(
                    "Gordura Visceral: Nível \(vf)",
                    value: Binding(
                        get: { visceralFatLevel ?? 1 },
                        set: {
                            visceralFatLevel = $0
                            recalculate()
                        }
                    ),
                    in: 1...59
                )
            }

            if let bw = bodyWaterPercent {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Água Corporal")
                        Spacer()
                        Text(String(format: "%.1f%%", bw))
                            .foregroundColor(.cyan)
                            .font(.subheadline.bold())
                    }
                    Slider(
                        value: Binding(
                            get: { bodyWaterPercent ?? 55.0 },
                            set: {
                                bodyWaterPercent = $0
                                recalculate()
                            }
                        ),
                        in: 30...80,
                        step: 0.5
                    )
                }
            }
        }
    }

    // MARK: - Seção de Metas Sugeridas

    private func suggestedTargetsSection(result: NutritionCalculationResult) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.green)
                    Text("METAS INICIAIS SUGERIDAS")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(result.formulaUsed)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(result.formulaUsed.contains("Katch-McArdle") ? Color.green.opacity(0.18) : Color.blue.opacity(0.12))
                        .foregroundColor(result.formulaUsed.contains("Katch-McArdle") ? .green : .blue)
                        .cornerRadius(6)
                }

                HStack {
                    Text("\(Int(result.targetCalories)) kcal")
                        .font(.title2.bold())
                        .foregroundColor(.orange)
                    Spacer()
                    Text("Água: \(Int(result.targetWaterMl)) ml")
                        .font(.headline)
                        .foregroundColor(.cyan)
                }

                HStack(spacing: 16) {
                    macroBadge(name: "Proteína", grams: Int(result.targetProteinGrams), color: .blue)
                    macroBadge(name: "Carboidratos", grams: Int(result.targetCarbsGrams), color: .green)
                    macroBadge(name: "Gordura", grams: Int(result.targetFatGrams), color: .purple)
                }

                if result.formulaUsed.contains("Katch-McArdle") {
                    Text("✨ Baseado em Katch-McArdle com dados de bioimpedância — precisão metabólica avançada calibrada na massa magra real.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                } else {
                    Text("⚠️ Estimativa inicial por Mifflin-St Jeor — será calibrada após 14 dias de registros reais de peso.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Cálculo Imediato")
        }
    }

    private func macroBadge(name: String, grams: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(grams)g")
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
    }

    // MARK: - Lógica de Importação de Arquivo

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: url) {
                let parsed = BioimpedancePDFParser.parse(pdfData: data)
                applyParsedData(parsed, fileName: url.lastPathComponent)
            }
        case .failure(let error):
            print("Erro ao importar PDF de bioimpedância: \(error.localizedDescription)")
        }
    }

    private func applyParsedData(_ parsed: BioimpedanceParsedData, fileName: String) {
        importedReportName = fileName

        if let n = parsed.name, !n.isEmpty {
            name = n
        }
        if let b = parsed.birthDate {
            birthDate = b
        }
        if let s = parsed.sex {
            sex = s
        }
        if let h = parsed.heightCm, h > 0 {
            heightCm = h
        }
        if let w = parsed.weightKg, w > 0 {
            weightKg = w
        }

        if let bf = parsed.bodyFatPercentage {
            bodyFatPercentage = bf
        }
        if let lm = parsed.leanMassKg {
            leanMassKg = lm
        }
        if let vf = parsed.visceralFatLevel {
            visceralFatLevel = vf
        }
        if let bw = parsed.bodyWaterLitersOrPercentage {
            bodyWaterPercent = bw
        }

        let equipment = parsed.detectedEquipmentOrClinic ?? "Laudo Clínico"
        importSuccessBanner = "Laudo detectado (\(equipment)). Dados preenchidos automaticamente e editáveis abaixo."

        recalculate()
    }

    // MARK: - Recálculo das Metas

    private func recalculate() {
        let tempProfile = UserProfile(
            name: name,
            birthDate: birthDate,
            sex: sex,
            heightCm: heightCm,
            currentWeightKg: weightKg,
            activityLevel: activityLevel,
            goal: goal,
            preferredMealsPerDay: mealsPerDay
        )
        calculatedResult = NutritionCalculator.calculateFullTarget(
            from: tempProfile,
            leanMassKg: leanMassKg,
            bodyFatPercentage: bodyFatPercentage
        )
    }

    // MARK: - Finalização e Persistência do Onboarding

    private func finishOnboarding() {
        let profile = UserProfile(
            name: name,
            birthDate: birthDate,
            sex: sex,
            heightCm: heightCm,
            currentWeightKg: weightKg,
            activityLevel: activityLevel,
            goal: goal,
            preferredMealsPerDay: mealsPerDay
        )

        let targetToSave: NutritionTarget?
        if let res = calculatedResult {
            targetToSave = NutritionTarget(
                calories: res.targetCalories,
                proteinGrams: res.targetProteinGrams,
                carbsGrams: res.targetCarbsGrams,
                fatGrams: res.targetFatGrams,
                fiberGrams: res.targetFiberGrams,
                waterMl: res.targetWaterMl,
                source: .initialCalculation,
                notes: "Estimativa calculada por \(res.formulaUsed)"
            )
        } else {
            targetToSave = nil
        }

        store.saveProfile(profile, target: targetToSave)

        // Registrar primeira medição corporal (com bioimpedância se houver)
        let source: MeasurementSource = (bodyFatPercentage != nil || leanMassKg != nil) ? .bia : .manual
        let fatMass: Double?
        if let bf = bodyFatPercentage {
            fatMass = (weightKg * (bf / 100.0)).rounded(to: 2)
        } else if let lm = leanMassKg {
            fatMass = max(0.0, weightKg - lm).rounded(to: 2)
        } else {
            fatMass = nil
        }

        let measurement = BodyMeasurement(
            measuredAt: Date(),
            weightKg: weightKg,
            bodyFatPercent: bodyFatPercentage,
            waterPercent: bodyWaterPercent,
            visceralFatLevel: visceralFatLevel,
            leanMassKg: leanMassKg,
            fatMassKg: fatMass,
            source: source,
            isReference: true
        )
        BodyMeasurementStore.shared.addMeasurement(measurement)
    }
}
