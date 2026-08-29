import Testing
@testable import less

/// Sanidade da Fase 0: confirma que o alvo de teste compila, importa o modulo do
/// app e roda no simulador via CI. Testes reais do `TimerService` (correcao em
/// background) e do calculo de estatisticas chegam na Fase 3 (Definition of Done, 13).
@Suite("Sanidade")
struct SanityTests {
    @Test("o alvo de teste compila e executa")
    func targetCompilesAndRuns() {
        #expect(true)
    }

    @Test("o shell de navegacao instancia")
    @MainActor
    func rootViewInstantiates() {
        _ = RootView()
    }
}
