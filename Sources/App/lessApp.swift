import SwiftUI
import SwiftData

/// Ponto de entrada do app.
///
/// Fase 2: o `ModelContainer` do SwiftData entra aqui e desce pela `@Environment`.
/// A injecao do `AudioEngineService` (Fase 1, adiada) e do `NotificationService`
/// (Fase 3) chega conforme as fases avancam. Ver ROADMAP.md.
@main
struct LessApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try .less()
        } catch {
            // Sem store nao ha app: falhar alto e melhor que rodar com estado fantasma.
            fatalError("Falha ao abrir o ModelContainer do SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
