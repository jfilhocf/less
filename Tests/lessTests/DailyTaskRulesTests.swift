import Testing
import Foundation
@testable import less

/// Testes das regras da lista de tarefas (adendo 2026-09-14): teto de 3/dia, rolagem
/// que ocupa vaga, concluir nao devolve vaga.
@Suite("DailyTaskRules")
struct DailyTaskRulesTests {
    let today = "2026-09-14"
    let yesterday = "2026-09-13"

    private func task(_ day: String, done: Bool = false) -> TaskSnapshot {
        TaskSnapshot(id: UUID(), dayKey: day, isCompleted: done)
    }

    @Test("chave de dia e estavel e ordenavel")
    func dayKeyFormat() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = DateComponents(calendar: cal, year: 2026, month: 9, day: 14).date!
        #expect(DailyTaskRules.dayKey(for: date, calendar: cal) == "2026-09-14")
        #expect("2026-09-13" < "2026-09-14") // ordenacao lexicografica = cronologica
    }

    @Test("teto de 3 por dia bloqueia a quarta")
    func capBlocksFourth() {
        let three = [task(today), task(today), task(today)]
        #expect(DailyTaskRules.slotsUsed(tasks: three, today: today) == 3)
        #expect(DailyTaskRules.canCreate(tasks: three, today: today) == false)

        let two = [task(today), task(today)]
        #expect(DailyTaskRules.canCreate(tasks: two, today: today) == true)
    }

    @Test("concluir NAO devolve a vaga")
    func completingDoesNotFreeSlot() {
        let tasks = [task(today, done: true), task(today), task(today)]
        #expect(DailyTaskRules.slotsUsed(tasks: tasks, today: today) == 3)
        #expect(DailyTaskRules.canCreate(tasks: tasks, today: today) == false)
    }

    @Test("pendente de ontem e candidata a rolar; concluida nao")
    func rolloverPicksIncompletePast() {
        let pending = task(yesterday, done: false)
        let doneYesterday = task(yesterday, done: true)
        let todays = task(today, done: false)
        let ids = DailyTaskRules.rolloverCandidates(
            tasks: [pending, doneYesterday, todays],
            today: today
        )
        #expect(ids == [pending.id])
    }

    @Test("apos rolar, a tarefa ocupa vaga de hoje (1 rolada + 2 novas)")
    func rolledTaskOccupiesSlot() {
        // simula a reatribuicao que o servico faz: dayKey da rolada vira hoje
        let rolled = TaskSnapshot(id: UUID(), dayKey: today, isCompleted: false)
        let novas = [task(today), task(today)]
        let all = [rolled] + novas
        #expect(DailyTaskRules.slotsUsed(tasks: all, today: today) == 3)
        #expect(DailyTaskRules.canCreate(tasks: all, today: today) == false)
    }
}
