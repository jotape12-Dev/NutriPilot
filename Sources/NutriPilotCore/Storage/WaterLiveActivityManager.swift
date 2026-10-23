#if canImport(ActivityKit)
import Foundation

#if os(iOS) || targetEnvironment(macCatalyst)
import ActivityKit

/// Gerenciador de Ciclo de Vida da Live Activity de Ritmo de Hidratação para iOS (ActivityKit).
@available(iOS 16.1, *)
@MainActor
public final class WaterLiveActivityManager: @unchecked Sendable {
    public static let shared = WaterLiveActivityManager()

    private var currentActivity: Activity<WaterPacingActivityAttributes>?

    public var isActivityActive: Bool {
        if let activity = currentActivity {
            return activity.activityState == .active
        }
        return Activity<WaterPacingActivityAttributes>.activities.contains { $0.activityState == .active }
    }

    public init() {}

    /// Inicia a Live Activity de hidratação caso ainda não haja uma ativa.
    public func startLiveActivity(
        targetWaterMl: Double,
        currentWaterMl: Double,
        config: WaterReminderConfig = WaterReminderConfig()
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[WaterLiveActivityManager] Live Activities não autorizadas pelo sistema.")
            return
        }

        // Se já existe uma atividade ativa, reaproveita
        if let active = Activity<WaterPacingActivityAttributes>.activities.first(where: { $0.activityState == .active }) {
            self.currentActivity = active
            return
        }

        let attributes = WaterPacingActivityAttributes(
            targetWaterMl: targetWaterMl,
            startHour: config.startHour,
            endHour: config.endHour
        )

        let initialBreakdown = WaterStore.shared.pacingBreakdown(
            at: Date(),
            targetWaterMl: targetWaterMl,
            config: config
        )

        let contentState = WaterPacingActivityAttributes.ContentState(
            currentWaterMl: currentWaterMl,
            breakdown: initialBreakdown
        )

        do {
            if #available(iOS 16.2, *) {
                let activityContent = ActivityContent(state: contentState, staleDate: nil)
                self.currentActivity = try Activity.request(
                    attributes: attributes,
                    content: activityContent,
                    pushType: nil
                )
            } else {
                self.currentActivity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            }
        } catch {
            print("[WaterLiveActivityManager] Falha ao iniciar Live Activity: \(error.localizedDescription)")
        }
    }

    /// Atualiza os dados de progresso e ritmo da Live Activity ativa.
    public func updateLiveActivity(
        currentWaterMl: Double,
        breakdown: WaterPacingBreakdown
    ) {
        guard let activity = currentActivity ?? Activity<WaterPacingActivityAttributes>.activities.first(where: { $0.activityState == .active }) else {
            return
        }
        self.currentActivity = activity

        let contentState = WaterPacingActivityAttributes.ContentState(
            currentWaterMl: currentWaterMl,
            breakdown: breakdown
        )

        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: contentState)
            }
        }
    }

    /// Encerra a Live Activity de hidratação.
    public func endLiveActivity(immediate: Bool = false) {
        let activitiesToEnd = Activity<WaterPacingActivityAttributes>.activities.filter { $0.activityState == .active }
        guard !activitiesToEnd.isEmpty || currentActivity != nil else { return }

        Task {
            let dismissPolicy: ActivityUIDismissalPolicy = immediate ? .immediate : .default
            for act in activitiesToEnd {
                await act.end(nil, dismissalPolicy: dismissPolicy)
            }
            if let act = self.currentActivity, !activitiesToEnd.contains(where: { $0.id == act.id }) {
                await act.end(nil, dismissalPolicy: dismissPolicy)
            }
            await MainActor.run {
                self.currentActivity = nil
            }
        }
    }
}

#else
// Multiplataforma / Fallback para macOS permitindo testes e compatibilidade sem ActivityKit nativo
@MainActor
public final class WaterLiveActivityManager: @unchecked Sendable {
    public static let shared = WaterLiveActivityManager()

    public private(set) var isActivityActive: Bool = false
    public private(set) var lastContentState: WaterPacingActivityAttributes.ContentState?

    public init() {}

    public func startLiveActivity(
        targetWaterMl: Double,
        currentWaterMl: Double,
        config: WaterReminderConfig = WaterReminderConfig()
    ) {
        let initialBreakdown = WaterStore.shared.pacingBreakdown(
            at: Date(),
            targetWaterMl: targetWaterMl,
            config: config
        )
        self.lastContentState = WaterPacingActivityAttributes.ContentState(
            currentWaterMl: currentWaterMl,
            breakdown: initialBreakdown
        )
        self.isActivityActive = true
    }

    public func updateLiveActivity(
        currentWaterMl: Double,
        breakdown: WaterPacingBreakdown
    ) {
        self.lastContentState = WaterPacingActivityAttributes.ContentState(
            currentWaterMl: currentWaterMl,
            breakdown: breakdown
        )
    }

    public func endLiveActivity(immediate: Bool = false) {
        self.isActivityActive = false
        self.lastContentState = nil
    }
}
#endif
#endif
