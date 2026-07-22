//
//  PomodoroLiveActivity.swift
//  DayQuestWidgetExtension
//
//  UI Live Activity Помодоро: баннер на экране блокировки
//  и все три режима Dynamic Island (компактный, развёрнутый,
//  минимальный). Таймер и прогресс считает сама система —
//  мы лишь передали даты начала и конца фазы.
//
//  Файл кладётся ТОЛЬКО в виджет-таргет.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // Баннер на экране блокировки (и на устройствах без Island)
            LockScreenPomodoroView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Развёрнутый вид — долгое нажатие на Island
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.phaseTitle, systemImage: icon(for: context.state))
                        .font(.headline)
                        .foregroundStyle(color(for: context.state))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Text(timerInterval:) — системный живой отсчёт
                    Text(timerInterval: context.state.startDate...context.state.endDate,
                         countsDown: true)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // ProgressView(timerInterval:) — живой прогресс фазы
                    ProgressView(timerInterval: context.state.startDate...context.state.endDate,
                                 countsDown: false,
                                 label: { EmptyView() },
                                 currentValueLabel: { EmptyView() })
                        .tint(color(for: context.state))
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                .font(.title2)
                .foregroundStyle(state.isBreak ? .green : .red)

            VStack(alignment: .leading, spacing: 6) {
                Text(state.phaseTitle)
                    .font(.headline)
                    .foregroundStyle(.white)

                ProgressView(timerInterval: state.startDate...state.endDate,
                             countsDown: false,
                             label: { EmptyView() },
                             currentValueLabel: { EmptyView() })
                    .tint(state.isBreak ? .green : .red)
            }

            Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(16)
    }
}
