import Testing
import Foundation
import SwiftData
import AppIntents
@testable import less

/// Testes dos App Intents (PRD 17.2).
///
/// Chamam `perform()` direto, sem XCUITest e sem device - o que e possivel porque o intent
/// nao contem regra: ele so traduz uma acao do Atalhos numa chamada ao `FocusStore`.
///
/// `.serialized` porque o `FocusRuntime` e estado global do processo: dois testes instalando
/// runtimes diferentes em paralelo disputariam a mesma caixa.
@MainActor
@Suite("App Intents", .serialized)
struct FocusIntentsTests {
    let now = Date(timeIntervalSince1970: 1_789_000_000)

    @discardableResult
    private func installRuntime() throws -> (FocusStore, FakeNotificationCenter) {
        FocusRuntime.reset()
        let container = try ModelContainer.lessInMemory()
        let center = FakeNotificationCenter()
        let store = FocusStore(
            persistence: SwiftDataPersistenceService(container: container),
            notifications: LiveNotificationService(center: center),
            alarms: UnavailableAlarmService()
        )
        FocusRuntime.install(container: container, store: store)
        return (store, center)
    }

    // MARK: Iniciar

    @Test("iniciar pelo Atalho poe a tarefa em foco")
    func startIntentStartsFocus() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "focar pelo atalho", now: now)

        _ = try await StartFocusIntent().perform()

        #expect(store.isFocusing)
        #expect(store.activeTask?.title == "focar pelo atalho")
        #expect(store.phase == .focus)
    }

    @Test("iniciar pelo Atalho AGENDA a notificacao antes de retornar")
    func startIntentSchedulesBeforeReturning() async throws {
        let (store, center) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "com notificacao", now: now)

        _ = try await StartFocusIntent().perform()

        // sem nenhum sleep: se o agendamento dependesse de um Task solto, o processo
        // poderia ser suspenso e a notificacao nunca sairia (defeito S7 do audit)
        #expect(await center.pendingIdentifiers().isEmpty == false)
    }

    @Test("iniciar em background NAO pede permissao de notificacao")
    func startIntentDoesNotPromptInBackground() async throws {
        let (store, center) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "sem prompt", now: now)

        _ = try await StartFocusIntent().perform()

        // nao ha como mostrar dialogo com o app em background; pedir ali so gastaria
        // a unica chance de perguntar
        #expect(await center.authorizationCalls == 0)
    }

    @Test("sem tarefa pendente o intent NAO falha - inicia foco livre")
    func startIntentWithoutTaskStartsFreeBlock() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        #expect(store.tasks.isEmpty)

        // Antes isto lancava .noPendingTask. Erro em AppIntent ABORTA o Atalho inteiro:
        // as acoes seguintes (ligar preto-e-branco, abrir o app) nunca rodavam. E o
        // Pomodoro nao depende da lista - da para so querer o timer.
        _ = try await StartFocusIntent().perform()

        #expect(store.isFocusing)
        #expect(store.isFreeBlock)
        #expect(store.activeTask == nil)
        #expect(store.phase == .focus)
    }

    @Test("com todas as tarefas concluidas, tambem inicia foco livre")
    func startIntentWithAllTasksDoneStartsFree() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "ja feita", now: now)
        store.complete(store.tasks[0], now: now)

        _ = try await StartFocusIntent().perform()

        #expect(store.isFreeBlock)
        #expect(store.isFocusing)
    }

    @Test("foco livre tambem agenda o aviso de transicao")
    func freeBlockSchedulesNotification() async throws {
        let (store, center) = try installRuntime()
        store.refresh(now: now)

        _ = try await StartFocusIntent().perform()

        #expect(await center.pendingIdentifiers().isEmpty == false)
    }

    @Test("pausar funciona no foco livre")
    func pauseWorksOnFreeBlock() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        _ = try await StartFocusIntent().perform()

        _ = try await PauseFocusIntent().perform()

        #expect(store.isRunning == false)
        #expect(store.isFocusing)
    }

    @Test("com bloco ja rodando, iniciar de novo NAO falha e nao reinicia")
    func startIntentTwiceIsIdempotent() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "unica", now: now)
        _ = try await StartFocusIntent().perform()
        let firstTask = store.activeTask?.id

        // Antes lancava .alreadyFocusing - e erro em AppIntent aborta o Atalho inteiro,
        // matando as acoes seguintes. "Ja esta como voce pediu" nao e falha.
        _ = try await StartFocusIntent().perform()

        #expect(store.isFocusing)
        #expect(store.activeTask?.id == firstTask)
    }

    @Test("bloco esquecido de ONTEM nao trava o Atalho de hoje")
    func staleAnchorDoesNotBlockToday() async throws {
        let (store, _) = try installRuntime()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        store.refresh(now: yesterday)
        store.addTask(title: "de ontem", now: yesterday)
        try store.startBlock(store.tasks[0], now: yesterday)

        // Hoje: a ancora de ontem e lixo, nao bloco em andamento. Sem expirar, TODO
        // Atalho de hoje morreria em .alreadyFocusing - sintoma identico ao relatado.
        _ = try store.startNextPendingTask(now: now)

        #expect(store.isFocusing)
        #expect(DailyTaskRules.dayKey(for: store.activeTask?.startedAt ?? now)
                == DailyTaskRules.dayKey(for: now) || store.isFreeBlock)
    }

    @Test("tarefa concluida nao e escolhida para iniciar")
    func startIntentSkipsCompleted() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "ja feita", now: now)
        store.addTask(title: "a fazer", now: now)
        store.complete(store.tasks[0], now: now)

        _ = try await StartFocusIntent().perform()

        #expect(store.activeTask?.title == "a fazer")
    }

    // MARK: Pausar

    @Test("pausar pelo Atalho para o bloco e limpa as notificacoes")
    func pauseIntentPausesAndClears() async throws {
        let (store, center) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "pausavel", now: now)
        _ = try await StartFocusIntent().perform()

        _ = try await PauseFocusIntent().perform()

        #expect(store.isRunning == false)
        #expect(store.isFocusing) // segue sendo a tarefa ativa, so pausada
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test("pausar sem bloco responde, em vez de abortar o Atalho")
    func pauseIntentWithoutBlockAnswers() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)

        // Nao lanca: erro aqui mataria as acoes seguintes do Atalho.
        _ = try await PauseFocusIntent().perform()
        #expect(store.isFocusing == false)
    }

    // MARK: Concluir

    @Test("concluir pelo Atalho encerra a tarefa em foco")
    func completeIntentCompletesTask() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "para concluir", now: now)
        _ = try await StartFocusIntent().perform()

        _ = try await CompleteTaskIntent().perform()

        #expect(store.isFocusing == false)
        #expect(store.tasks.first?.isCompleted == true)
    }

    @Test("concluir sem nada em foco responde, em vez de abortar o Atalho")
    func completeIntentWithoutFocusAnswers() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "parada", now: now)

        _ = try await CompleteTaskIntent().perform()
        #expect(store.tasks.first?.isCompleted == false)
    }

    // MARK: O que o Atalho enxerga

    @Test("sao exatamente 3 atalhos - nem mais (escopo), nem menos")
    func exposesExactlyThreeShortcuts() {
        #expect(LessShortcuts.appShortcuts.count == 3)
    }

    @Test("nenhum intent abre o app: eles rodam dentro do Atalho")
    func intentsRunInBackground() {
        #expect(StartFocusIntent.openAppWhenRun == false)
        #expect(PauseFocusIntent.openAppWhenRun == false)
        #expect(CompleteTaskIntent.openAppWhenRun == false)
    }

    // MARK: A fiacao que a falha muda quebraria

    @Test("o que o Atalho grava e o que a tela le - um container so")
    func intentAndUIShareTheSameStore() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "visivel na tela", now: now)

        _ = try await StartFocusIntent().perform()

        // um leitor independente sobre o container do runtime - o que a UI faria
        let reader = SwiftDataPersistenceService(container: FocusRuntime.container)
        let active = try reader.activeTask()

        #expect(active != nil)
        #expect(active?.id == store.activeTask?.id)
        #expect(active?.startedAt != nil)
    }

    // MARK: Regressao - a corrida que deixava notificacao de bloco pausado

    @Test("pausar nao pode reagendar por baixo do proprio cancelamento")
    func pauseNeverLeavesScheduledNotifications() async throws {
        // Repetido no corpo (e nao por trait) porque era corrida: passava na maioria das
        // execucoes. Uma rodada so nao prova nada sobre um defeito intermitente.
        for _ in 1...15 {
            let (store, center) = try installRuntime()
            store.refresh(now: now)
            store.addTask(title: "corrida", now: now)
            _ = try await StartFocusIntent().perform()

            _ = try await PauseFocusIntent().perform()

            #expect(await center.pendingIdentifiers().isEmpty)
            #expect(store.isRunning == false)
        }
    }

    @Test("pausar pela interface tambem nao deixa notificacao para tras")
    func pauseFromUIAlsoClears() async throws {
        let (store, center) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "pela tela", now: now)

        try store.startBlock(store.tasks[0], now: now)
        await store.finishStart(now: now, askPermission: false)

        store.pauseBlock(now: now.addingTimeInterval(60))
        await store.cancelNotifications()

        // O intent chamava refresh(), que reagendava num Task solto. Dependendo de quem
        // ganhasse a corrida, a transicao de um bloco PAUSADO continuava agendada e o
        // usuario receberia o aviso. Repetido porque era flaky: passava na maioria das vezes.
        #expect(await center.pendingIdentifiers().isEmpty)
        #expect(store.isRunning == false)
    }
}
