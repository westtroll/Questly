//
//  PomodoroViewController.swift
//  Questly
//
//  Экран Помодоро — тонкий контроллер-сборщик. Кольцо и кнопки
//  живут здесь; панель фокусов, недельная статистика, анимация
//  режима фокуса, алерты и карточка блокировки — отдельными
//  компонентами в Views/Pomodoro/.
//

import UIKit
import Combine
import SwiftUI

final class PomodoroViewController: UIViewController {

    // MARK: - ViewModel

    private let viewModel = PomodoroViewModel.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Цвета фаз

    private var phaseColor: UIColor {
        switch viewModel.phase {
        case .work:       return DQColor.accentAdaptive   // фокус = основной акцент
        case .shortBreak: return .systemGreen
        case .longBreak:  return .systemTeal
        }
    }

    // MARK: - UI: ядро таймера

    private let phasePill: PaddedLabel = {
        let label = PaddedLabel()
        label.insets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.layer.cornerRadius = 14
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Контейнер кольца. Сами кольца — CAShapeLayer-ы:
    // это самый лёгкий способ рисовать дуги с анимацией.
    private let ringContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    // monospacedDigit — цифры одинаковой ширины,
    // иначе «11:11» уже, чем «00:00», и текст дёргается каждую секунду.
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = DQFont.roundedMono(52, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Название фокуса над кольцом — видно только в режиме фокуса
    private let focusModeTitle: UILabel = {
        let label = UILabel()
        label.font = DQFont.rounded(22, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var startButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "play.fill")
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        return button
    }()

    private lazy var resetButton = makeSideButton("arrow.counterclockwise", action: #selector(resetTapped))
    private lazy var skipButton  = makeSideButton("forward.end.fill", action: #selector(skipTapped))

    private var controls: UIStackView!
    private var dotsStack: UIStackView!
    private var cycleDots: [UIView] = []

    // MARK: - UI: компоненты

    private let focusPanel = FocusPanelView()
    private let statsCard = WeeklyStatsCardView()
    private let blockCard = AppBlockCardView()

    private var focusAnimator: FocusModeAnimator!
    private var didApplyInitialFocusMode = false

    // Скролл всего экрана: на невысоких экранах колонка таймера
    // и карточка статистики не помещаются вместе.
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Помодоро"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            style: .plain,
            target: self,
            action: #selector(openTimerSettings)
        )

        setupLayout()
        setupComponents()
        statsCard.refresh()
        setupRingLayers()
        setupBindings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshFocusPanel()
        statsCard.refresh()
    }

    // Путь кольца зависит от реального размера контейнера,
    // поэтому строим его после layout-а.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Таймер уже шёл, когда экран открыли — сразу в режим фокуса,
        // без анимации (кадры валидны только после первого layout).
        if !didApplyInitialFocusMode {
            didApplyInitialFocusMode = true
            if viewModel.isRunning {
                focusAnimator.setActive(true, animated: false, title: focusModeTitleText())
            }
        }

        let center = CGPoint(x: ringContainer.bounds.midX, y: ringContainer.bounds.midY)
        let radius = ringContainer.bounds.width / 2 - 10
        // Старт с «12 часов» (-90°), полный круг по часовой.
        let path = UIBezierPath(
            arcCenter: center, radius: radius,
            startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true
        )
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        trackLayer.frame = ringContainer.bounds
        progressLayer.frame = ringContainer.bounds

        // CGColor не адаптируется к теме сам — обновляем здесь.
        trackLayer.strokeColor = UIColor.tertiarySystemFill
            .resolvedColor(with: traitCollection).cgColor
    }

    // MARK: - Setup

    private func setupRingLayers() {
        for layer in [trackLayer, progressLayer] {
            layer.fillColor = nil
            layer.lineWidth = 12
            layer.lineCap = .round
            ringContainer.layer.addSublayer(layer)
        }
        progressLayer.strokeEnd = 0
    }

    private func setupLayout() {
        // Точки цикла
        dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.spacing = 10
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<PomodoroViewModel.pomodorosPerCycle {
            let dot = UIView()
            dot.layer.cornerRadius = 5
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 10).isActive = true
            cycleDots.append(dot)
            dotsStack.addArrangedSubview(dot)
        }

        // Ряд управления: сброс — старт/пауза — пропуск
        controls = UIStackView(arrangedSubviews: [resetButton, startButton, skipButton])
        controls.axis = .horizontal
        controls.spacing = 28
        controls.alignment = .center
        controls.translatesAutoresizingMaskIntoConstraints = false

        focusPanel.translatesAutoresizingMaskIntoConstraints = false
        statsCard.translatesAutoresizingMaskIntoConstraints = false
        blockCard.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        [phasePill, ringContainer, focusPanel, dotsStack, controls,
         blockCard, statsCard].forEach { scrollView.addSubview($0) }
        view.addSubview(focusModeTitle)
        ringContainer.addSubview(timeLabel)

        // Прячем карточку, пока нет capability Family Controls
        // (платный аккаунт разработчика). Флаг в AppConfig.
        blockCard.isHidden = !AppConfig.isScreenTimeAvailable

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            phasePill.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            phasePill.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),

            ringContainer.topAnchor.constraint(equalTo: phasePill.bottomAnchor, constant: 32),
            ringContainer.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            ringContainer.widthAnchor.constraint(equalToConstant: 260),
            ringContainer.heightAnchor.constraint(equalToConstant: 260),

            timeLabel.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor),

            focusModeTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            focusModeTitle.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -196),
            focusModeTitle.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            focusModeTitle.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),

            focusPanel.topAnchor.constraint(equalTo: ringContainer.bottomAnchor, constant: 20),
            focusPanel.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            focusPanel.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),

            dotsStack.topAnchor.constraint(equalTo: focusPanel.bottomAnchor, constant: 16),
            dotsStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),

            controls.topAnchor.constraint(equalTo: dotsStack.bottomAnchor, constant: 32),
            controls.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),

            startButton.widthAnchor.constraint(equalToConstant: 72),
            startButton.heightAnchor.constraint(equalToConstant: 72),

            blockCard.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 28),
            blockCard.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            blockCard.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),

            // Статистика недели — в потоке под управлением; её низ
            // замыкает contentSize скролла. (blockCard в цепочке не
            // участвует: он спрятан за флагом Screen Time; когда флаг
            // включим — пересадим цепочку на него.)
            statsCard.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 28),
            statsCard.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            statsCard.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            statsCard.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    /// Колбэки компонентов и аниматор
    private func setupComponents() {
        focusPanel.onEditCurrent = { [weak self] in self?.showFocusPicker(thenStart: false) }
        focusPanel.onAdd = { [weak self] in self?.showAddFocus() }
        focusPanel.onSelect = { [weak self] label in
            self?.viewModel.focusLabel = label
            self?.refreshFocusPanel()
        }
        focusPanel.onDeleteRequest = { [weak self] label in
            guard let self else { return }
            present(FocusAlerts.confirmDelete(label: label) { [weak self] in
                FocusList.remove(label)
                self?.refreshFocusPanel()
            }, animated: true)
        }

        blockCard.setSwitch(on: FocusBlockService.shared.isEnabled, animated: false)
        blockCard.onToggle = { [weak self] isOn in self?.blockToggled(isOn) }
        blockCard.onTap = { [weak self] in
            guard FocusBlockService.shared.isAuthorized else { return }
            self?.presentAppPicker()
        }
        updateBlockSubtitle()

        focusAnimator = FocusModeAnimator(
            host: view,
            scrollView: scrollView,
            ring: ringContainer,
            controls: controls,
            title: focusModeTitle,
            fading: [phasePill, focusPanel, dotsStack, blockCard, statsCard]
        )
    }

    // MARK: - Combine Bindings

    private func setupBindings() {
        viewModel.$remaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                timeLabel.text = viewModel.timeString
                refreshFocusPanel()
                // Присваивание strokeEnd анимируется CoreAnimation-ом
                // само (implicit animation ~0.25s) — плавно и бесплатно.
                progressLayer.strokeEnd = CGFloat(viewModel.progress)
            }
            .store(in: &cancellables)

        viewModel.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                guard let self else { return }
                statsCard.refresh()      // завершённая сессия сразу видна
                refreshFocusPanel()      // и в плашках фокусов тоже
                if focusAnimator.isActive {
                    focusAnimator.updateTitle(focusModeTitleText())
                }
                phasePill.text = phase.title
                applyPhaseColor()
            }
            .store(in: &cancellables)

        viewModel.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                guard let self else { return }
                var config = startButton.configuration
                config?.image = UIImage(systemName: isRunning ? "pause.fill" : "play.fill")
                startButton.configuration = config
                focusAnimator.setActive(isRunning, animated: true,
                                        title: focusModeTitleText())
            }
            .store(in: &cancellables)

        viewModel.$completedPomodoros
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completed in
                guard let self else { return }
                for (index, dot) in cycleDots.enumerated() {
                    dot.backgroundColor = index < completed
                        ? phaseColor
                        : .tertiarySystemFill
                }
            }
            .store(in: &cancellables)
    }

    private func applyPhaseColor() {
        let color = phaseColor
        progressLayer.strokeColor = color.resolvedColor(with: traitCollection).cgColor
        phasePill.textColor = color
        phasePill.backgroundColor = color.withAlphaComponent(0.15)

        var config = startButton.configuration
        config?.baseBackgroundColor = color
        startButton.configuration = config

        resetButton.tintColor = color
        skipButton.tintColor = color

        // Точки перекрашиваем под новую фазу
        for (index, dot) in cycleDots.enumerated() {
            dot.backgroundColor = index < viewModel.completedPomodoros
                ? color
                : .tertiarySystemFill
        }
    }

    // Цвет слоёв задаётся через CGColor — при смене темы обновляем вручную.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyPhaseColor()
    }

    // MARK: - Панель фокусов

    private func refreshFocusPanel() {
        let current = viewModel.focusLabel
        let others = FocusList.all()
            .filter { $0 != current }
            .map { label -> (String, Int, Int) in
                let detail = PomodoroStats.todayDetail(label: label)
                return (label, detail.sessions, detail.minutes)
            }
        focusPanel.refresh(with: .init(
            current: current,
            currentStats: viewModel.focusTodayLive,
            others: others
        ))
    }

    private func focusModeTitleText() -> String {
        if viewModel.phase == .work {
            if let label = viewModel.focusLabel, !label.isEmpty {
                return "🎯 \(label)"
            }
            return "🎯 Фокус"
        }
        return "☕️ Перерыв"
    }

    private func showFocusPicker(thenStart: Bool) {
        let alert = FocusAlerts.picker(
            currentLabel: viewModel.focusLabel,
            recents: PomodoroStats.recentLabels(limit: 3),
            thenStart: thenStart
        ) { [weak self] label in
            guard let self else { return }
            viewModel.focusLabel = label
            refreshFocusPanel()
            if thenStart { viewModel.toggle() }
        }
        present(alert, animated: true)
    }

    private func showAddFocus() {
        present(FocusAlerts.addFocus { [weak self] text in
            // Новый фокус сразу становится текущим
            self?.viewModel.focusLabel = text
            self?.refreshFocusPanel()
        }, animated: true)
    }

    // MARK: - Actions

    @objc private func startTapped() {
        Haptics.light()
        // Свежий старт рабочей фазы без названия фокуса — сначала
        // спросим, над чем работаем, и запустим после выбора.
        if !viewModel.isRunning,
           viewModel.phase == .work,
           viewModel.remaining == viewModel.phase.duration,
           (viewModel.focusLabel ?? "").isEmpty {
            showFocusPicker(thenStart: true)
            return
        }
        viewModel.toggle()
    }

    @objc private func openTimerSettings() {
        let settingsVC = PomodoroSettingsViewController()
        // Если таймер стоит — применяем новую длительность сразу
        // (reset перечитает duration фазы). Запущенный не трогаем.
        settingsVC.onChange = { [weak self] in
            guard let self, !viewModel.isRunning else { return }
            viewModel.reset()
        }
        let nav = UINavigationController(rootViewController: settingsVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(nav, animated: true)
    }

    @objc private func resetTapped() {
        viewModel.reset()
    }

    @objc private func skipTapped() {
        viewModel.skip()
    }

    // MARK: - Блокировка приложений (Screen Time)

    private func blockToggled(_ isOn: Bool) {
        if isOn {
            // Сначала разрешение Screen Time (async), потом включение.
            Task {
                let granted = await FocusBlockService.shared.requestAuthorization()
                if granted {
                    FocusBlockService.shared.isEnabled = true
                    Haptics.light()
                    updateBlockSubtitle()
                    // Нечего блокировать — сразу открываем выбор.
                    if FocusBlockService.shared.selectionCount == 0 {
                        presentAppPicker()
                    }
                } else {
                    blockCard.setSwitch(on: false, animated: true)
                    present(FocusAlerts.blockDenied(), animated: true)
                }
            }
        } else {
            FocusBlockService.shared.isEnabled = false
            FocusBlockService.shared.stopBlocking()   // если фокус уже идёт
            updateBlockSubtitle()
        }
    }

    private func presentAppPicker() {
        // FamilyActivityPicker — только SwiftUI. UIHostingController —
        // штатный мост: заворачивает SwiftUI-view в UIViewController.
        let picker = AppPickerView(selection: FocusBlockService.shared.selection) { [weak self] newSelection in
            FocusBlockService.shared.selection = newSelection
            self?.updateBlockSubtitle()
            self?.dismiss(animated: true)
        }
        let host = UIHostingController(rootView: picker)
        host.modalPresentationStyle = .pageSheet
        present(host, animated: true)
    }

    private func updateBlockSubtitle() {
        let service = FocusBlockService.shared
        if !service.isEnabled {
            blockCard.setSubtitle("Выключено")
        } else if service.selectionCount == 0 {
            blockCard.setSubtitle("Ничего не выбрано — тапни, чтобы выбрать")
        } else {
            blockCard.setSubtitle("Выбрано: \(service.selectionCount) · блокируется на время фокуса")
        }
    }

    // MARK: - Фабрика боковых кнопок

    private func makeSideButton(_ symbol: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        // У UIButton, в отличие от UIImageView, конфигурация символа
        // задаётся методом с указанием состояния кнопки.
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 20, weight: .medium),
            forImageIn: .normal
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}
