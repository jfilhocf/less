import Foundation
import SwiftData

/// Tarefa do dia (adendo 2026-09-14). Nome `FocusTask` para nao colidir com `Swift.Task`
/// da concorrencia. Regras de teto/rolagem em `DailyTaskRules`; o Pomodoro dela roda no
/// `TimerService` com o `preset` escolhido no inicio.
@Model
final class FocusTask {
    var id: UUID
    var title: String
    var createdAt: Date
    /// Dia ao qual a tarefa esta atribuida ("yyyy-MM-dd"). Muda quando a tarefa rola.
    var dayKey: String
    var isCompleted: Bool
    var completedAt: Date?
    /// Preset do Pomodoro (rawValue de `PomodoroPreset`).
    var presetRaw: String
    /// Blocos de foco fechados para esta tarefa (derivado do timer, persistido ao fim).
    var completedFocusBlocks: Int
    /// Instante-ancora do Pomodoro em execucao (nil = nao iniciado). ADR-05.
    var startedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date,
        dayKey: String,
        preset: PomodoroPreset = .short
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.dayKey = dayKey
        self.isCompleted = false
        self.completedAt = nil
        self.presetRaw = preset.rawValue
        self.completedFocusBlocks = 0
        self.startedAt = nil
    }

    var preset: PomodoroPreset {
        PomodoroPreset(rawValue: presetRaw) ?? .short
    }

    func snapshot() -> TaskSnapshot {
        TaskSnapshot(id: id, dayKey: dayKey, isCompleted: isCompleted)
    }
}
