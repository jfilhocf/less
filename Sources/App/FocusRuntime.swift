import Foundation
import SwiftData

/// Dono UNICO do `ModelContainer` e do `FocusStore` do processo.
///
/// Existe por dois motivos, os dois praticos:
///
/// 1. **Um App Intent sobe o app em background, sem View nenhuma montada.** O store nascia
///    dentro de `PlayerView.task`; nesse caminho ele simplesmente nao existiria, e o Atalho
///    nao teria o que acionar.
/// 2. **`ModelContainer.less()` e uma FACTORY** - chamar duas vezes abre dois stores sobre o
///    mesmo `less.store`. O intent gravaria num e a tela leria do outro, **sem erro nenhum**:
///    a tarefa simplesmente nao apareceria. E a mesma classe de falha muda do SIGTRAP da
///    Fase 2, e a unica defesa e nao ter dois donos.
///
/// Por isso **nao ha fallback preguicoso**: se ninguem instalou, acessar `store` para o
/// programa em vez de abrir um segundo container por conta propria.
@MainActor
enum FocusRuntime {
    private struct Box {
        let container: ModelContainer
        let store: FocusStore
    }

    private static var box: Box?

    static var isInstalled: Bool { box != nil }

    static var container: ModelContainer { required().container }
    static var store: FocusStore { required().store }

    private static func required() -> Box {
        guard let box else {
            preconditionFailure(
                "FocusRuntime nao foi instalado. LessApp.init() deve chamar installLive() e "
                + "os testes, installForTesting(container:)."
            )
        }
        return box
    }

    /// Instala o runtime de producao. Chamado uma unica vez em `LessApp.init()`, que e o
    /// unico codigo garantido a rodar quando o Atalhos sobe o app em background.
    @discardableResult
    static func installLive() throws -> FocusStore {
        if let box { return box.store }
        let container = try ModelContainer.less()
        let store = FocusStore(
            persistence: SwiftDataPersistenceService(container: container),
            notifications: LiveNotificationService()
        )
        box = Box(container: container, store: store)
        return store
    }

    /// Instala um runtime sobre um container ja existente (testes e previews).
    @discardableResult
    static func install(container: ModelContainer, store: FocusStore) -> FocusStore {
        box = Box(container: container, store: store)
        return store
    }

    #if DEBUG
    /// Zera entre testes. So em DEBUG - nao existe no build de release.
    static func reset() { box = nil }
    #endif
}
