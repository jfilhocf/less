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

    @Test("sem tarefa pendente, o intent recusa com erro proprio")
    func startIntentWithoutTaskFails() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)

        await #expect(throws: FocusStore.ActionError.noPendingTask) {
            _ = try await StartFocusIntent().perform()
        }
    }

    @Test("com bloco ja rodando, iniciar de novo recusa em vez de reiniciar")
    func startIntentTwiceFails() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "unica", now: now)
        _ = try await StartFocusIntent().perform()

        await #expect(throws: FocusStore.ActionError.alreadyFocusing) {
            _ = try await StartFocusIntent().perform()
        }
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

    @Test("pausar sem bloco em andamento recusa")
    func pauseIntentWithoutBlockFails() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)

        await #expect(throws: FocusStore.ActionError.notFocusing) {
            _ = try await PauseFocusIntent().perform()
        }
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

    @Test("concluir sem nada em foco recusa")
    func completeIntentWithoutFocusFails() async throws {
        let (store, _) = try installRuntime()
        store.refresh(now: now)
        store.addTask(title: "parada", now: now)

        await #expect(throws: FocusStore.ActionError.notFocusing) {
            _ = try await CompleteTaskIntent().perform()
        }
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
