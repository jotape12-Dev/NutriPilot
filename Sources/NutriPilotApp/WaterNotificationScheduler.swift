import Foundation
import UserNotifications
#if canImport(NutriPilotCore)
import NutriPilotCore
#endif

/// Agendador de lembretes inteligentes de hidratação em tempo real com base no ritmo fisiológico saudável (Pacing).
public final class WaterNotificationScheduler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let shared = WaterNotificationScheduler()

    public static let categoryIdentifier = "NUTRIPILOT_WATER_PACING"
    public static let action250ml = "ACTION_LOG_250ML"
    public static let action500ml = "ACTION_LOG_500ML"

    public override init() {
        super.init()
        setupNotificationCategories()
    }

    public func setupNotificationCategories() {
        let act250 = UNNotificationAction(
            identifier: Self.action250ml,
            title: "+250 ml",
            options: []
        )
        let act500 = UNNotificationAction(
            identifier: Self.action500ml,
            title: "+500 ml",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [act250, act500],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Solicita autorização ao usuário para envio de notificações locais.
    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Cancela todos os lembretes pendentes de pacing de água.
    public func cancelAllReminders() {
        let ids = (1...24).map { "water_pacing_interval_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Agenda as notificações locais periódicas com base na meta diária, horários e intervalos de hidratação saudável.
    public func scheduleIntervalReminders(targetWaterMl: Double, store: WaterStore = .shared) {
        cancelAllReminders()
        guard store.reminderConfig.isEnabled else { return }

        let config = store.reminderConfig
        let windowHours = max(1, config.endHour - config.startHour)
        let intervalHours = max(1, config.intervalHours)
        let hourlyRate = (targetWaterMl / Double(windowHours)).rounded(to: 1)
        let intervalTarget = (hourlyRate * Double(intervalHours)).rounded(to: 1)

        let center = UNUserNotificationCenter.current()

        var currentHour = config.startHour + intervalHours
        var intervalIndex = 1

        while currentHour <= config.endHour {
            let content = UNMutableNotificationContent()
            content.title = "💧 Ritmo Saudável de Hidratação"
            content.subtitle = "Intervalo das \(currentHour - intervalHours):00 às \(currentHour):00"
            content.body = "Meta deste intervalo: ~\(Int(intervalTarget)) ml. Beba água para manter seu ritmo de \(Int(targetWaterMl)) ml hoje sem sobrecarga renal."
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier

            var dateComponents = DateComponents()
            dateComponents.hour = currentHour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "water_pacing_interval_\(intervalIndex)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    print("Erro ao agendar lembrete de hidratação: \(error)")
                }
            }

            currentHour += intervalHours
            intervalIndex += 1
        }
    }
}
