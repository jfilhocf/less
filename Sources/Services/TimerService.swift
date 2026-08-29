import Foundation

/// Contrato do timer Pomodoro (PRD 6; ADR-05).
///
/// A implementacao (Fase 3) ancora o tempo restante em um `targetDate` absoluto -
/// NUNCA contagem incremental (guardrail 12.4) - e agenda notificacoes locais para
/// cada transicao prevista, garantindo correcao em background inclusive quando o
/// app e suspenso ou encerrado (6.3).
///
/// Metodos previstos para a Fase 3:
/// - `start(config:)`, `pause()`, `resume()`, `reset()`
/// - maquina de estados idle / focusing / shortBreak / longBreak / paused (6.1)
/// - `reconcile(now:)` para recuperar o estado ao voltar do background,
///   inclusive o caso de multiplas transicoes perdidas (6.3)
protocol TimerService: Sendable {
}
