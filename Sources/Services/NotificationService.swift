import Foundation
import UserNotifications

/// Descricao de uma notificacao a agendar, independente do framework.
///
/// Existe para o `UNNotificationRequest` (que **nao** e `Sendable`) nao atravessar
/// fronteira de concorrencia: sob strict concurrency isso e erro de compilacao, e o
/// compilador esta certo - passar objeto de classe mutavel entre atores e armadilha.
/// A traducao para o tipo do sistema acontece so na borda, em `SystemNotificationCenter`.
struct PendingNotification: Sendable, Equatable {
    let identifier: String
    let title: String
    let body: String
    let phase: PomodoroPhase
    let fireAt: Date
}

/// Superficie minima do centro de notificacoes que o app usa.
///
/// Existe para o servico ser testavel no CI: o centro real exige app em execucao e
/// permissao concedida, coisas que teste unitario nao tem. Em producao o adaptador e
/// `SystemNotificationCenter`; nos testes, um duble que so registra chamadas.
protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func add(_ notification: PendingNotification) async throws
    func removePending(withIdentifiers identifiers: [String]) async
    func pendingIdentifiers() async -> [String]
}

/// Adaptador sobre o `UNUserNotificationCenter` real. Sem estado proprio.
struct SystemNotificationCenter: NotificationScheduling {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func add(_ notification: PendingNotification) async throws {
        try await UNUserNotificationCenter.current().add(Self.request(from: notification))
    }

    func removePending(withIdentifiers identifiers: [String]) async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .map(\.identifier)
    }

    /// Traducao para o tipo do sistema. Pura e estatica de proposito: da para testar o
    /// formato do request sem centro de notificacoes nenhum.
    static func request(from notification: PendingNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        // A fase viaja junto para a UI reconciliar ao abrir pela notificacao.
        content.userInfo = ["phase": notification.phase.rawValue]

        // Disparo por DATA ABSOLUTA, nunca por intervalo relativo: a ancora do Pomodoro e
        // um timestamp e o app pode ficar suspenso no meio (ADR-05, guardrail 12.4).
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: notification.fireAt
        )
        return UNNotificationRequest(
            identifier: notification.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
    }
}

/// Contrato de notificacoes locais (PRD 6.3).
///
/// Agenda **uma notificacao local por transicao de ciclo prevista** e as cancela ao pausar,
/// resetar ou reconfigurar. A UNICA notificacao permitida no app e a transicao de ciclo do
/// Pomodoro - nada de engajamento, streak ou lembrete (guardrail 12.9).
///
/// As datas vem prontas do `PomodoroEngine.upcomingTransitions(start:now:limit:)`: este
/// servico **nao recalcula** quando cada fase termina, so traduz transicao em notificacao.
protocol NotificationService: Sendable {
    /// Pede permissao ao usuario. `false` se negada ou indisponivel.
    func requestAuthorization() async -> Bool

    /// Substitui as notificacoes pendentes do Pomodoro pelas destas transicoes.
    /// Sempre cancela antes de agendar, para nao acumular duplicata a cada reconciliacao.
    /// Transicoes com data <= `now` sao ignoradas (nao ha o que notificar no passado).
    func rescheduleTransitions(
        _ transitions: [PomodoroTransition],
        taskTitle: String?,
        now: Date
    ) async

    /// Cancela apenas as notificacoes do Pomodoro deste app.
    func cancelAll() async
}

/// Implementacao sobre `UserNotifications`.
final class LiveNotificationService: NotificationService {
    /// Prefixo dos identificadores. Serve para `cancelAll()` remover **so** o que este
    /// servico agendou, sem varrer notificacoes de outras partes do app no futuro.
    static let identifierPrefix = "less.pomodoro.transition."

    private let center: any NotificationScheduling

    init(center: any NotificationScheduling = SystemNotificationCenter()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization()) ?? false
    }

    func rescheduleTransitions(
        _ transitions: [PomodoroTransition],
        taskTitle: String? = nil,
        now: Date = Date()
    ) async {
        await cancelAll()
        for (offset, transition) in transitions.enumerated() where transition.at > now {
            let notification = Self.makeNotification(
                for: transition, offset: offset, taskTitle: taskTitle
            )
            try? await center.add(notification)
        }
    }

    func cancelAll() async {
        let ours = await center.pendingIdentifiers()
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        guard !ours.isEmpty else { return }
        await center.removePending(withIdentifiers: ours)
    }

    // MARK: Montagem (pura)

    /// Monta a notificacao de uma transicao. `offset` so desempata o identificador quando
    /// duas transicoes caem no mesmo segundo.
    static func makeNotification(
        for transition: PomodoroTransition,
        offset: Int,
        taskTitle: String?
    ) -> PendingNotification {
        PendingNotification(
            identifier: "\(identifierPrefix)\(offset).\(Int(transition.at.timeIntervalSince1970))",
            title: title(entering: transition.entering),
            body: taskTitle ?? "",
            phase: transition.entering,
            fireAt: transition.at
        )
    }

    /// Copy da notificacao. Sem alegacao de saude e sem tom de cobranca (guardrail 12.6 /
    /// PRD 10.2): so anuncia o que comeca agora.
    static func title(entering phase: PomodoroPhase) -> String {
        switch phase {
        case .focus:      return String(localized: "notification.focus.title")
        case .shortBreak: return String(localized: "notification.shortBreak.title")
        case .longBreak:  return String(localized: "notification.longBreak.title")
        }
    }
}
