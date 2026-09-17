import SwiftUI
import SwiftData
import UserNotifications
import ChefCore

/// Horários das refeições e seus lembretes (roadmap item 10).
struct MealRemindersCard: View {
    @Environment(\.modelContext) private var context
    @Query private var times: [SDMealTime]

    @State private var permission: UNAuthorizationStatusWrapper = .unknown

    private var sorted: [SDMealTime] {
        times.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    private var anyEnabled: Bool { times.contains { $0.reminderEnabled } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Horários e lembretes", systemImage: "bell.badge")
                    .font(.title3.weight(.bold))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { anyEnabled },
                    set: { setAll($0) }
                ))
                .labelsHidden()
                .tint(Color.chefPrimary)
            }

            if permission == .denied {
                Label("As notificações do Chef estão desativadas no iPhone. Ative em Ajustes › Notificações › Chef.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 10))
            }

            ForEach(sorted) { time in
                row(time)
            }

            Text("Os horários vêm de 3 em 3 horas por padrão. Ajuste cada um para a sua rotina.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .chefGlassCard()
        .task {
            permission = .init(await MealReminderService.authorizationStatus())
        }
    }

    private func row(_ time: SDMealTime) -> some View {
        HStack {
            Image(systemName: time.reminderEnabled ? "bell.fill" : "bell.slash")
                .font(.caption)
                .foregroundStyle(time.reminderEnabled ? Color.chefPrimary : .secondary)
                .frame(width: 20)

            Text(time.slot.label)
                .font(.subheadline)

            Spacer()

            DatePicker(
                time.slot.label,
                selection: Binding(
                    get: { dateFrom(time) },
                    set: { update(time, to: $0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()

            Toggle("", isOn: Binding(
                get: { time.reminderEnabled },
                set: { newValue in
                    time.reminderEnabled = newValue
                    persistAndReschedule(requestIfNeeded: newValue)
                }
            ))
            .labelsHidden()
            .tint(Color.chefPrimary)
        }
    }

    // MARK: - Ações

    private func dateFrom(_ time: SDMealTime) -> Date {
        Calendar.current.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func update(_ time: SDMealTime, to date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        time.hour = parts.hour ?? time.hour
        time.minute = parts.minute ?? time.minute
        persistAndReschedule(requestIfNeeded: false)
    }

    private func setAll(_ enabled: Bool) {
        for time in times { time.reminderEnabled = enabled }
        Haptics.selection()
        persistAndReschedule(requestIfNeeded: enabled)
    }

    private func persistAndReschedule(requestIfNeeded: Bool) {
        try? context.save()

        let schedule = times.map {
            (slot: $0.slot, hour: $0.hour, minute: $0.minute, enabled: $0.reminderEnabled)
        }

        Task {
            if requestIfNeeded, await MealReminderService.authorizationStatus() == .notDetermined {
                _ = await MealReminderService.requestAuthorization()
            }
            permission = .init(await MealReminderService.authorizationStatus())
            await MealReminderService.reschedule(schedule)
        }
    }
}

/// `UNAuthorizationStatus` não é `Equatable` de um jeito conveniente pra
/// `@State`, e só interessam três situações aqui.
enum UNAuthorizationStatusWrapper: Equatable {
    case unknown, authorized, denied, notDetermined

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral: self = .authorized
        case .denied: self = .denied
        case .notDetermined: self = .notDetermined
        @unknown default: self = .unknown
        }
    }
}
