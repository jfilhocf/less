import Foundation

/// Contrato de persistencia (PRD 7; ADR-03) sobre SwiftData.
///
/// A implementacao (Fase 2) semeia o catalogo padrao a partir de um JSON no
/// bundle no primeiro launch, faz CRUD de `Mix` e garante os singletons
/// `AppSettings` e `PomodoroConfig`. Estatisticas (minutos por dia, sequencia
/// de dias, total) sao DERIVADAS em runtime de `FocusSession`, nunca persistidas
/// (guardrail 12.12).
protocol PersistenceService: Sendable {
}
