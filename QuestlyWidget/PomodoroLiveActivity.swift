//
//  PomodoroLiveActivity.swift
//  QuestlyWidgetExtension
//
//  UI Live Activity Помодоро: баннер на экране блокировки
//  и все три режима Dynamic Island. Таймер и прогресс считает
//  сама система — мы лишь передали даты начала и конца фазы.
//
//  Кнопки: пока фаза идёт — «Завершить» (досрочно свернуть сессию);
//  когда фаза дотикала в фоне, staleDate помечает активность
//  устаревшей (context.isStale), и плашка сама переключается
//  в состояние «фаза окончена» с кнопкой «Старт».
//
//  Файл кладётся ТОЛЬКО в виджет-таргет.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct PomodoroLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // Баннер на экране блокировки (и на устройствах без Island)
            LockScreenPomodoroView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Развёрнутый вид — долгое нажатие на Island
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.isStale ? "Готово" : context.state.phaseTitle,
                          systemImage: icon(for: context.state))
                        .font(.headline)
                        .foregroundStyle(color(for: context.state))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale {
                        // Text(timerInterval:) — системный живой отсчёт
                        Text(timerInterval: context.state.startDate...context.state.endDate,
                             countsDown: true)
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        CountersRow(state: context.state)
                        Spacer()
                        ActionButton(isStale: context.isStale,
                                     isBreak: context.state.isBreak)
                    }
                }
            } compactLeading: {
                Image(systemName: icon(for: context.state))
                    .foregroundStyle(color(for: context.state))
            } compactTrailing: {
                // Фиксированная ширина — чтобы Island не «дышал»
                // при смене цифр (11:11 уже, чем 00:00).
                Text(timerInterval: context.state.startDate...context.state.endDate,
                     countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
                    .foregroundStyle(color(for: context.state))
            } minimal: {
                // Минимальный режим — когда активностей несколько
                Image(systemName: icon(for: context.state))
                    .foregroundStyle(color(for: context.state))
            }
        }
    }

    private func icon(for state: PomodoroActivityAttributes.ContentState) -> String {
        state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile"
    }

    private func color(for state: PomodoroActivityAttributes.ContentState) -> Color {
        state.isBreak ? .green : .red
    }
}

// MARK: - Баннер экрана блокировки

private struct LockScreenPomodoroView: View {
    let state: PomodoroActivityAttributes.ContentState
    let isStale: Bool

    private var accent: Color { state.isBreak ? .green : .red }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(accent)

                if isStale {
                    // Фаза дотикала, пока телефон лежал
                    Text(state.isBreak ? "Пора к делу" : "Время отдохнуть")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    // Крупный живой таймер — системный отсчёт
                    Text(timerInterval: state.startDate...state.endDate,
                         countsDown: true)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                }

                CountersRow(state: state)
            }

            Spacer(minLength: 8)

            ActionButton(isStale: isStale, isBreak: state.isBreak)
        }
        .padding(16)
    }

    private var title: String {
        if isStale {
            return state.isBreak ? "Перерыв окончен" : "Фокус завершён"
        }
        return state.phaseTitle
    }
}

// MARK: - Строка счётчиков: 🍅 сессии | ☕️ перерывы | минуты фокуса

private struct CountersRow: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            Text("🍅 \(state.completedPomodoros)")
            divider
            Text("☕️ \(state.completedBreaks)")
            divider
            Text("\(state.focusMinutesToday)м")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
    }

    private var divider: some View {
        Text("|").foregroundStyle(.white.opacity(0.3))
    }
}

// MARK: - Кнопка действия: «Завершить» во время фазы, «Старт» после

private struct ActionButton: View {
    let isStale: Bool
    let isBreak: Bool

    var body: some View {
        if isStale {
            // Стартуем СЛЕДУЮЩУЮ фазу: после фокуса — перерыв (зелёная),
            // после перерыва — фокус (красная).
            Button(intent: StartNextPhaseIntent()) {
                Text("Старт")
                    .font(.headline)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(isBreak ? .red : .green)
        } else {
            Button(intent: EndPomodoroIntent()) {
                Text("Завершить")
                    .font(.headline)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }
}
