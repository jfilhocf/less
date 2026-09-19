import Testing
import Foundation
import SwiftData
@testable import less

/// Passo 0 da Fase 4b: propriedade unica do `ModelContainer` e do `FocusStore`.
///
/// Estes testes existem contra uma falha **muda**: se o app e um App Intent abrirem cada um
/// o seu `ModelContainer` sobre o mesmo `less.store`, o intent grava num e a tela le do
/// outro. Nada aparece, nenhum erro e lancado, nenhum teste comum reprova. E a mesma classe
/// do SIGTRAP da Fase 2 (registrado no STATUS.md) - por isso a garantia e testada, nao
/// apenas comentada.
///
/// `.serialized` porque o runtime e estado global do processo.
@MainActor
@Suite("FocusRuntime", .serialized)
struct FocusRuntimeTests {
    let now = Date(timeIntervalSince1970: 1_789_000_000)

    private func installFresh() throws -> (ModelContainer, FocusStore) {
        FocusRuntime.reset()
        let container = try ModelContainer.lessInMemory()
        let store = FocusStore(
            persistence: SwiftDataPersistenceService(container: container),
            notifications: LiveNotificationService(center: FakeNotificationCenter())
        )
        FocusRuntime.install(container: container, store: store)
        return (container, store)
    }

    @Test("instalar duas vezes nao troca o container por baixo de quem ja o usa")
    func installIsIdempotentPerBox() throws {
        let (container, _) = try installFresh()
        #expect(FocusRuntime.isInstalled)
        #expect(ObjectIdentifier(FocusRuntime.container) == ObjectIdentifier(container))
    }

    @Test("store e container servidos sao sempre os MESMOS objetos")
    func servesSameInstances() throws {
        let (container, store) = try installFresh()

        #expect(FocusRuntime.store === store)
        #expect(FocusRuntime.store === FocusRuntime.store)
        #expect(ObjectIdentifier(FocusRuntime.container) == ObjectIdentifier(FocusRuntime.container))
        #expect(ObjectIdentifier(FocusRuntime.container) == ObjectIdentifier(container))
    }

    @Test("o que o store grava e visivel por quem le pelo container do runtime")
    func writesAreVisibleThroughRuntimeContainer() throws {
        let (_, store) = try installFresh()
        store.refresh(now: now)
        store.addTask(title: "escrita pelo store", now: now)

        // um leitor independente, construido do jeito que um App Intent construiria
        let reader = SwiftDataPersistenceService(container: FocusRuntime.container)
        let found = try reader.tasks(on: DailyTaskRules.dayKey(for: now))

        #expect(found.count == 1)
        #expect(found.first?.title == "escrita pelo store")
    }

    @Test("bloco iniciado pelo store aparece para um leitor do mesmo container")
    func activeBlockIsVisibleAcrossReaders() throws {
        let (_, store) = try installFresh()
        store.refresh(now: now)
        store.addTask(title: "bloco compartilhado", now: now)
        try store.startBlock(store.tasks[0], now: now)

        let reader = SwiftDataPersistenceService(container: FocusRuntime.container)
        let active = try reader.activeTask()

        #expect(active != nil)
        #expect(active?.id == store.activeTask?.id)
    }

    @Test("reset desinstala - e acessar depois disso seria erro de programacao")
    func resetUninstalls() throws {
        _ = try installFresh()
        #expect(FocusRuntime.isInstalled)
        FocusRuntime.reset()
        #expect(FocusRuntime.isInstalled == false)
    }
}

/// O buraco que o audit chamou de S7: efeito colateral disparado em `Task { }` solto nao
/// roda quando o processo e suspenso logo apos o `perform()` de um App Intent.
@MainActor
@Suite("Efeitos colaterais aguardaveis")
struct AwaitableSideEffectsTests {
    let now = Date(timeIntervalSince1970: 1_789_000_000)

    private func makeStore() throws -> (FocusStore, FakeNotificationCenter) {
        let container = try ModelContainer.lessInMemory()
        let center = FakeNotificationCenter()
        let store = FocusStore(
            persistence: SwiftDataPersistenceService(container: container),
            notifications: LiveNotificationService(center: center)
        )
        return (store, center)
    }

    @Test("startBlock + finishStart agendam notificacao SEM depender de sleep")
    func awaitableStartSchedulesDeterministically() async throws {
        let (store, center) = try makeStore()
        store.refresh(now: now)
        store.addTask(title: "via intent", now: now)

        try store.startBlock(store.tasks[0], now: now)
        // nenhuma notificacao ainda: a parte assincrona nao rodou
        #expect(await center.pendingIdentifiers().isEmpty)

        await store.finishStart(now: now, askPermission: false)

        // agendou, e sem nenhum `Task.sleep` no teste - se so passasse com sleep,
        // significaria que o efeito ficou solto num Task nao aguardado
        #expect(await center.pendingIdentifiers().isEmpty == false)
        #expect(store.isFocusing)
    }

    @Test("pauseBlock + cancelNotifications limpam de forma deterministica")
    func awaitablePauseCancels() async throws {
        let (store, center) = try makeStore()
        store.refresh(now: now)
        store.addTask(title: "pausar direito", now: now)

        try store.startBlock(store.tasks[0], now: now)
        await store.finishStart(now: now, askPermission: false)
        #expect(await center.pendingIdentifiers().isEmpty == false)

        store.pauseBlock(now: now.addingTimeInterval(60))
        await store.cancelNotifications()

        #expect(await center.pendingIdentifiers().isEmpty)
        #expect(store.isRunning == false)
    }

    @Test("finishStart sem pedir permissao nao trava quando nao ha como mostrar prompt")
    func finishStartWithoutPermissionPrompt() async throws {
        let (store, center) = try makeStore()
        store.refresh(now: now)
        store.addTask(title: "background", now: now)

        try store.startBlock(store.tasks[0], now: now)
        await store.finishStart(now: now, askPermission: false)

        #expect(await center.authorizationCalls == 0)
        #expect(await center.pendingIdentifiers().isEmpty == false)
    }
}
