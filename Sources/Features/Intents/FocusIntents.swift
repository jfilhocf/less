import AppIntents
import Foundation

/// As acoes do `less` expostas ao app **Atalhos** (PRD 17.2).
///
/// Por que isto existe: o usuario quer que iniciar um bloco de foco tambem ative o **Modo
/// Foco** do iPhone e o **filtro de cor preto-e-branco**. Nenhum app de terceiro consegue
/// ligar esses dois ajustes por conta propria - nao ha API publica, e `SetFocusFilterIntent`
/// serve para REAGIR a um Foco, nao para ativa-lo. O caminho legitimo e o usuario montar UM
/// Atalho encadeando as acoes de sistema com estas acoes daqui.
///
/// Sao **exatamente tres**, as do PRD 17.2. Acrescentar "adicionar tarefa" ou "quanto falta"
/// seria aumento de escopo (guardrail 10).
///
/// **Forma que compila sob Swift 6 strict concurrency:** o tipo do intent e `nonisolated`
/// (requisito do protocolo) e so o `perform()` e `@MainActor`. O `FocusStore` e
/// `@MainActor`, entao alcanca-lo de um `perform()` nao isolado seria erro; e o
/// `FocusRuntime` so pode ser lido de dentro da main actor.

// MARK: - Iniciar foco

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.start.title"
    static let description = IntentDescription("intent.start.description")

    /// Roda em background: iniciar um bloco nao precisa trazer o app para a frente, e
    /// abrir o app no meio de um Atalho atrapalharia o encadeamento com Foco/filtro de cor.
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = FocusRuntime.store
        // Sem tarefa pendente inicia um bloco LIVRE em vez de lancar erro: erro aqui
        // abortaria o Atalho inteiro e as acoes seguintes (preto-e-branco, abrir o app)
        // nunca rodariam. E o timer nao depende da lista de tarefas.
        let title = try store.startNextPendingTask()

        // AGUARDA o agendamento. Um `Task { }` solto aqui nao rodaria: `perform()` retorna e
        // o sistema pode suspender o processo, e a notificacao de transicao nunca sairia.
        // Sem prompt de permissao: em background nao ha como mostrar dialogo.
        await store.finishStart(askPermission: false)

        if let title {
            return .result(dialog: IntentDialog("intent.start.done \(title)"))
        }
        return .result(dialog: IntentDialog("intent.start.done.free"))
    }
}

// MARK: - Pausar

struct PauseFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.pause.title"
    static let description = IntentDescription("intent.pause.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = FocusRuntime.store
        let paused = try store.pauseFocus()

        // Pausado nao tem transicao prevista: manter notificacao agendada mentiria.
        await store.cancelNotifications()

        // "Nada para pausar" e resposta, nao falha: erro abortaria o Atalho inteiro.
        return .result(dialog: IntentDialog(paused ? "intent.pause.done" : "intent.pause.nothing"))
    }
}

// MARK: - Concluir a tarefa em foco

struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.complete.title"
    static let description = IntentDescription("intent.complete.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = FocusRuntime.store
        let title = try store.completeActiveTask()
        await store.cancelNotifications()
        if let title {
            return .result(dialog: IntentDialog("intent.complete.done \(title)"))
        }
        return .result(dialog: IntentDialog("intent.complete.nothing"))
    }
}

// MARK: - Atalhos oferecidos sem o usuario configurar nada

struct LessShortcuts: AppShortcutsProvider {
    /// `var` computed com o builder, nunca `let`: como `static let` o tipo opaco nao
    /// satisfaz o requisito do protocolo.
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Iniciar foco no \(.applicationName)",
                "Começar a focar no \(.applicationName)",
            ],
            shortTitle: "intent.start.title",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: PauseFocusIntent(),
            phrases: [
                "Pausar o foco no \(.applicationName)",
                "Pausar o \(.applicationName)",
            ],
            shortTitle: "intent.pause.title",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Concluir a tarefa no \(.applicationName)",
                "Terminar a tarefa no \(.applicationName)",
            ],
            shortTitle: "intent.complete.title",
            systemImageName: "checkmark.circle"
        )
    }
}
