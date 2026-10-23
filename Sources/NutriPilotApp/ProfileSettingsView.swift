import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

/// Tela completa de visualização e edição das configurações de perfil, rotina, biometria e metas metabólicas.
public struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    public var profileStore: ProfileStore
    public var bodyStore: BodyMeasurementStore

    // MARK: - Estado Editável
    @State private var name: String
    @State private var birthDate: Date
    @State private var sex: BiologicalSex
    @State private var heightCm: Double
    @State private var weightKg: Double
    @State private var activityLevel: ActivityLevel
    @State private var goal: NutritionGoal
    @State private var preferredMealsPerDay: Int
    @State private var autoRecalculateTargets: Bool = true

    // Bioimpedância
    @State private var isShowingBioimpedanceSheet: Bool = false
    @State private var showSavedAlert: Bool = false
    @State private var hapticTrigger: Int = 0

    public init(
        profileStore: ProfileStore = .shared,
        bodyStore: BodyMeasurementStore = .shared
    ) {
        self.profileStore = profileStore
        self.bodyStore = bodyStore

        let p = profileStore.currentProfile ?? UserProfile(
            name: "Usuário",
            birthDate: Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date(),
            sex: .male,
            heightCm: 175,
            currentWeightKg: 75.0,
            activityLevel: .moderate,
            goal: .recomposition,
            preferredMealsPerDay: 4
        )

        _name = State(initialValue: p.name)
        _birthDate = State(initialValue: p.birthDate)
        _sex = State(initialValue: p.sex)
        _heightCm = State(initialValue: p.heightCm)
        _weightKg = State(initialValue: p.currentWeightKg)
        _activityLevel = State(initialValue: p.activityLevel)
        _goal = State(initialValue: p.goal)
        _preferredMealsPerDay = State(initialValue: p.preferredMealsPerDay)
    }

    // MARK: - Computed Properties para Live Preview
    private var temporaryProfile: UserProfile {
        UserProfile(
            name: name.isEmpty ? "Usuário" : name,
            birthDate: birthDate,
            sex: sex,
            heightCm: heightCm,
            currentWeightKg: weightKg,
            activityLevel: activityLevel,
            goal: goal,
            dietaryRestrictions: profileStore.currentProfile?.dietaryRestrictions ?? [],
            preferredMealsPerDay: preferredMealsPerDay
        )
    }

    private var latestBIA: BodyMeasurement? {
        bodyStore.sortedMeasurements.reversed().first(where: { $0.source == .bia || $0.bodyFatPercent != nil })
    }

    private var previewBreakdown: MetabolicBreakdown {
        NutritionCalculator.calculateMetabolicBreakdown(
            profile: temporaryProfile,
            leanMassKg: latestBIA?.leanMassKg,
            bodyFatPercentage: latestBIA?.bodyFatPercent
        )
    }

    private var previewTarget: NutritionCalculationResult {
        NutritionCalculator.calculateFullTarget(
            from: temporaryProfile,
            leanMassKg: latestBIA?.leanMassKg,
            bodyFatPercentage: latestBIA?.bodyFatPercent
        )
    }

    public var body: some View {
        NavigationStack {
            Form {
                // 1. Identificação Básica
                identificationSection

                // 2. Biometria Corporal
                biometricsSection

                // 3. Rotina & Nível de Atividade Diária
                routineSection

                // 4. Objetivo Nutricional & Estrutura de Refeições
                goalSection

                // 5. Integração com Laudo de Bioimpedância (PDF)
                bioimpedanceShortcutSection

                // 6. Projeção Metabólica em Tempo Real
                liveMetabolicPreviewSection

                // 7. Ação de Salvar
                saveActionSection
            }
            .navigationTitle("Editar Configurações")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saveChanges()
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $isShowingBioimpedanceSheet) {
                BioimpedanceAnalysisSheet(
                    profileStore: profileStore,
                    bodyStore: bodyStore
                )
            }
            .alert("Configurações Salvas", isPresented: $showSavedAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Seu perfil, rotina e metas metabólicas foram atualizados com sucesso no NutriPilot.")
            }
        }
    }

    // MARK: - 1. Identificação Básica
    private var identificationSection: some View {
        Section(header: Text("Identificação")) {
            TextField("Nome completo ou apelido", text: $name)

            DatePicker("Data de Nascimento", selection: $birthDate, displayedComponents: .date)

            Picker("Sexo Biológico", selection: $sex) {
                ForEach(BiologicalSex.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
        }
    }

    // MARK: - 2. Biometria
    private var biometricsSection: some View {
        Section(header: Text("Biometria")) {
            Picker("Altura", selection: $heightCm) {
                ForEach(130...230, id: \.self) { cm in
                    Text("\(cm) cm").tag(Double(cm))
                }
            }

            Picker("Peso Atual", selection: $weightKg) {
                ForEach(Array(stride(from: 35.0, through: 200.0, by: 0.5)), id: \.self) { kg in
                    Text(String(format: "%.1f kg", kg)).tag(kg)
                }
            }
        }
    }

    // MARK: - 3. Rotina & Nível de Atividade
    private var routineSection: some View {
        Section(
            header: Text("Rotina & Atividade Física"),
            footer: Text("O nível de atividade define o multiplicador de gasto calórico total (NEAT + EAT).")
        ) {
            Picker("Nível de Atividade", selection: $activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }

            HStack {
                Text("Fator Multiplicador")
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2fx TMB", activityLevel.multiplier))
                    .bold()
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - 4. Objetivo & Refeições
    private var goalSection: some View {
        Section(header: Text("Objetivo & Dieta")) {
            Picker("Objetivo Principal", selection: $goal) {
                ForEach(NutritionGoal.allCases, id: \.self) { g in
                    Text(g.rawValue).tag(g)
                }
            }

            Stepper("Refeições por dia: \(preferredMealsPerDay)", value: $preferredMealsPerDay, in: 2...6)

            Toggle("Recalcular Metas Automaticamente", isOn: $autoRecalculateTargets)
        }
    }

    // MARK: - 5. Bioimpedância
    private var bioimpedanceShortcutSection: some View {
        Section(
            header: Text("Composição Corporal & Bioimpedância"),
            footer: Text("O envio de laudos PDF de balanças como InBody, Seca, Avanutri ou Tanita substitui estimativas genéricas pelo cálculo baseado em massa magra (Katch-McArdle).")
        ) {
            if let bia = latestBIA {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Último Laudo Aplicado")
                            .font(.subheadline.bold())
                        HStack(spacing: 12) {
                            if let bf = bia.bodyFatPercent {
                                Text(String(format: "%.1f%% Gordura", bf))
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                            if let lean = bia.leanMassKg {
                                Text(String(format: "%.1f kg Magra", lean))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
            }

            Button {
                isShowingBioimpedanceSheet = true
                hapticTrigger += 1
            } label: {
                HStack {
                    Image(systemName: "doc.viewfinder.fill")
                        .foregroundColor(.green)
                    Text("Reanalisar por Laudo de Bioimpedância (PDF)")
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - 6. Live Metabolic Preview
    private var liveMetabolicPreviewSection: some View {
        Section(header: Text("Projeção Metabólica em Tempo Real")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Fórmula Ativa:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(previewBreakdown.formulaUsed)
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }

                HStack(spacing: 8) {
                    metabolicCard(title: "TMB", value: "\(Int(previewBreakdown.bmr))", unit: "kcal/dia", color: .blue)
                    metabolicCard(title: "Gasto Total (GET)", value: "\(Int(previewBreakdown.tdee))", unit: "kcal/dia", color: .orange)
                    metabolicCard(title: "Meta Diária", value: "\(Int(previewTarget.targetCalories))", unit: "kcal/dia", color: .green)
                }

                Divider()

                HStack {
                    macroBadge(title: "Proteína", grams: previewTarget.targetProteinGrams, color: .purple)
                    Spacer()
                    macroBadge(title: "Carboidrato", grams: previewTarget.targetCarbsGrams, color: .orange)
                    Spacer()
                    macroBadge(title: "Gordura", grams: previewTarget.targetFatGrams, color: .yellow)
                    Spacer()
                    macroBadge(title: "Água", grams: previewTarget.targetWaterMl / 1000.0, unit: "L", color: .blue)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func metabolicCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    private func macroBadge(title: String, grams: Double, unit: String = "g", color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(unit == "g" ? "\(Int(grams))g" : String(format: "%.1fL", grams))
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }

    // MARK: - 7. Ação de Salvar
    private var saveActionSection: some View {
        Section {
            Button(action: saveChanges) {
                Text("Salvar Alterações")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.green)
        }
    }

    private func saveChanges() {
        profileStore.updateProfile(
            name: name,
            birthDate: birthDate,
            sex: sex,
            heightCm: heightCm,
            currentWeightKg: weightKg,
            activityLevel: activityLevel,
            goal: goal,
            preferredMealsPerDay: preferredMealsPerDay,
            recalculateTarget: autoRecalculateTargets,
            leanMassKg: latestBIA?.leanMassKg,
            bodyFatPercentage: latestBIA?.bodyFatPercent
        )

        // Se o peso foi alterado, registra também no histórico de pesagem
        _ = bodyStore.logWeight(kg: weightKg)

        hapticTrigger += 1
        showSavedAlert = true
    }
}
