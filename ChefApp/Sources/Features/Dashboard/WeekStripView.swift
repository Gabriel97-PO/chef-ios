import SwiftUI

/// Seletor de dias da semana no estilo Strava ("Sua sequência"): em vez de
/// um título fixo "Hoje", deixa escolher qualquer dia (passado) da semana
/// pra consultar o histórico de refeições registradas naquele dia.
struct WeekStripView: View {
    @Binding var selectedDate: Date
    @State private var weekOffset: Int = 0

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        return cal
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    private var weekDays: [Date] {
        let base = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: today) ?? today
        let start = calendar.dateInterval(of: .weekOfYear, for: base)?.start ?? base
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private static let letters = ["S", "T", "Q", "Q", "S", "S", "D"]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { weekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left").font(.caption.weight(.bold))
                }

                Spacer()

                Text(weekRangeLabel)
                    .font(.caption.weight(.semibold))

                Spacer()

                Button {
                    guard weekOffset < 0 else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { weekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .opacity(weekOffset < 0 ? 1 : 0.25)
                .disabled(weekOffset >= 0)
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                    dayButton(day: day, letter: Self.letters[index])
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .chefGlassCard(cornerRadius: 20, padding: 16)
    }

    @ViewBuilder
    private func dayButton(day: Date, letter: String) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isFuture = day > today
        let dayNumber = calendar.component(.day, from: day)

        Button {
            guard !isFuture else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 6) {
                Text(letter)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.chefPrimary : Color.clear)
                        .frame(width: 34, height: 34)
                    if isToday && !isSelected {
                        Circle()
                            .stroke(Color.chefPrimary, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }
                    Text("\(dayNumber)")
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : (isFuture ? .tertiary : .primary))
                }
            }
            .opacity(isFuture ? 0.35 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(fullDateLabel(day))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var weekRangeLabel: String {
        if weekOffset == 0 { return "Essa semana" }
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d 'de' MMM"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    private func fullDateLabel(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: day)
    }
}
