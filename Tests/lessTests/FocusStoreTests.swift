import Testing
import Foundation
import SwiftData
@testable import less

/// Testes da Fase 4a: a orquestracao do dia (tarefas + Pomodoro + notificacoes).
///
/// O foco aqui e o **comportamento observavel pela interface** - o que a tela mostraria -
/// e principalmente a reconciliacao apos o app morrer, que e o aceite da Fase 3 que nao
/// da para verificar sem uma tela.
@MainActor
@Suite("FocusStore")
struct FocusStoreTests {
    let now = Date(timeIntervalSince1970: 1_789_000_000)

    /// Container compartilhado para simular "o mesmo app reaberto": um store novo sobre o
    /// mesmo disco e exatamente o que acontece quando o usuario mata e reabre o app.
    private func makeStore(
        container: ModelContainer
    ) -> (FocusStore, FakeNotificationCenter) {
        let center = FakeNotificationCenter()
        let store = FocusStore(
            persistence: SwiftDataPersistenceService(container: container),
            notifications: LiveNotificationService(center: center),
            // Alarme indisponivel de proposito: assim o aviso sai pela notificacao e o
            // teste e deterministico. O AlarmKit real pediria autorizacao do sistema.
            alarms: UnavailableAlarmService()
        )
        return (store, center)
    }

    // MARK: Tarefas

    @Test("adiciona tarefa e ela aparece na lista do dia")
    func addsTask() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)

        store.addTask(title: "escrever o PRD", now: now)

        #expect(store.tasks.count == 1)
        #expect(store.tasks.first?.title == "escrever o PRD")
        #expect(store.errorMessage == nil)
    }

    @Test("titulo em branco e ignorado")
    func ignoresBlankTitle() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)

        store.addTask(title: "   ", now: now)

        #expect(store.tasks.isEmpty)
    }

    @Test("a quarta tarefa vira mensagem, nao erro tecnico")
    func fourthTaskShowsLimitMessage() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        for i in 1...3 { store.addTask(title: "t\(i)", now: now) }

        store.addTask(title: "a quarta", now: now)

        #expect(store.tasks.count == 3)
        #expect(store.canCreate == false)
        #expect(store.errorMessage != nil) // a interface mostra "Tres por dia e o limite."
    }

    @Test("concluir mantem a tarefa na lista, riscada")
    func completeKeepsTaskInList() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        store.addTask(title: "feita", now: now)

        store.complete(store.tasks[0], now: now)

        #expect(store.tasks.count == 1)
        #expect(store.tasks[0].isCompleted == true)
    }

    // MARK: Pomodoro

    @Test("iniciar leva para o modo foco e agenda as notificacoes")
    func startEntersFocusMode() async throws {
        let (store, center) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        store.addTask(title: "focar", now: now)

        store.start(store.tasks[0], now: now)

        #expect(store.isFocusing == true)
        #expect(store.isRunning == true)
        #expect(store.phase == .focus)
        #expect(store.remaining == 25 * 60)

        // o agendamento acontece numa Task; dar uma volta no loop antes de conferir
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(120))
        #expect(await center.pendingIdentifiers().isEmpty == false)
    }

    @Test("encerrar sai do foco, grava a sessao e limpa as notificacoes")
    func stopRecordsSessionAndClears() async throws {
        let container = try ModelContainer.lessInMemory()
        let (store, center) = makeStore(container: container)
        store.refresh(now: now)
        store.addTask(title: "focar", now: now)
        store.start(store.tasks[0], now: now)

        store.stop(now: now.addingTimeInterval(600)) // 10 min depois

        #expect(store.isFocusing == false)
        #expect(store.activeTask == nil)

        let persistence = SwiftDataPersistenceService(container: container)
        let sessions = try persistence.sessions(
            from: now.addingTimeInterval(-60), to: now.addingTimeInterval(3600)
        )
        #expect(sessions.count == 1)
        #expect(sessions.first?.effectiveSeconds == 600)

        try? await Task.sleep(for: .milliseconds(120))
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test("pausar congela o tempo restante")
    func pauseFreezesRemaining() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        store.addTask(title: "focar", now: now)
        store.start(store.tasks[0], now: now)

        store.pause(now: now.addingTimeInterval(60))

        #expect(store.isRunning == false)
        #expect(store.remaining == 24 * 60) // 25 - 1
    }

    // MARK: Reconciliacao - o aceite da Fase 3

    @Test("app morto durante o foco: ao reabrir, o tempo decorrido foi descontado")
    func restoresElapsedAfterRelaunch() throws {
        let container = try ModelContainer.lessInMemory()

        // sessao 1: usuario inicia e o app morre
        let (first, _) = makeStore(container: container)
        first.refresh(now: now)
        first.addTask(title: "sobrevive", now: now)
        first.start(first.tasks[0], now: now)

        // sessao 2: app reaberto 10 minutos depois, store novo sobre o MESMO disco
        let (second, _) = makeStore(container: container)
        second.refresh(now: now.addingTimeInterval(600))

        #expect(second.isFocusing == true)
        #expect(second.activeTask?.title == "sobrevive")
        #expect(second.phase == .focus)
        #expect(second.remaining == 15 * 60) // 25 - 10, e nao 25
    }

    @Test("app morto e reaberto DEPOIS do bloco: ja esta na pausa, sem contar tick nenhum")
    func reconcilesMissedTransition() throws {
        let container = try ModelContainer.lessInMemory()

        let (first, _) = makeStore(container: container)
        first.refresh(now: now)
        first.addTask(title: "passou do bloco", now: now)
        first.start(first.tasks[0], now: now)

        // volta 27 min depois: os 25 de foco acabaram com o app morto e ja se passaram
        // 2 min da pausa curta de 5 -> devem restar 3
        let (second, _) = makeStore(container: container)
        second.refresh(now: now.addingTimeInterval(27 * 60))

        #expect(second.phase == .shortBreak)
        #expect(second.remaining == 3 * 60)
        #expect(second.completedFocusBlocks == 1)
    }

    @Test("varias transicoes perdidas de uma vez reconciliam certo (PRD 6.3)")
    func reconcilesManyMissedTransitions() throws {
        let container = try ModelContainer.lessInMemory()

        let (first, _) = makeStore(container: container)
        first.refresh(now: now)
        first.addTask(title: "sumiu por horas", now: now)
        first.start(first.tasks[0], now: now)

        // 1h30 depois: varios blocos de 25/5 se passaram com o app morto
        let (second, _) = makeStore(container: container)
        second.refresh(now: now.addingTimeInterval(90 * 60))

        #expect(second.isFocusing == true)
        // 90 min = 3 ciclos completos de (25 foco + 5 pausa) -> comeca o 4o foco, 3 fechados
        #expect(second.phase == .focus)
        #expect(second.remaining == 25 * 60)
        #expect(second.completedFocusBlocks == 3)
    }

    @Test("sem Pomodoro ancorado, reabrir mostra a lista e nao o foco")
    func noAnchorMeansTaskList() throws {
        let container = try ModelContainer.lessInMemory()
        let (first, _) = makeStore(container: container)
        first.refresh(now: now)
        first.addTask(title: "so na lista", now: now)

        let (second, _) = makeStore(container: container)
        second.refresh(now: now)

        #expect(second.isFocusing == false)
        #expect(second.tasks.count == 1)
    }

    // MARK: Rolagem

    @Test("ao abrir num dia novo, a pendente de ontem aparece e e sinalizada")
    func rollsOverOnRefresh() throws {
        let container = try ModelContainer.lessInMemory()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let (first, _) = makeStore(container: container)
        first.refresh(now: yesterday)
        first.addTask(title: "ficou pra tras", now: yesterday)

        let (second, _) = makeStore(container: container)
        second.refresh(now: now)

        #expect(second.rolledOverCount == 1)
        #expect(second.tasks.count == 1)
        #expect(second.tasks[0].title == "ficou pra tras")
    }

    // MARK: Formatacao do relogio

    @Test("o relogio arredonda para cima - nunca mostra 00:00 com tempo sobrando")
    func clockRoundsUp() {
        #expect(FocusSessionView.clock(1500) == "25:00")
        #expect(FocusSessionView.clock(59.4) == "01:00")
        #expect(FocusSessionView.clock(0.2) == "00:01")
        #expect(FocusSessionView.clock(0) == "00:00")
        #expect(FocusSessionView.clock(-5) == "00:00")
    }

    // MARK: Estatistica - o bug que o audit da Fase 4b encontrou

    @Test("sessao grava tempo de FOCO, nao tempo de relogio")
    func sessionRecordsFocusTimeNotWallClock() throws {
        let container = try ModelContainer.lessInMemory()
        let (store, _) = makeStore(container: container)
        store.refresh(now: now)
        store.addTask(title: "medir direito", now: now)
        store.start(store.tasks[0], now: now)

        // 55 min corridos = 25 foco + 5 pausa + 25 foco
        store.stop(now: now.addingTimeInterval(55 * 60))

        let persistence = SwiftDataPersistenceService(container: container)
        let sessions = try persistence.sessions(
            from: now.addingTimeInterval(-60), to: now.addingTimeInterval(4 * 3600)
        )
        #expect(sessions.count == 1)
        // 50 min de foco, nao os 55 do relogio
        #expect(sessions.first?.effectiveSeconds == 50 * 60)
    }

    @Test("encerrar no meio de uma pausa nao credita a pausa como foco")
    func stoppingDuringBreakDoesNotCreditIt() throws {
        let container = try ModelContainer.lessInMemory()
        let (store, _) = makeStore(container: container)
        store.refresh(now: now)
        store.addTask(title: "parou na pausa", now: now)
        store.start(store.tasks[0], now: now)

        // 28 min: o bloco de 25 fechou e ja se passaram 3 da pausa
        store.stop(now: now.addingTimeInterval(28 * 60))

        let persistence = SwiftDataPersistenceService(container: container)
        let sessions = try persistence.sessions(
            from: now.addingTimeInterval(-60), to: now.addingTimeInterval(4 * 3600)
        )
        #expect(sessions.first?.effectiveSeconds == 25 * 60)
    }

    @Test("tempo pausado pelo usuario tambem nao conta como foco")
    func userPauseDoesNotCountAsFocus() throws {
        let container = try ModelContainer.lessInMemory()
        let (store, _) = makeStore(container: container)
        store.refresh(now: now)
        store.addTask(title: "pausou", now: now)
        store.start(store.tasks[0], now: now)

        store.pause(now: now.addingTimeInterval(10 * 60))   // 10 min de foco
        store.stop(now: now.addingTimeInterval(40 * 60))    // 30 min parado

        let persistence = SwiftDataPersistenceService(container: container)
        let sessions = try persistence.sessions(
            from: now.addingTimeInterval(-60), to: now.addingTimeInterval(4 * 3600)
        )
        // so os 10 min que rodaram de fato
        #expect(sessions.first?.effectiveSeconds == 10 * 60)
    }

    // MARK: Desmarcar e apagar - reportado em uso real

    @Test("concluir por engano tem volta: desmarcar devolve a tarefa para pendente")
    func uncompleteRevertsTask() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        store.addTask(title: "marquei sem querer", now: now)

        store.complete(store.tasks[0], now: now)
        #expect(store.tasks[0].isCompleted == true)

        store.uncomplete(store.tasks[0], now: now)
        #expect(store.tasks[0].isCompleted == false)
        #expect(store.tasks[0].completedAt == nil)
    }

    @Test("o toque no circulo alterna nos dois sentidos")
    func toggleGoesBothWays() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        store.addTask(title: "vai e volta", now: now)

        store.toggleCompletion(store.tasks[0], now: now)
        #expect(store.tasks[0].isCompleted == true)

        store.toggleCompletion(store.tasks[0], now: now)
        #expect(store.tasks[0].isCompleted == false)

        store.toggleCompletion(store.tasks[0], now: now)
        #expect(store.tasks[0].isCompleted == true)
    }

    @Test("desmarcada volta a poder iniciar um bloco")
    func uncompletedTaskCanStartAgain() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        store.addTask(title: "retomar", now: now)
        store.complete(store.tasks[0], now: now)

        store.uncomplete(store.tasks[0], now: now)
        store.start(store.tasks[0], now: now)

        #expect(store.isFocusing)
        #expect(store.activeTask?.title == "retomar")
    }

    @Test("apagar remove a tarefa e libera a vaga do dia")
    func deleteFreesSlot() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        for i in 1...3 { store.addTask(title: "t\(i)", now: now) }
        #expect(store.canCreate == false)

        store.delete(store.tasks[0], now: now)

        #expect(store.tasks.count == 2)
        // apagar e correcao de engano ("essa tarefa nao existe"), diferente de concluir -
        // por isso devolve a vaga. Concluir continua NAO devolvendo.
        #expect(store.canCreate == true)
    }

    @Test("apagar a tarefa em foco encerra o bloco junto")
    func deletingActiveTaskStopsBlock() throws {
        let (store, _) = makeStore(container: try .lessInMemory())
        store.refresh(now: now)
        store.addTask(title: "em foco", now: now)
        store.start(store.tasks[0], now: now)
        #expect(store.isFocusing)

        store.delete(store.tasks[0], now: now)

        #expect(store.isFocusing == false)
        #expect(store.tasks.isEmpty)
    }
}
