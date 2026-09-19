import SwiftUI
import SwiftData

/// Ponto de entrada do app.
///
/// `init()` e o unico codigo garantido a rodar quando o sistema sobe o app **em background**
/// - por um App Intent vindo do Atalhos, por exemplo, sem View nenhuma montada. Por isso o
/// `ModelContainer` e o `FocusStore` nascem aqui, no `FocusRuntime`, e nao dentro de uma tela.
@main
struct LessApp: App {
    init() {
        do {
            try FocusRuntime.installLive()
        } catch {
            // Sem store nao ha app: falhar alto e melhor que rodar com estado fantasma.
            fatalError("Falha ao abrir o ModelContainer do SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Mesmo container do `FocusRuntime`, de proposito: se um dia entrar um `@Query` na
        // arvore, ele le do MESMO store que o `FocusStore` grava. Fecha a porta dos dois
        // containers sobre o mesmo arquivo, que falharia em silencio.
        .modelContainer(FocusRuntime.container)
    }
}
