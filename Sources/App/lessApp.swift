import SwiftUI

/// Ponto de entrada do app.
///
/// Fase 0: apenas o shell de navegacao. O `ModelContainer` do SwiftData (Fase 2)
/// e a injecao dos servicos (`AudioEngineService`, `TimerService`, ...) via ambiente
/// (Fase 1+) entram aqui conforme as fases avancam. Ver ROADMAP.md.
@main
struct LessApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
