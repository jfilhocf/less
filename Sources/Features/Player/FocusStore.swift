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
    /// Ha bloco rodando - **com ou sem tarefa**. O timer existe por si so: a pessoa pode
    /// so querer 25 minutos de foco, sem lista de tarefas envolvida.
    var isFocusing: Bool { activeTask != nil || isFreeBlock }
    /// Bloco de foco sem tarefa associada.
    private(set) var isFreeBlock = false

    /// Derivado da lista ja carregada, pela mesma regra pura que o servico usa ao gravar.
    /// Sem ida ao disco e sempre coerente com o que esta na tela.
    var canCreate: Bool {
        DailyTaskRules.canCreate(tasks: tasks.map { $0.snapshot() }, today: dayKey)
    }

    // MARK: Dependencias

    private let persistence: any PersistenceService
    private let notifications: any NotificationService
    private let alarms: any AlarmScheduling
    private let timer = LiveTimerService()
    private var ticker: Task<Void, Never>?

    init(
        persistence: any PersistenceService,
        notifications: any NotificationService,
        alarms: any AlarmScheduling = AlarmServiceFactory.make()
    ) {
        self.persistence = persistence
        self.notifications = notifications
        self.alarms = alarms
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
            let anchor = try reloadState(now: now)
            if let anchor {
                Task { await self.rescheduleNotifications(from: anchor, now: now) }
            }
        } catch {
            errorMessage = String(localized: "error.load")
        }
    }

    /// Parte SINCRONA do refresh: rolagem do dia + reconstrucao do Pomodoro a partir da
    /// ancora em disco. Devolve a ancora quando ha bloco ativo, para o chamador decidir se
    /// reagenda as notificacoes.
    ///
    /// Existe separada porque `refresh` reagendava notificacoes num `Task { }` solto - e
    /// quem chamava `refresh` antes de PAUSAR corria contra o proprio cancelamento: o
    /// reagendamento podia pousar depois do cancel e deixar agendada a transicao de um bloco
    /// pausado. Quem pausa usa esta versao e nao reagenda nada.
    @discardableResult
    func reloadState(now: Date = .now) throws -> Date? {
        rolledOverCount = try persistence.rollOverPendingTasks(now: now)
        try reload(now: now)

        if let running = try persistence.activeTask(), let anchor = running.startedAt {
            // Ancora de outro dia = bloco que ninguem encerrou, nao bloco em andamento.
            // Sem isto, um bloco esquecido ontem faz TODO Atalho de hoje morrer em
            // `.alreadyFocusing` - com sintoma identico ao de "nao abriu o app".
            guard Self.isSameDay(anchor, now) else {
                try persistence.stopPomodoro(on: running)
                activeTask = nil
                isFreeBlock = false
                stopTicking()
                errorMessage = nil
                return nil
            }
            activeTask = running
            isFreeBlock = false
            timer.start(preset: running.preset, at: anchor)
            timer.reconcile(now: now)
            startTicking()
            errorMessage = nil
            return anchor
        }

        // Sem tarefa ancorada, ainda pode haver um bloco LIVRE em andamento.
        if let free = try persistence.activeFreeBlock() {
            guard Self.isSameDay(free.startedAt, now) else {
                try persistence.stopFreeBlock()
                activeTask = nil
                isFreeBlock = false
                stopTicking()
                errorMessage = nil
                return nil
            }
            activeTask = nil
            isFreeBlock = true
            timer.start(preset: free.preset, at: free.startedAt)
            timer.reconcile(now: now)
            startTicking()
            errorMessage = nil
            return free.startedAt
        }

        activeTask = nil
        isFreeBlock = false
        stopTicking()
        errorMessage = nil
        return nil
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

    /// Desmarca uma tarefa concluida.
    func uncomplete(_ task: FocusTask, now: Date = .now) {
        do {
            try persistence.uncomplete(task)
            try reload(now: now)
        } catch {
            errorMessage = String(localized: "error.save")
        }
    }

    /// Alterna concluida/pendente - o que o toque no circulo faz.
    func toggleCompletion(_ task: FocusTask, now: Date = .now) {
        if task.isCompleted {
            uncomplete(task, now: now)
        } else {
            complete(task, now: now)
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
            try startBlock(task, now: now)
            Task { await self.finishStart(now: now) }
        } catch {
            errorMessage = String(localized: "error.save")
        }
    }

    /// Parte SINCRONA de iniciar: o que precisa estar em disco e em tela imediatamente.
    /// Separada de proposito - ver `finishStart(now:askPermission:)`.
    func startBlock(_ task: FocusTask, now: Date = .now) throws {
        try persistence.startPomodoro(on: task, at: now)
        activeTask = task
        isFreeBlock = false
        timer.start(preset: task.preset, at: now)
        startTicking()
    }

    /// Inicia um bloco de foco **sem tarefa**. O Pomodoro nao depende da lista.
    func startFreeBlock(preset: PomodoroPreset? = nil, now: Date = .now) throws {
        let chosen = try preset ?? persistence.settings().defaultPreset
        try persistence.startFreeBlock(preset: chosen, at: now)
        activeTask = nil
        isFreeBlock = true
        timer.start(preset: chosen, at: now)
        startTicking()
    }

    /// Versao para a interface: inicia bloco livre e trata erro em `errorMessage`.
    func startFreeFocus(preset: PomodoroPreset? = nil, now: Date = .now) {
        do {
            try startFreeBlock(preset: preset, now: now)
            Task { await self.finishStart(now: now) }
        } catch {
            errorMessage = String(localized: "error.save")
        }
    }

    /// Parte ASSINCRONA de iniciar: permissao e agendamento das notificacoes.
    ///
    /// E publica e aguardavel porque quem inicia um bloco por **App Intent** precisa poder
    /// esperar por ela. Num intent, `perform()` retorna e o sistema pode suspender ou matar
    /// o processo em seguida: um `Task { }` solto nao roda, o bloco comeca e a notificacao
    /// de transicao **nunca e agendada**. Pela interface o `Task { }` basta, porque o app
    /// segue vivo na tela.
    ///
    /// `askPermission` fica `false` quando nao ha como mostrar prompt (app em background).
    func finishStart(now: Date = .now, askPermission: Bool = true) async {
        if askPermission {
            // Permissao pedida no primeiro bloco iniciado, nunca no launch: pedir antes de a
            // pessoa entender para que serve so ensina a recusar.
            await requestNotificationPermission()
        }
        await rescheduleNotifications(from: now, now: now)
    }

    func pause(now: Date = .now) {
        pauseBlock(now: now)
        Task { await self.cancelNotifications() }
    }

    /// Parte sincrona de pausar.
    func pauseBlock(now: Date = .now) {
        timer.pause(at: now)
        stopTicking()
    }

    /// Cancela as notificacoes pendentes. Aguardavel pelo mesmo motivo de `finishStart`.
    /// Pausado nao tem transicao prevista: deixar notificacao agendada mentiria.
    func cancelNotifications() async {
        await notifications.cancelAll()
        await alarms.cancelAll()
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
        // Bloco livre: nao ha tarefa, mas a sessao conta para a estatistica do mesmo jeito.
        if isFreeBlock {
            stopFreeBlock(now: now)
            return
        }
        guard let task = activeTask else { return }
        let anchor = task.startedAt ?? now
        timer.reconcile(now: now)

        // `effectiveSeconds` e tempo de FOCO, nao tempo de relogio: 25 de foco + 5 de pausa
        // + 25 de foco sao 55 minutos corridos e **50 de foco**. Usar `now - anchor` aqui
        // contava pausa como foco e inflava a estatistica do usuario em silencio.
        let focused = PomodoroEngine(preset: task.preset)
            .focusedSeconds(elapsed: timer.elapsed)

        do {
            try persistence.recordSession(
                taskID: task.id,
                startedAt: anchor,
                endedAt: now,
                effectiveSeconds: Int(focused),
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
        Task { await self.cancelNotifications() }
    }

    // MARK: Acoes por identidade (usadas pelos App Intents)

    /// Falhas que um App Intent precisa comunicar ao usuario pela Siri/Atalhos.
    /// `CustomLocalizedStringResourceConvertible` faz o sistema falar a frase certa em vez
    /// de "a operacao nao pode ser concluida".
    enum ActionError: Error, CustomLocalizedStringResourceConvertible, Equatable {
        case noPendingTask
        case alreadyFocusing
        case notFocusing
        case couldNotSave

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .noPendingTask:   return "intent.error.noPendingTask"
            case .alreadyFocusing: return "intent.error.alreadyFocusing"
            case .notFocusing:     return "intent.error.notFocusing"
            case .couldNotSave:    return "intent.error.couldNotSave"
            }
        }
    }

    /// Inicia a proxima tarefa pendente do dia. Devolve o titulo, para o intent responder.
    ///
    /// Sincrona de proposito: o efeito assincrono (notificacoes) fica em `finishStart`, que
    /// o intent AGUARDA antes de retornar - senao o processo pode ser suspenso no meio.
    /// Inicia o foco pela via do Atalho/Siri.
    ///
    /// **Sem tarefa pendente, inicia um bloco LIVRE em vez de falhar.** Lancar erro aqui
    /// matava o Atalho inteiro: as acoes seguintes (ligar preto-e-branco, abrir o app) nunca
    /// rodavam. E, mais importante, o Pomodoro nao depende da lista - a pessoa pode so querer
    /// o timer.
    @discardableResult
    func startNextPendingTask(now: Date = .now) throws -> String? {
        // versao sincrona: reagendar aqui correria contra o cancelamento do proprio intent
        do {
            _ = try reloadState(now: now)
        } catch {
            // Falha de disco nao pode se disfarcar de "dia vazio" - e o unico erro que
            // ainda deve parar o Atalho.
            throw ActionError.couldNotSave
        }

        // Ja focando = o estado final que o Atalho pediu JA vale. Lancar aqui transformava
        // sucesso em aborto do fluxo inteiro: o Atalhos nao tem "continuar em caso de erro",
        // entao as acoes seguintes (preto-e-branco, Abrir App) morriam junto.
        if isFocusing { return activeTask?.title }

        if let next = tasks.first(where: { !$0.isCompleted }) {
            do {
                try startBlock(next, now: now)
            } catch {
                throw ActionError.couldNotSave
            }
            return next.title
        }

        do {
            try startFreeBlock(now: now)
        } catch {
            throw ActionError.couldNotSave
        }
        return nil
    }

    /// Pausa o bloco em andamento.
    /// Pausa o bloco em andamento. `false` quando nao havia nada rodando.
    ///
    /// **Nao lanca**: "nada para pausar" nao e falha, e erro aqui abortaria o Atalho.
    @discardableResult
    func pauseFocus(now: Date = .now) throws -> Bool {
        do {
            _ = try reloadState(now: now)
        } catch {
            throw ActionError.couldNotSave
        }
        guard isFocusing, isRunning else { return false }
        pauseBlock(now: now)
        return true
    }

    /// Conclui a tarefa em foco. Devolve o titulo concluido.
    /// Conclui a tarefa em foco. `nil` quando nao havia tarefa - tambem nao lanca.
    @discardableResult
    func completeActiveTask(now: Date = .now) throws -> String? {
        do {
            _ = try reloadState(now: now)
        } catch {
            throw ActionError.couldNotSave
        }
        // Bloco livre nao tem tarefa a concluir - encerra o bloco e segue.
        if isFreeBlock {
            stop(now: now)
            return nil
        }
        guard let task = activeTask else { return nil }
        let title = task.title
        complete(task, now: now)
        if errorMessage != nil { throw ActionError.couldNotSave }
        return title
    }

    private func stopFreeBlock(now: Date) {
        timer.reconcile(now: now)
        let preset = (try? persistence.settings().defaultPreset) ?? .short
        let anchor = (try? persistence.activeFreeBlock())?.startedAt ?? now
        let focused = PomodoroEngine(preset: preset).focusedSeconds(elapsed: timer.elapsed)
        do {
            try persistence.recordSession(
                taskID: nil,
                startedAt: anchor,
                endedAt: now,
                effectiveSeconds: Int(focused),
                completedCycles: timer.completedFocusBlocks,
                wasInterrupted: timer.phase == .focus
            )
            try persistence.stopFreeBlock()
        } catch {
            errorMessage = String(localized: "error.save")
        }
        isFreeBlock = false
        timer.reset()
        stopTicking()
        Task { await self.cancelNotifications() }
    }

    /// Pede autorizacao do aviso de transicao, preferindo o alarme.
    ///
    /// Pede **um** dos dois, nunca os dois seguidos: dois dialogos de permissao no primeiro
    /// bloco e o caminho mais curto para o usuario negar os dois.
    func requestNotificationPermission() async {
        if alarms.isAvailable, await alarms.requestAuthorization() {
            return
        }
        _ = await notifications.requestAuthorization()
    }

    // MARK: Interno

    /// Ancora e "agora" caem no mesmo dia local?
    ///
    /// Ao expirar, a sessao e **descartada sem gravar**: registrar 9 horas de "foco" que
    /// ninguem fez contaminaria a estatistica com numero inventado (guardrail 12.12).
    private static func isSameDay(_ anchor: Date, _ now: Date) -> Bool {
        DailyTaskRules.dayKey(for: anchor) == DailyTaskRules.dayKey(for: now)
    }

    /// Recarrega a lista do dia e fixa qual dia ela representa.
    private func reload(now: Date) throws {
        dayKey = DailyTaskRules.dayKey(for: now)
        tasks = try persistence.tasks(on: dayKey)
    }

    /// Reagenda o aviso de transicao pelo melhor meio disponivel.
    ///
    /// **Um meio de cada vez, nunca os dois** - avisar em dobro seria pior que nao avisar.
    /// O alarme ganha quando autorizado porque e o unico que **fura o Modo Foco e o
    /// silencioso**; a notificacao comum e silenciada justamente pelo Foco que o usuario
    /// ligou para trabalhar. Sem autorizacao (ou em iOS < 26), cai na notificacao.
    private func rescheduleNotifications(from anchor: Date, now: Date) async {
        // Bloco livre nao tem tarefa: o aviso sai sem titulo, mas sai.
        let preset: PomodoroPreset
        let title: String?
        if let task = activeTask {
            preset = task.preset
            title = task.title
        } else if isFreeBlock {
            preset = (try? persistence.activeFreeBlock())?.preset ?? .short
            title = nil
        } else {
            return
        }
        let upcoming = PomodoroEngine(preset: preset)
            .upcomingTransitions(start: anchor, now: now)

        // CONSULTA o sistema, nao uma flag de instancia. A flag nascia `false` e so virava
        // `true` em `requestNotificationPermission()` - que o caminho do Atalho PULA. Ou
        // seja: o unico caminho que liga o Modo Foco era o unico que perdia o alarme e caia
        // na notificacao comum, justamente a que o Foco silencia.
        if await alarms.isAuthorized() {
            await notifications.cancelAll()
            await alarms.schedule(upcoming, taskTitle: title, now: now)
        } else {
            await alarms.cancelAll()
            await notifications.rescheduleTransitions(upcoming, taskTitle: title, now: now)
        }
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
