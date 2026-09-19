import Foundation
import SwiftData

/// Falhas de persistencia que a interface precisa distinguir do "deu errado" generico.
enum PersistenceError: Error, Equatable {
    /// As 3 vagas do dia ja estao ocupadas (`DailyTaskRules.maxPerDay`). Concluir nao
    /// devolve vaga, e tarefa rolada de ontem ocupa uma - entao isto e esperado, nao um bug.
    case dayIsFull(slotsUsed: Int)
}

/// Contrato de persistencia (PRD 7; ADR-03) sobre SwiftData.
///
/// Guarda tarefas do dia, sessoes de foco e os ajustes globais. **Nao decide regra de
/// produto**: teto do dia e rolagem sao de `DailyTaskRules` (puro e testado); este servico
/// so aplica o que as regras mandam e grava. Estatisticas (minutos por dia, sequencia,
/// total) sao DERIVADAS em runtime de `FocusSession`, nunca persistidas como agregado
/// (guardrail 12.12).
///
/// `@MainActor` pelo mesmo motivo do `TimerService`: alimenta a interface. O `ModelContext`
/// do SwiftData nao e `Sendable`, entao confina-lo na main actor evita ter que espalhar
/// isolamento pelo app inteiro (ADR-06, strict concurrency).
@MainActor
protocol PersistenceService: Sendable {
    // MARK: Tarefas do dia

    /// Tarefas atribuidas a um dia ("yyyy-MM-dd"), mais recentes por ultimo.
    func tasks(on dayKey: String) throws -> [FocusTask]

    /// Se ainda cabe criar tarefa hoje (teto de `DailyTaskRules.maxPerDay`).
    func canCreateTask(now: Date) throws -> Bool

    /// Cria uma tarefa para hoje. Lanca `PersistenceError.dayIsFull` se o teto ja foi atingido.
    /// `preset` nil usa o padrao de `AppSettings`.
    @discardableResult
    func createTask(title: String, preset: PomodoroPreset?, now: Date) throws -> FocusTask

    /// Marca como concluida. NAO libera a vaga do dia - as 3 sao o compromisso do dia.
    func complete(_ task: FocusTask, at now: Date) throws

    /// Rola para hoje toda tarefa pendente de dias anteriores e devolve quantas rolaram.
    /// Cada rolada OCUPA vaga de hoje; se houver mais de 3 acumuladas, todas rolam e a
    /// criacao fica bloqueada ate o usuario zerar o atraso (disciplina do adendo 16.1).
    @discardableResult
    func rollOverPendingTasks(now: Date) throws -> Int

    func delete(_ task: FocusTask) throws

    // MARK: Pomodoro em execucao

    /// Ancora o Pomodoro da tarefa em `now` e persiste. **A ancora precisa estar em disco**:
    /// e ela que permite reconstruir o estado certo se o app for morto no meio (PRD 6.3).
    func startPomodoro(on task: FocusTask, at now: Date) throws

    /// Desancora (fim ou desistencia).
    func stopPomodoro(on task: FocusTask) throws

    /// A tarefa com Pomodoro ancorado, se houver. So pode haver uma.
    func activeTask() throws -> FocusTask?

    // MARK: Ajustes (singleton)

    /// Ajustes globais, criados com os defaults no primeiro acesso.
    func settings() throws -> AppSettings

    // MARK: Sessoes de foco

    @discardableResult
    func recordSession(
        taskID: UUID?,
        startedAt: Date,
        endedAt: Date,
        effectiveSeconds: Int,
        completedCycles: Int,
        wasInterrupted: Bool
    ) throws -> FocusSession

    /// Sessoes que comecaram no intervalo, para a UI derivar estatisticas em runtime.
    func sessions(from: Date, to: Date) throws -> [FocusSession]
}

/// Implementacao sobre SwiftData.
///
/// Toda decisao de regra e delegada a `DailyTaskRules` - se uma regra mudar, muda la e
/// os testes puros pegam, sem precisar de container nem simulador.
@MainActor
final class SwiftDataPersistenceService: PersistenceService {
    /// Retido de proposito. O `ModelContext` **nao** segura o container: e o container que
    /// retem o `mainContext`, e a referencia de volta nao mantem vivo. Guardar so o contexto
    /// faz o container morrer junto com o escopo que o criou e qualquer operacao seguinte
    /// derruba o processo (SIGTRAP, sem erro Swift). Nao trocar por uma propriedade `context`
    /// solitaria.
    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    // MARK: Tarefas do dia

    func tasks(on dayKey: String) throws -> [FocusTask] {
        let descriptor = FetchDescriptor<FocusTask>(
            predicate: #Predicate { $0.dayKey == dayKey },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func canCreateTask(now: Date = Date()) throws -> Bool {
        let today = DailyTaskRules.dayKey(for: now)
        let snapshots = try tasks(on: today).map { $0.snapshot() }
        return DailyTaskRules.canCreate(tasks: snapshots, today: today)
    }

    @discardableResult
    func createTask(
        title: String,
        preset: PomodoroPreset? = nil,
        now: Date = Date()
    ) throws -> FocusTask {
        let today = DailyTaskRules.dayKey(for: now)
        let snapshots = try tasks(on: today).map { $0.snapshot() }

        guard DailyTaskRules.canCreate(tasks: snapshots, today: today) else {
            throw PersistenceError.dayIsFull(
                slotsUsed: DailyTaskRules.slotsUsed(tasks: snapshots, today: today)
            )
        }

        let chosen = try preset ?? settings().defaultPreset
        let task = FocusTask(title: title, createdAt: now, dayKey: today, preset: chosen)
        context.insert(task)
        try context.save()
        return task
    }

    func complete(_ task: FocusTask, at now: Date = Date()) throws {
        task.isCompleted = true
        task.completedAt = now
        try context.save()
    }

    @discardableResult
    func rollOverPendingTasks(now: Date = Date()) throws -> Int {
        let today = DailyTaskRules.dayKey(for: now)

        // So as pendentes interessam; a regra decide quais delas rolam.
        let pending = try context.fetch(
            FetchDescriptor<FocusTask>(predicate: #Predicate { !$0.isCompleted })
        )
        let ids = Set(
            DailyTaskRules.rolloverCandidates(tasks: pending.map { $0.snapshot() }, today: today)
        )
        guard !ids.isEmpty else { return 0 }

        for task in pending where ids.contains(task.id) {
            task.dayKey = today
        }
        try context.save()
        return ids.count
    }

    func delete(_ task: FocusTask) throws {
        context.delete(task)
        try context.save()
    }

    // MARK: Pomodoro em execucao

    func startPomodoro(on task: FocusTask, at now: Date) throws {
        // So uma tarefa ancorada por vez: iniciar outra encerra a anterior.
        for other in try context.fetch(
            FetchDescriptor<FocusTask>(predicate: #Predicate { $0.startedAt != nil })
        ) where other.id != task.id {
            other.startedAt = nil
        }
        task.startedAt = now
        try context.save()
    }

    func stopPomodoro(on task: FocusTask) throws {
        task.startedAt = nil
        try context.save()
    }

    func activeTask() throws -> FocusTask? {
        try context.fetch(
            FetchDescriptor<FocusTask>(predicate: #Predicate { $0.startedAt != nil })
        ).first
    }

    // MARK: Ajustes

    func settings() throws -> AppSettings {
        if let existing = try context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        try context.save()
        return created
    }

    // MARK: Sessoes

    @discardableResult
    func recordSession(
        taskID: UUID?,
        startedAt: Date,
        endedAt: Date,
        effectiveSeconds: Int,
        completedCycles: Int,
        wasInterrupted: Bool
    ) throws -> FocusSession {
        let session = FocusSession(
            startedAt: startedAt,
            endedAt: endedAt,
            effectiveSeconds: effectiveSeconds,
            taskID: taskID,
            completedCycles: completedCycles,
            wasInterrupted: wasInterrupted
        )
        context.insert(session)
        try context.save()
        return session
    }

    func sessions(from: Date, to: Date) throws -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startedAt >= from && $0.startedAt <= to },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}

// MARK: - Container

extension ModelContainer {
    /// Schema do app num lugar so, para o app e os testes nao divergirem.
    static func lessSchema() -> Schema {
        Schema([FocusTask.self, FocusSession.self, AppSettings.self])
    }

    /// Container do app (em disco).
    ///
    /// A URL do store e explicita, e `Application Support` e criado antes: o default do
    /// SwiftData assume que esse diretorio ja existe, o que nao e verdade num container
    /// recem-criado (simulador, primeiro launch, app host de teste) - de onde vinha o
    /// `Failed to stat path .../Application Support/default.store` que derrubava o app.
    static func less() throws -> ModelContainer {
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try ModelContainer(
            for: lessSchema(),
            configurations: ModelConfiguration(url: directory.appending(path: "less.store"))
        )
    }

    /// Container efemero para testes - nada toca o disco.
    static func lessInMemory() throws -> ModelContainer {
        try ModelContainer(
            for: lessSchema(),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
