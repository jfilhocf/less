import Testing
import Foundation
import SwiftData
@testable import less

/// Testes da Fase 2: persistencia das tarefas do dia, ajustes e sessoes sobre SwiftData.
/// Tudo em container in-memory - roda no CI, sem device e sem tocar o disco.
///
/// O que NAO se testa aqui: as regras de teto/rolagem em si, que sao puras e ja tem
/// cobertura em `DailyTaskRulesTests`. Aqui verifica-se que o servico **aplica** essas
/// regras e grava o resultado certo.
@MainActor
@Suite("PersistenceService")
struct PersistenceServiceTests {
    let calendar = Calendar.current
    /// Meio-dia evita que qualquer ajuste de fuso empurre a data para o dia vizinho.
    let now = Date(timeIntervalSince1970: 1_789_000_000) // 2026-09-08 ~12h UTC

    private func makeService() throws -> SwiftDataPersistenceService {
        SwiftDataPersistenceService(container: try .lessInMemory())
    }

    private func dayBefore(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date)!
    }

    // MARK: Criar e recuperar

    @Test("cria tarefa, persiste e recupera pelo dia")
    func createsAndFetches() throws {
        let service = try makeService()
        let today = DailyTaskRules.dayKey(for: now)

        let created = try service.createTask(title: "escrever o PRD", preset: .short, now: now)
        #expect(created.dayKey == today)
        #expect(created.isCompleted == false)

        let fetched = try service.tasks(on: today)
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "escrever o PRD")
        #expect(fetched.first?.id == created.id)
    }

    @Test("preset nao informado cai no padrao dos ajustes")
    func fallsBackToDefaultPreset() throws {
        let service = try makeService()
        let settings = try service.settings()
        settings.defaultPresetRaw = PomodoroPreset.long.rawValue

        let task = try service.createTask(title: "bloco longo", preset: nil, now: now)
        #expect(task.preset == .long)
    }

    // MARK: Teto do dia

    @Test("teto de 3 bloqueia a quarta com dayIsFull")
    func capBlocksFourth() throws {
        let service = try makeService()
        for i in 1...3 {
            try service.createTask(title: "t\(i)", preset: .short, now: now)
        }
        #expect(try service.canCreateTask(now: now) == false)
        #expect(throws: PersistenceError.dayIsFull(slotsUsed: 3)) {
            try service.createTask(title: "a quarta", preset: .short, now: now)
        }
        #expect(try service.tasks(on: DailyTaskRules.dayKey(for: now)).count == 3)
    }

    @Test("concluir NAO devolve a vaga")
    func completingDoesNotFreeSlot() throws {
        let service = try makeService()
        var created: [FocusTask] = []
        for i in 1...3 {
            created.append(try service.createTask(title: "t\(i)", preset: .short, now: now))
        }

        try service.complete(created[0], at: now)
        #expect(created[0].isCompleted == true)
        #expect(created[0].completedAt != nil)

        // a vaga continua ocupada: 3 sao o compromisso do dia
        #expect(try service.canCreateTask(now: now) == false)
    }

    // MARK: Rolagem

    @Test("pendente de ontem rola para hoje e ocupa vaga")
    func rollsOverPending() throws {
        let service = try makeService()
        let yesterday = dayBefore(now)
        let todayKey = DailyTaskRules.dayKey(for: now)

        try service.createTask(title: "ficou pra tras", preset: .short, now: yesterday)
        #expect(try service.tasks(on: todayKey).isEmpty)

        let rolled = try service.rollOverPendingTasks(now: now)
        #expect(rolled == 1)

        let todays = try service.tasks(on: todayKey)
        #expect(todays.count == 1)
        #expect(todays.first?.title == "ficou pra tras")

        // ocupou vaga: so cabem mais 2
        try service.createTask(title: "nova 1", preset: .short, now: now)
        try service.createTask(title: "nova 2", preset: .short, now: now)
        #expect(try service.canCreateTask(now: now) == false)
    }

    @Test("concluida de ontem NAO rola")
    func completedDoesNotRoll() throws {
        let service = try makeService()
        let yesterday = dayBefore(now)

        let done = try service.createTask(title: "terminada", preset: .short, now: yesterday)
        try service.complete(done, at: yesterday)

        #expect(try service.rollOverPendingTasks(now: now) == 0)
        #expect(try service.tasks(on: DailyTaskRules.dayKey(for: now)).isEmpty)
    }

    @Test("atraso acumulado rola inteiro e bloqueia criacao")
    func backlogRollsEntirelyAndBlocks() throws {
        let service = try makeService()
        let yesterday = dayBefore(now)
        let twoDaysAgo = dayBefore(yesterday)

        // 4 pendentes acumuladas: a regra manda todas rolarem, mesmo passando do teto
        for i in 1...3 {
            try service.createTask(title: "velha \(i)", preset: .short, now: twoDaysAgo)
        }
        try service.createTask(title: "de ontem", preset: .short, now: yesterday)

        #expect(try service.rollOverPendingTasks(now: now) == 4)
        #expect(try service.tasks(on: DailyTaskRules.dayKey(for: now)).count == 4)
        // paga o que nao terminou: criacao travada ate zerar o atraso
        #expect(try service.canCreateTask(now: now) == false)
    }

    @Test("rolar duas vezes no mesmo dia nao duplica nem muda nada")
    func rolloverIsIdempotent() throws {
        let service = try makeService()
        try service.createTask(title: "pendente", preset: .short, now: dayBefore(now))

        #expect(try service.rollOverPendingTasks(now: now) == 1)
        #expect(try service.rollOverPendingTasks(now: now) == 0)
        #expect(try service.tasks(on: DailyTaskRules.dayKey(for: now)).count == 1)
    }

    // MARK: Ajustes

    @Test("ajustes sao singleton: nao cria uma segunda instancia")
    func settingsIsSingleton() throws {
        let service = try makeService()
        let first = try service.settings()
        first.hapticsEnabled = false

        let second = try service.settings()
        #expect(second.id == first.id)
        #expect(second.hapticsEnabled == false)
    }

    // MARK: Sessoes

    @Test("sessao e gravada e recuperada pelo intervalo")
    func recordsAndFetchesSession() throws {
        let service = try makeService()
        let task = try service.createTask(title: "com sessao", preset: .short, now: now)
        let end = now.addingTimeInterval(25 * 60)

        try service.recordSession(
            taskID: task.id,
            startedAt: now,
            endedAt: end,
            effectiveSeconds: 1500,
            completedCycles: 1,
            wasInterrupted: false
        )

        let found = try service.sessions(from: now.addingTimeInterval(-60), to: end)
        #expect(found.count == 1)
        #expect(found.first?.taskID == task.id)
        #expect(found.first?.effectiveSeconds == 1500)

        // fora da janela nao aparece
        let outside = try service.sessions(
            from: end.addingTimeInterval(60),
            to: end.addingTimeInterval(3600)
        )
        #expect(outside.isEmpty)
    }

    @Test("estatistica e derivada das sessoes, nao persistida como agregado")
    func statsAreDerived() throws {
        let service = try makeService()
        let end = now.addingTimeInterval(25 * 60)
        try service.recordSession(
            taskID: nil, startedAt: now, endedAt: end,
            effectiveSeconds: 1500, completedCycles: 1, wasInterrupted: false
        )
        try service.recordSession(
            taskID: nil, startedAt: end, endedAt: end.addingTimeInterval(1500),
            effectiveSeconds: 1500, completedCycles: 1, wasInterrupted: false
        )

        // guardrail 12.12: soma-se na hora a partir das linhas, nada de total salvo
        let total = try service
            .sessions(from: now.addingTimeInterval(-60), to: end.addingTimeInterval(3600))
            .reduce(0) { $0 + $1.effectiveSeconds }
        #expect(total == 3000)
    }
}
