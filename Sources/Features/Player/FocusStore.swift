import Foundation
import Observation

/// Coordena o dia de trabalho: tarefas, Pomodoro e notificacoes.
///
/// Nao contem regra de produto nem matematica de tempo - o teto e a rolagem sao de
/// `DailyTaskRules`, o calculo de fase e do `PomodoroEngine`, a gravacao e do
/// `PersistenceService` e o agendamento e do `NotificationService`. Aqui so se orquestra
/// a ordem das coisas e se expoe estado observavel para a interface.
@MainActor
@Observable
final class FocusStore {
    // MARK: Estado exposto

    private(set) var tasks: [FocusTask] = []
    private(set) var activeTask: FocusTask?
    private(set) var rolledOverCount = 0
    private(set) var errorMessage: String?
    /// Dia que a lista carregada representa. Toda leitura de "hoje" sai daqui, nunca de
    /// `Date()` solto - senao o estado exibido e o estado consultado podem ser de dias
    /// diferentes (e, em teste com relogio injetado, sempre seriam).
    private(set) var dayKey = ""

    var phase: PomodoroPhase { timer.phase }
    var remaining: TimeInterval { timer.remaining }
    var isRunning: Bool { timer.isRunning }
    var completedFocusBlocks: Int { timer.completedFocusBlocks }
    var isFocusing: Bool { activeTask != nil }

    /// Derivado da lista ja carregada, pela mesma regra pura que o servico usa ao gravar.
    /// Sem ida ao disco e sempre coerente com o que esta na tela.
    var canCreate: Bool {
        DailyTaskRules.canCreate(tasks: tasks.map { $0.snapshot() }, today: dayKey)
    }

    // MARK: Dependencias

    private let persistence: any PersistenceService
    private let notifications: any NotificationService
    private let timer = LiveTimerService()
    private var ticker: Task<Void, Never>?

    init(persistence: any PersistenceService, notifications: any NotificationService) {
        self.persistence = persistence
        self.notifications = notifications
    }

    // Sem `deinit` para cancelar o ticker: `deinit` nao roda isolado na main actor e nao pode
    // tocar estado isolado. Nao e vazamento - o loop usa `[weak self]` e sai sozinho no tick
    // seguinte quando o store morre.

    // MARK: Ciclo de vida

    /// Chamar ao abrir o app e ao voltar do background.
    ///
    /// Faz a rolagem do dia e **reconstroi o Pomodoro a partir da ancora em disco** - e isto
    /// que faz o app saber o que aconteceu enquanto esteve morto (PRD 6.3): o estado nao vem
    /// de contagem acumulada, vem da diferenca entre a ancora e o relogio de agora.
    func refresh(now: Date = .now) {
        do {
            rolledOverCount = try persistence.rollOverPendingTasks(now: now)
            try reload(now: now)

            if let running = try persistence.activeTask(), let anchor = running.startedAt {
                activeTask = running
                timer.start(preset: running.preset, at: anchor)
                timer.reconcile(now: now)
                startTicking()
                Task { await self.rescheduleNotifications(from: anchor, now: now) }
            } else {
                activeTask = nil
                stopTicking()
            }
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "error.load")
        }
    }

    // MARK: Tarefas

    func addTask(title: String, now: Date = .now) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try persistence.createTask(title: clean, preset: nil, now: now)
            try reload(now: now)
            errorMessage = nil
        } catch PersistenceError.dayIsFull {
            errorMessage = String(localized: "today.full")
        } catch {
            errorMessage = String(localized: "error.save")
        }
    }

    func complete(_ task: FocusTask, now: Date = .now) {
        do {
            if activeTask?.id == task.id { stop(now: now) }
            try persistence.complete(task, at: now)
            try reload(now: now)
        } catch {
            errorMessage = String(localized: "error.save")
        }
    }

    func delete(_ task: FocusTask, now: Date = .now) {
        do {
            if activeTask?.id == task.id { stop(now: now) }
            try persistence.delete(task)
            try reload(now: now)
        } catch {
            errorMessage = String(localized: "error.save")
        }
    }

    // MARK: Pomodoro

    func start(_ task: FocusTask, now: Date = .now) {
        do {
            try persistence.startPomodoro(on: task, at: now)
            activeTask = task
            timer.start(preset: task.preset, at: now)
            startTicking()
            Task {
                // Permissao pedida AQUI, no primeiro bloco iniciado - nao no launch. Pedir
                // antes de a pessoa entender para que serve so ensina a recusar.
                await self.requestNotificationPermission()
                await self.rescheduleNotifications(from: now, now: now)
            }
        } catch {
            errorMessage = String(localized: "error.save")
        }
    }

    func pause(now: Date = .now) {
        timer.pause(at: now)
        stopTicking()
        // Pausado nao tem transicao prevista: deixar notificacao agendada mentiria.
        Task { await self.notifications.cancelAll() }
    }

    func resume(now: Date = .now) {
        timer.resume(at: now)
        startTicking()
        if let anchor = activeTask?.startedAt {
            Task { await self.rescheduleNotifications(from: anchor, now: now) }
        }
    }

    /// Encerra o bloco e registra a sessao para as estatisticas (derivadas, PRD 12.12).
    func stop(now: Date = .now) {
        guard let task = activeTask else { return }
        let anchor = task.startedAt ?? now
        do {
            try persistence.recordSession(
                taskID: task.id,
                startedAt: anchor,
                endedAt: now,
                effectiveSeconds: Int(max(0, now.timeIntervalSince(anchor))),
                completedCycles: timer.completedFocusBlocks,
                wasInterrupted: timer.phase == .focus
            )
            try persistence.stopPomodoro(on: task)
        } catch {
            errorMessage = String(localized: "error.save")
        }
        activeTask = nil
        timer.reset()
        stopTicking()
        Task { await self.notifications.cancelAll() }
    }

    func requestNotificationPermission() async {
        _ = await notifications.requestAuthorization()
    }

    // MARK: Interno

    /// Recarrega a lista do dia e fixa qual dia ela representa.
    private func reload(now: Date) throws {
        dayKey = DailyTaskRules.dayKey(for: now)
        tasks = try persistence.tasks(on: dayKey)
    }

    private func rescheduleNotifications(from anchor: Date, now: Date) async {
        guard let task = activeTask else { return }
        let upcoming = PomodoroEngine(preset: task.preset)
            .upcomingTransitions(start: anchor, now: now)
        await notifications.rescheduleTransitions(
            upcoming, taskTitle: task.title, now: now
        )
    }

    /// Um tick por segundo so para a interface: o valor mostrado vem sempre de
    /// `reconcile`, nunca de decrementar um contador (guardrail 12.4).
    private func startTicking() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.timer.reconcile(now: .now)
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }
}

#if DEBUG
extension FocusStore {
    /// Popula o dia com tarefas de exemplo, para inspecionar a interface no simulador.
    /// Compilado apenas em DEBUG - nao existe no build que vai para a App Store.
    func seedDemo(now: Date = .now, startFirst: Bool = false) {
        if tasks.isEmpty {
            addTask(title: "Terminar a Fase 4a do less", now: now)
            addTask(title: "Revisar o PRD", now: now)
            addTask(title: "Responder o e-mail do cliente", now: now)
        }
        if startFirst, let first = tasks.first, activeTask == nil {
            start(first, now: now)
        }
    }
}
#endif
