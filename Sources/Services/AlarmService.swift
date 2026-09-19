import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Aviso de transicao de ciclo do Pomodoro que **fura o Modo Foco e o silencioso**.
///
/// Por que isto existe: uma `UNUserNotification` comum e **silenciada pelo proprio Modo Foco**
/// - ou seja, exatamente quando o usuario ligou o Foco para trabalhar, ele para de ser avisado
/// do fim do bloco. E o furo classico desta categoria de app.
///
/// A doc do AlarmKit e literal: um alarme *"overrides both a device's focus and silent mode,
/// if necessary"*. Nao exige entitlement nenhuma (so `NSAlarmKitUsageDescription` e a
/// autorizacao do usuario), entao funciona ate com Apple ID gratuita.
///
/// **Continua sendo o UNICO aviso do app** - transicao de ciclo do Pomodoro, nada de
/// engajamento (guardrail 12.9). Trocamos o meio, nao a politica.
protocol AlarmScheduling: Sendable {
    /// `false` quando o usuario nega ou o recurso nao existe nesta versao do iOS.
    func requestAuthorization() async -> Bool
    /// CONSULTA o estado, sem pedir nada. Funciona em background - onde nao ha como mostrar
    /// dialogo - e nao gasta a unica chance de perguntar.
    func isAuthorized() async -> Bool
    var isAvailable: Bool { get }
    /// Agenda um aviso por transicao. Substitui o que estiver agendado.
    func schedule(_ transitions: [PomodoroTransition], taskTitle: String?, now: Date) async
    func cancelAll() async
}

/// Identificadores estaveis dos alarmes do Pomodoro, para cancelar so o que e nosso.
enum AlarmIdentifiers {
    /// Namespace fixo: os IDs sao derivados dele, entao sobrevivem a relancamento do app.
    static let namespace = UUID(uuidString: "5E5C7BF0-1E55-4A1B-9E0C-000000000001")!

    static func id(forTransitionIndex index: Int) -> UUID {
        var bytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        bytes[15] = UInt8(truncatingIfNeeded: index &+ 1)
        return NSUUID(uuidBytes: bytes) as UUID
    }

    /// O teto do iOS para alarmes pendentes por app e baixo; o Pomodoro so precisa das
    /// proximas transicoes, entao limitar aqui evita bater em `maximumLimitReached`.
    static let maxScheduled = 5
}

#if canImport(AlarmKit)

/// Metadado exigido pelo AlarmKit. Vazio de proposito: o `less` nao tem o que anexar, e
/// nada aqui deve virar dado persistido (guardrail 12.12).
@available(iOS 26.0, *)
struct LessAlarmMetadata: AlarmMetadata {
    init() {}
}

/// Implementacao sobre AlarmKit (iOS 26+).
@available(iOS 26.0, *)
final class LiveAlarmService: AlarmScheduling {
    var isAvailable: Bool { true }

    func isAuthorized() async -> Bool {
        AlarmManager.shared.authorizationState == .authorized
    }

    func requestAuthorization() async -> Bool {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await manager.requestAuthorization()) == .authorized
        @unknown default:
            return false
        }
    }

    func schedule(
        _ transitions: [PomodoroTransition],
        taskTitle: String?,
        now: Date = .now
    ) async {
        await cancelAll()
        guard AlarmManager.shared.authorizationState == .authorized else { return }

        let upcoming = transitions
            .filter { $0.at > now }
            .prefix(AlarmIdentifiers.maxScheduled)

        for (index, transition) in upcoming.enumerated() {
            let alert = AlarmPresentation.Alert(
                title: Self.title(entering: transition.entering),
                stopButton: AlarmButton(
                    text: "alarm.stop",
                    textColor: .white,
                    systemImageName: "checkmark"
                )
            )
            let attributes = AlarmAttributes<LessAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: LessAlarmMetadata(),
                tintColor: Color.accentColor
            )
            let configuration = AlarmManager.AlarmConfiguration.alarm(
                schedule: .fixed(transition.at),
                attributes: attributes
            )
            _ = try? await AlarmManager.shared.schedule(
                id: AlarmIdentifiers.id(forTransitionIndex: index),
                configuration: configuration
            )
        }
    }

    func cancelAll() async {
        // So os nossos: os IDs saem do namespace fixo, entao nada de outro app e tocado.
        for index in 0..<AlarmIdentifiers.maxScheduled {
            try? AlarmManager.shared.cancel(id: AlarmIdentifiers.id(forTransitionIndex: index))
        }
    }

    /// Mesma copy da notificacao: so anuncia a fase que comeca, sem alegacao de saude nem
    /// tom de cobranca (guardrail 12.6 / PRD 10.2).
    static func title(entering phase: PomodoroPhase) -> LocalizedStringResource {
        switch phase {
        case .focus:      return "notification.focus.title"
        case .shortBreak: return "notification.shortBreak.title"
        case .longBreak:  return "notification.longBreak.title"
        }
    }
}

#endif

/// Usado quando o AlarmKit nao existe (iOS < 26). Nao avisa nada por conta propria: quem
/// cobre esse caso e o `NotificationService`, que continua no lugar.
struct UnavailableAlarmService: AlarmScheduling {
    var isAvailable: Bool { false }
    func requestAuthorization() async -> Bool { false }
    func isAuthorized() async -> Bool { false }
    func schedule(_ transitions: [PomodoroTransition], taskTitle: String?, now: Date) async {}
    func cancelAll() async {}
}

/// Escolhe a implementacao conforme a versao do iOS, sem subir o deployment target do app
/// (que segue em 17.0 - baixar a base instalada seria pior que perder o alarme).
enum AlarmServiceFactory {
    static func make() -> any AlarmScheduling {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return LiveAlarmService()
        }
        #endif
        return UnavailableAlarmService()
    }
}
