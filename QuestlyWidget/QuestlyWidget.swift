//
//  DayQuestWidget.swift
//  DayQuestWidgetExtension
//
//  Два виджета:
//  - «Мой день» — домашний экран (small + medium);
//  - «Прогресс дня» — экран блокировки (кольцо, прямоугольник, строка).
//  Оба читают один WidgetSnapshot и используют общий провайдер.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline (общий для обоих виджетов)

struct DayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct DayProvider: TimelineProvider {

    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.placeholder : WidgetSnapshot.load()
        completion(DayEntry(date: .now, snapshot: snapshot))
    }

    // Приложение само дёргает reloadAllTimelines() после каждого
    // изменения, поэтому длинное расписание не нужно —
    // на всякий случай просим систему обновить нас через час.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let entry = DayEntry(date: .now, snapshot: WidgetSnapshot.load())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Цвет балла (та же логика, что в приложении)

private func scoreColor(_ score: Int) -> Color {
    switch score {
    case 0..<20:  return .red
    case 20..<60: return .orange
    default:      return .green
    }
}

// MARK: - Домашний экран: маленький

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🔥 \(snapshot.streak)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                Spacer()
                Text("🏆 \(snapshot.level)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.indigo)
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(snapshot.rawPoints)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("/100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(snapshot.score), total: 100)
                .tint(scoreColor(snapshot.score))

            Text("\(snapshot.statusEmoji) \(snapshot.statusLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Домашний экран: средний

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("🔥 \(snapshot.streak) · 🏆 \(snapshot.level) ур.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(snapshot.rawPoints)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("/100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: Double(snapshot.score), total: 100)
                    .tint(scoreColor(snapshot.score))

                Text("\(snapshot.statusEmoji) \(snapshot.statusLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 1) {
                if snapshot.pendingTasks.isEmpty {
                    Spacer()
                    Text("Всё выполнено 🎉")
                        .font(.caption.weight(.medium))
                    Spacer()
                } else {
                    Text("Осталось")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(snapshot.pendingTasks.prefix(3).enumerated()),
                            id: \.offset) { _, task in
                        // Тап — задача выполняется прямо с виджета,
                        // не открывая приложение (CompleteTaskIntent).
                        Button(intent: CompleteTaskIntent(taskID: task.id ?? "")) {
                            HStack(spacing: 4) {
                                Image(systemName: "circle")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(task.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Text("+\(task.points)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.green)
                            }
                            // Тап-зона: вся ширина строки + вертикальный
                            // запас. Без этого кнопка — только сам текст
                            // высотой ~12pt, палец промахивается в фон,
                            // а тап по фону = «открыть приложение».
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Экран блокировки: кольцо

struct CircularLockView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        // Gauge в стиле accessoryCircular — системное кольцо прогресса,
        // как у Активности. Система сама подбирает вид под обои.
        Gauge(value: Double(snapshot.score), in: 0...100) {
            Text("DQ")
        } currentValueLabel: {
            Text("\(snapshot.rawPoints)")
                .font(.system(.body, design: .rounded).weight(.bold))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Экран блокировки: прямоугольник

struct RectangularLockView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(snapshot.rawPoints)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text("/ 100 баллов")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(snapshot.score), total: 100)

            Text("🔥 \(snapshot.streak) · \(snapshot.statusEmoji) \(snapshot.statusLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Экран блокировки: строка над часами

struct InlineLockView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Text("🎯 \(snapshot.rawPoints)/100 · 🔥 \(snapshot.streak)")
    }
}

// MARK: - Виджет домашнего экрана

struct DayQuestWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DayEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
        default:
            SmallWidgetView(snapshot: entry.snapshot)
        }
    }
}

struct DayQuestWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayQuestWidget", provider: DayProvider()) { entry in
            DayQuestWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Мой день")
        .description("Прогресс дня, стрик, уровень и ближайшие задачи")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Виджет экрана блокировки

struct DayQuestLockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DayEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularLockView(snapshot: entry.snapshot)
        case .accessoryInline:
            InlineLockView(snapshot: entry.snapshot)
        default:
            CircularLockView(snapshot: entry.snapshot)
        }
    }
}

struct DayQuestLockWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayQuestLockWidget", provider: DayProvider()) { entry in
            DayQuestLockWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Прогресс дня")
        .description("Балл дня и стрик на экране блокировки")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Виджет «Цели года»

struct GoalsWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .bold))
                Text("ЦЕЛИ ГОДА")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(Color(red: 0.06, green: 0.43, blue: 0.34))

            let goals = snapshot.yearGoals ?? []
            if goals.isEmpty {
                Spacer()
                Text("Поставь цели на год\nв профиле Questly")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(goals.prefix(4), id: \.self) { goal in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.62, blue: 0.46))
                            .frame(width: 5, height: 5)
                        Text(goal)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct GoalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayQuestGoalsWidget", provider: DayProvider()) { entry in
            GoalsWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Цели года")
        .description("Твои главные цели — всегда перед глазами")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Точка входа: оба виджета в одном бандле

@main
struct DayQuestWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayQuestWidget()
        DayQuestLockWidget()
        GoalsWidget()
        PomodoroLiveActivity()
    }
}
