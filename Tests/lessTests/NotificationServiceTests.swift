import Testing
import Foundation
import UserNotifications
@testable import less

/// Duble do centro de notificacoes: registra o que foi pedido, sem tocar o sistema.
/// `actor` porque o servico o usa de contexto concorrente e o estado e mutavel.
actor FakeNotificationCenter: NotificationScheduling {
    private(set) var pending: [PendingNotification] = []
    private(set) var authorizationCalls = 0
    private(set) var removeCalls: [[String]] = []
    private var authorizationResult = true

    func requestAuthorization() async throws -> Bool {
        authorizationCalls += 1
        return authorizationResult
    }

    func add(_ notification: PendingNotification) async throws {
        pending.append(notification)
    }

    func removePending(withIdentifiers identifiers: [String]) async {
        removeCalls.append(identifiers)
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func pendingIdentifiers() async -> [String] {
        pending.map(\.identifier)
    }

    // Helpers de teste
    func setAuthorizationResult(_ value: Bool) { authorizationResult = value }
    func seed(_ notification: PendingNotification) { pending.append(notification) }
    func phases() -> [PomodoroPhase] { pending.map(\.phase) }
}

/// Testes da Fase 3: traducao de transicoes do Pomodoro em notificacoes locais.
///
/// Verifica-se **intencao** (quantas, quais fases, quais datas, o que foi cancelado),
/// nunca a copy traduzida - a fase viaja no proprio tipo justamente para o teste nao
/// quebrar quando o texto mudar.
@Suite("NotificationService")
struct NotificationServiceTests {
    let start = Date(timeIntervalSince1970: 1_789_000_000)

    private func transitions(
        preset: PomodoroPreset = .short,
        limit: Int = 4
    ) -> [PomodoroTransition] {
        PomodoroEngine(preset: preset)
            .upcomingTransitions(start: start, now: start, limit: limit)
    }

    @Test("agenda uma notificacao por transicao futura")
    func schedulesOnePerTransition() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)

        await service.rescheduleTransitions(transitions(limit: 4), taskTitle: nil, now: start)

        #expect(await center.pendingIdentifiers().count == 4)
    }

    @Test("a sequencia de fases notificadas segue o Pomodoro classico")
    func phaseSequenceMatchesEngine() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)

        // preset .short: sai do foco -> curta, sai da curta -> foco, ...
        await service.rescheduleTransitions(transitions(limit: 4), taskTitle: nil, now: start)

        #expect(await center.phases() == [.shortBreak, .focus, .shortBreak, .focus])
    }

    @Test("apos 4 blocos de foco a notificacao anuncia pausa longa")
    func longBreakIsAnnounced() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)

        // 8 transicoes cobrem o super-ciclo inteiro
        await service.rescheduleTransitions(transitions(limit: 8), taskTitle: nil, now: start)

        let phases = await center.phases()
        #expect(phases.filter { $0 == .longBreak }.count == 1)
    }

    @Test("transicao no passado nao e agendada")
    func ignoresPastTransitions() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)

        let past = PomodoroTransition(at: start.addingTimeInterval(-60), entering: .focus)
        let future = PomodoroTransition(at: start.addingTimeInterval(60), entering: .shortBreak)

        await service.rescheduleTransitions([past, future], taskTitle: nil, now: start)

        #expect(await center.phases() == [.shortBreak])
    }

    @Test("reagendar NAO acumula duplicata")
    func reschedulingDoesNotAccumulate() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)
        let upcoming = transitions(limit: 4)

        await service.rescheduleTransitions(upcoming, taskTitle: nil, now: start)
        await service.rescheduleTransitions(upcoming, taskTitle: nil, now: start)
        await service.rescheduleTransitions(upcoming, taskTitle: nil, now: start)

        #expect(await center.pendingIdentifiers().count == 4) // e nao 12
    }

    @Test("cancelar so remove as notificacoes deste app")
    func cancelOnlyRemovesOurs() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)

        // algo de outra origem, que nao pode ser tocado
        await center.seed(PendingNotification(
            identifier: "outra.origem.lembrete",
            title: "x", body: "", phase: .focus, fireAt: start
        ))
        await service.rescheduleTransitions(transitions(limit: 3), taskTitle: nil, now: start)

        await service.cancelAll()

        let ids = await center.pendingIdentifiers()
        #expect(ids == ["outra.origem.lembrete"])
    }

    @Test("o titulo da tarefa vai no corpo quando existe")
    func taskTitleGoesInBody() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)

        await service.rescheduleTransitions(
            transitions(limit: 1), taskTitle: "escrever o PRD", now: start
        )

        #expect(await center.pending.first?.body == "escrever o PRD")
    }

    @Test("sem tarefa, o corpo fica vazio - nada de texto de engajamento")
    func noTaskMeansEmptyBody() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)

        await service.rescheduleTransitions(transitions(limit: 1), taskTitle: nil, now: start)

        #expect(await center.pending.first?.body == "")
    }

    @Test("a data de disparo casa exatamente com a transicao do motor")
    func fireDateMatchesTransition() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)
        let upcoming = transitions(limit: 3)

        await service.rescheduleTransitions(upcoming, taskTitle: nil, now: start)

        let fired = await center.pending.map(\.fireAt)
        #expect(fired == upcoming.map(\.at))
        // preset .short: primeira transicao 25 min apos o inicio
        #expect(fired.first == start.addingTimeInterval(25 * 60))
    }

    @Test("identificadores sao unicos e prefixados")
    func identifiersAreUniqueAndPrefixed() async {
        let center = FakeNotificationCenter()
        let service = LiveNotificationService(center: center)

        await service.rescheduleTransitions(transitions(limit: 8), taskTitle: nil, now: start)

        let ids = await center.pendingIdentifiers()
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix(LiveNotificationService.identifierPrefix) })
    }

    @Test("permissao negada nao derruba o servico")
    func deniedAuthorizationIsHandled() async {
        let center = FakeNotificationCenter()
        await center.setAuthorizationResult(false)
        let service = LiveNotificationService(center: center)

        #expect(await service.requestAuthorization() == false)
    }

    @Test("o request do sistema sai por data absoluta, sem repeticao")
    func systemRequestUsesAbsoluteDate() {
        let notification = PendingNotification(
            identifier: "less.pomodoro.transition.0.123",
            title: "titulo", body: "corpo", phase: .shortBreak,
            fireAt: start.addingTimeInterval(1500)
        )

        let request = SystemNotificationCenter.request(from: notification)
        let trigger = request.trigger as? UNCalendarNotificationTrigger

        #expect(request.identifier == notification.identifier)
        #expect(request.content.userInfo["phase"] as? String == "shortBreak")
        #expect(trigger?.repeats == false)

        let expected = Calendar.current.dateComponents(
            [.hour, .minute, .second], from: notification.fireAt
        )
        #expect(trigger?.dateComponents.hour == expected.hour)
        #expect(trigger?.dateComponents.minute == expected.minute)
        #expect(trigger?.dateComponents.second == expected.second)
    }
}
