import Foundation
import UserNotifications
import ChefCore

/// Lembretes de refeição (roadmap item 10).
///
/// São notificações **locais**, agendadas pelo próprio app — não push. Por
/// isso funcionam num build instalado por sideload, que não tem
/// entitlement de push nem servidor por trás.
///
/// Reagenda tudo do zero a cada mudança em vez de tentar casar o que já
/// estava agendado: são no máximo 6 notificações repetidas, e assim não
/// existe estado divergente entre o banco e o centro de notificações.
enum MealReminderService {
    private static let identifierPrefix = "chef.meal.reminder."

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Pede permissão. Devolve `false` se o usuário negou — a UI mostra isso
    /// explicitamente em vez de deixar o toggle ligado sem efeito nenhum.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: MealSlot.allCases.map { identifierPrefix + $0.rawValue }
        )
    }

    /// Agenda um lembrete diário por refeição habilitada.
    static func reschedule(_ schedule: [(slot: MealSlot, hour: Int, minute: Int, enabled: Bool)]) async {
        cancelAll()

        guard await authorizationStatus() == .authorized else { return }

        let center = UNUserNotificationCenter.current()
        for entry in schedule where entry.enabled {
            let content = UNMutableNotificationContent()
            content.title = entry.slot.label
            content.body = body(for: entry.slot)
            content.sound = .default

            var components = DateComponents()
            components.hour = entry.hour
            components.minute = entry.minute

            let request = UNNotificationRequest(
                identifier: identifierPrefix + entry.slot.rawValue,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try? await center.add(request)
        }
    }

    private static func body(for slot: MealSlot) -> String {
        switch slot {
        case .cafeDaManha: return "Hora do café da manhã. Comece o dia batendo a proteína."
        case .almoco: return "Hora do almoço. Veja o que sua dieta pede para agora."
        case .lanche: return "Hora do lanche. Um intervalo pra não chegar faminto na próxima."
        case .posTreino: return "Pós-treino. Aproveite a janela pra proteína."
        case .jantar: return "Hora do jantar. Confira quanto ainda cabe na sua meta."
        case .outro: return "Hora de comer. Registre no Chef pra fechar o dia."
        }
    }
}
