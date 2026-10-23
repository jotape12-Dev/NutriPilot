import SwiftUI
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

public struct WaterView: View {
    public var targetWaterMl: Double
    public var store: WaterStore

    @State private var hapticTrigger: Int = 0
    @State private var isLiveActivityActive: Bool = false

    public init(targetWaterMl: Double = 3000, store: WaterStore = .shared) {
        self.targetWaterMl = targetWaterMl
        self.store = store
    }

    private var todayLogs: [WaterLog] {
        store.logs(for: Date()).reversed() // mais recentes primeiro
    }

    private var currentConsumed: Double {
        store.totalWater(for: Date())
    }

    private var progressRatio: Double {
        guard targetWaterMl > 0 else { return 0 }
        return currentConsumed / targetWaterMl
    }

    private var pacingStatus: WaterReminderStatus {
        store.reminderStatus(at: Date(), targetWaterMl: targetWaterMl)
    }

    private var pacingBreakdown: WaterPacingBreakdown {
        store.pacingBreakdown(at: Date(), targetWaterMl: targetWaterMl)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Card Completo de Ritmo Saudável de Hidratação & Lembretes
                    healthyPacingCard
                        .padding(.top, 8)
                        .padding(.horizontal)

                    // Progresso Circular Animado
                    circularProgressView

                    // Botões Rápidos de 1 Toque
                    quickButtonsSection

                    // Ações de Ajuste (Desfazer)
                    if !todayLogs.isEmpty {
                        undoButton
                    }

                    // Histórico de Hoje
                    todayLogsSection
                }
                .padding(.bottom, 32)
            }
            .onAppear {
                isLiveActivityActive = WaterLiveActivityManager.shared.isActivityActive
            }
            .navigationTitle("Hidratação")
            .background(Color.appBackground)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .toolbar {
                if !todayLogs.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                _ = store.undoLastLog()
                                hapticTrigger += 1
                            }
                        } label: {
                            Label("Desfazer", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Componentes de UI

    private var circularProgressView: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.18), lineWidth: 22)

            Circle()
                .trim(from: 0, to: min(1.0, progressRatio))
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.8), Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: currentConsumed)

            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.cyan)

                Text("\(Int(currentConsumed))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Text("de \(Int(targetWaterMl)) ml")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                Text(String(format: "%.0f%% da meta", min(100.0, progressRatio * 100)))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.15))
                    .foregroundColor(.cyan)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 225, height: 225)
        .padding(.vertical, 10)
    }

    private var healthyPacingCard: some View {
        let pacing = pacingBreakdown
        let statusColor: Color = {
            switch pacing.status {
            case .targetAchieved, .onTrack: return .green
            case .behind: return .orange
            case .ahead: return .blue
            case .outsideWindow: return .secondary
            }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .foregroundColor(statusColor)
                    Text("RITMO SAUDÁVEL (PACING)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(pacing.status.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            // Estatísticas fisiológicas do ritmo
            HStack(spacing: 8) {
                pacingMetricBox(
                    title: "Taxa Fisiológica",
                    value: "\(Int(pacing.healthyHourlyRateMl))",
                    unit: "ml/hora",
                    color: .cyan
                )

                pacingMetricBox(
                    title: "Intervalo Atual",
                    value: "\(Int(pacing.intervalTargetMl))",
                    unit: "\(pacing.currentIntervalStartHour)h - \(pacing.currentIntervalEndHour)h",
                    color: .blue
                )

                pacingMetricBox(
                    title: "Esperado Agora",
                    value: "\(Int(pacing.expectedConsumedMl))",
                    unit: "ml acumulados",
                    color: statusColor
                )
            }

            // Conselho clínico / orientador
            Text(pacing.advice)
                .font(.footnote)
                .foregroundColor(.primary)
                .padding(.top, 2)

            Divider()

            // Controle de Notificações com Opt-in
            VStack(spacing: 10) {
                Toggle(isOn: Binding(
                    get: { store.reminderConfig.isEnabled },
                    set: { enabled in
                        handleReminderToggle(enabled)
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avisos Inteligentes de Intervalo")
                            .font(.subheadline.bold())
                        Text("Notifica a cada intervalo para beber no ritmo saudável")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)

                if store.reminderConfig.isEnabled {
                    HStack {
                        Text("Frequência dos Avisos:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("Frequência", selection: Binding(
                            get: { store.reminderConfig.intervalHours },
                            set: { newInterval in
                                store.updateReminderConfig(intervalHours: newInterval)
                                WaterNotificationScheduler.shared.scheduleIntervalReminders(
                                    targetWaterMl: targetWaterMl,
                                    store: store
                                )
                                hapticTrigger += 1
                            }
                        )) {
                            Text("A cada 1h").tag(1)
                            Text("A cada 2h").tag(2)
                            Text("A cada 3h").tag(3)
                        }
                        .pickerStyle(.menu)
                        .font(.caption.bold())
                    }
                }
            }

            // MARK: - Live Activity (Dynamic Island & Tela Bloqueada)
            Divider()

            VStack(spacing: 10) {
                Toggle(isOn: Binding(
                    get: { isLiveActivityActive },
                    set: { enabled in
                        isLiveActivityActive = enabled
                        if enabled {
                            WaterLiveActivityManager.shared.startLiveActivity(
                                targetWaterMl: targetWaterMl,
                                currentWaterMl: currentConsumed,
                                config: store.reminderConfig
                            )
                        } else {
                            WaterLiveActivityManager.shared.endLiveActivity(immediate: true)
                        }
                        hapticTrigger += 1
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "iphone.gen3")
                                .foregroundColor(.cyan)
                                .font(.caption)
                            Text("Acompanhar na Ilha Dinâmica & Tela Bloqueada")
                                .font(.subheadline.bold())
                        }
                        Text("Live Activity com progresso em tempo real")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.cyan)

                if isLiveActivityActive {
                    Button {
                        WaterLiveActivityManager.shared.updateLiveActivity(
                            currentWaterMl: currentConsumed,
                            breakdown: pacingBreakdown
                        )
                        hapticTrigger += 1
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise.circle")
                            Text("Testar / Atualizar Live Activity")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }

    private func pacingMetricBox(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }

    private func handleReminderToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await WaterNotificationScheduler.shared.requestAuthorization()
                await MainActor.run {
                    store.updateReminderConfig(isEnabled: granted)
                    if granted {
                        WaterNotificationScheduler.shared.scheduleIntervalReminders(
                            targetWaterMl: targetWaterMl,
                            store: store
                        )
                    }
                    hapticTrigger += 1
                }
            }
        } else {
            store.updateReminderConfig(isEnabled: false)
            WaterNotificationScheduler.shared.cancelAllReminders()
            hapticTrigger += 1
        }
    }

    private var quickButtonsSection: some View {
        VStack(spacing: 12) {
            Text("REGISTRO RÁPIDO EM 1 TOQUE")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickWaterButton(amount: 150, label: "+150 ml", icon: "cup.and.saucer.fill")
                quickWaterButton(amount: 250, label: "+250 ml", icon: "waterbottle.fill")
                quickWaterButton(amount: 350, label: "+350 ml", icon: "mug.fill")
                quickWaterButton(amount: 500, label: "+500 ml", icon: "waterbottle")
                quickWaterButton(amount: 750, label: "+750 ml", icon: "figure.run.circle.fill")
                quickWaterButton(amount: 1000, label: "+1.0 L", icon: "drop.circle.fill")
            }
            .padding(.horizontal)
        }
    }

    private func quickWaterButton(amount: Double, label: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                _ = store.addWater(amount: amount)
                hapticTrigger += 1
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appCardBackground)
            .foregroundColor(.cyan)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var undoButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                _ = store.undoLastLog()
                hapticTrigger += 1
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                Text("Desfazer último registro de água")
            }
            .font(.subheadline.bold())
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.appCardBackground)
            .clipShape(Capsule())
        }
    }

    private var todayLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HISTÓRICO DE HOJE (\(todayLogs.count))")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if todayLogs.isEmpty {
                Text("Nenhum copo de água registrado hoje ainda.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.appCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(todayLogs) { log in
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.cyan)

                            Text(timeFormatter.string(from: log.loggedAt))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("+\(Int(log.amountMl)) ml")
                                .font(.headline)
                                .foregroundColor(.cyan)

                            Button {
                                withAnimation {
                                    store.removeLog(id: log.id)
                                    hapticTrigger += 1
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
