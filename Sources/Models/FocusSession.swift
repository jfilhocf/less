import Foundation
import SwiftData

/// Registro de uma sessao de foco concluida ou interrompida (PRD 7). As estatisticas
/// (minutos por dia, blocos, sequencia) sao DERIVADAS destas linhas em runtime -
/// nunca persistidas como agregado (guardrail 12.12).
@Model
final class FocusSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    /// Segundos efetivos de foco (descontadas pausas do usuario).
    var effectiveSeconds: Int
    /// Tarefa associada (adendo 2026-09-14), quando a sessao veio de uma tarefa do dia.
    var taskID: UUID?
    var completedCycles: Int
    var wasInterrupted: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        effectiveSeconds: Int = 0,
        taskID: UUID? = nil,
        completedCycles: Int = 0,
        wasInterrupted: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.effectiveSeconds = effectiveSeconds
        self.taskID = taskID
        self.completedCycles = completedCycles
        self.wasInterrupted = wasInterrupted
    }
}
