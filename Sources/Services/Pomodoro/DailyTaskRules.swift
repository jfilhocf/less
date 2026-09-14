import Foundation

/// Visao minima de uma tarefa para as regras do dia (evita depender do SwiftData
/// na logica pura, mantendo tudo testavel no CI).
struct TaskSnapshot: Sendable, Equatable {
    let id: UUID
    /// Dia ao qual a tarefa esta atribuida, no formato "yyyy-MM-dd" (ordenavel).
    let dayKey: String
    let isCompleted: Bool
}

/// Regras puras da lista de tarefas do less (adendo 2026-09-14).
///
/// Produto: no maximo 3 tarefas por dia; tarefa nao concluida ROLA para o dia seguinte
/// e OCUPA vaga (ex.: 1 rolada + 2 novas = teto atingido). Concluir NAO devolve a vaga -
/// as 3 sao o compromisso do dia. A rolagem nunca descarta tarefa: se houver mais de 3
/// pendentes acumuladas, todas rolam e ocupam vagas, bloqueando criacao ate o usuario
/// zerar o atraso (disciplina "paga o que nao terminou").
enum DailyTaskRules {
    /// Teto de tarefas atribuidas a um mesmo dia.
    static let maxPerDay = 3

    /// Chave de dia local ("yyyy-MM-dd"). String ordenavel = comparavel cronologicamente,
    /// sem depender de `DateFormatter` (evita estado nao-Sendable no caminho quente).
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Quantas vagas do dia `today` ja estao ocupadas (concluidas ou nao contam).
    static func slotsUsed(tasks: [TaskSnapshot], today: String) -> Int {
        tasks.filter { $0.dayKey == today }.count
    }

    /// Se ainda cabe criar uma nova tarefa hoje.
    static func canCreate(tasks: [TaskSnapshot], today: String) -> Bool {
        slotsUsed(tasks: tasks, today: today) < maxPerDay
    }

    /// IDs das tarefas de dias anteriores que estao pendentes e devem rolar para `today`.
    /// O chamador reatribui o `dayKey` desses itens para `today` (a rolagem em si).
    static func rolloverCandidates(tasks: [TaskSnapshot], today: String) -> [UUID] {
        tasks
            .filter { $0.dayKey < today && !$0.isCompleted }
            .map { $0.id }
    }
}
