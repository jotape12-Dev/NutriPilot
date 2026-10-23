import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

public struct WaterPacingLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: WaterPacingActivityAttributes.self) { context in
            // MARK: - Tela Bloqueada & Notificações (Lock Screen Banner)
            WaterPacingLockScreenView(
                state: context.state,
                attributes: context.attributes
            )
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(Color.cyan)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Dynamic Island Expandida
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                            .foregroundColor(.cyan)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(context.state.currentWaterMl)) ml")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Text("de \(Int(context.attributes.targetWaterMl)) ml")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.pacingStatus)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(statusColor(context.state.pacingStatus).opacity(0.2))
                            .foregroundColor(statusColor(context.state.pacingStatus))
                            .clipShape(Capsule())

                        Text("\(Int(context.state.progressPercentage))%")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Barra de Progresso Animada
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.cyan, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: max(8, min(geo.size.width, geo.size.width * CGFloat(context.state.progressPercentage / 100.0))),
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)

                        // Detalhes do Ritmo Fisiológico
                        HStack {
                            Label("\(Int(context.state.hourlyRateMl)) ml/h", systemImage: "gauge.with.dots.needle.50percent")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)

                            Spacer()

                            Label("Meta intervalo: \(Int(context.state.intervalTargetMl)) ml", systemImage: "clock.badge.checkmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // MARK: - Dynamic Island Compact Leading
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.cyan)
                        .font(.caption)
                    Text("\(Int(context.state.currentWaterMl)) ml")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                // MARK: - Dynamic Island Compact Trailing
                Text("\(Int(context.state.progressPercentage))%")
                    .font(.caption2.bold())
                    .foregroundColor(.cyan)
            } minimal: {
                // MARK: - Dynamic Island Minimal
                ZStack {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        let lower = status.lowercased()
        if lower.contains("atingida") || lower.contains("ritmo") {
            return .green
        } else if lower.contains("atrasado") {
            return .orange
        } else if lower.contains("adiantado") {
            return .blue
        }
        return .cyan
    }
}

// MARK: - Lock Screen View (Card Moderno e Elegante)

struct WaterPacingLockScreenView: View {
    let state: WaterPacingActivityAttributes.ContentState
    let attributes: WaterPacingActivityAttributes

    private var statusColor: Color {
        let lower = state.pacingStatus.lowercased()
        if lower.contains("atingida") || lower.contains("ritmo") {
            return .green
        } else if lower.contains("atrasado") {
            return .orange
        } else if lower.contains("adiantado") {
            return .blue
        }
        return .cyan
    }

    var body: some View {
        VStack(spacing: 12) {
            // Cabeçalho: Título, Ícone e Badge de Status
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ritmo de Hidratação")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("NutriPilot • Meta Diária: \(Int(attributes.targetWaterMl)) ml")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(state.pacingStatus)
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            // Barra de Progresso Fisiológico
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(10, min(geo.size.width, geo.size.width * CGFloat(state.progressPercentage / 100.0))),
                                height: 10
                            )
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(Int(state.currentWaterMl)) ml consumidos")
                        .font(.caption2.bold())
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(Int(state.progressPercentage))% da meta")
                        .font(.caption2.bold())
                        .foregroundColor(.cyan)
                }
            }

            // Grid de Métricas de Pacing
            HStack(spacing: 8) {
                metricPill(
                    title: "Taxa Fisiológica",
                    value: "\(Int(state.hourlyRateMl)) ml/h",
                    icon: "gauge.with.dots.needle.50percent",
                    color: .cyan
                )

                metricPill(
                    title: "Meta do Intervalo",
                    value: "\(Int(state.intervalTargetMl)) ml",
                    icon: "clock.badge.checkmark",
                    color: .blue
                )

                metricPill(
                    title: "Janela Ativa",
                    value: "\(attributes.startHour)h - \(attributes.endHour)h",
                    icon: "sun.max.fill",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.10, blue: 0.18), Color(red: 0.03, green: 0.06, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func metricPill(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
