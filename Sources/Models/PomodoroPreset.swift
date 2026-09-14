import Foundation

/// Fase da maquina de estados do Pomodoro (PRD 6.1).
enum PomodoroPhase: String, Sendable, Codable, CaseIterable {
    case focus
    case shortBreak
    case longBreak
}

/// Os dois unicos presets de Pomodoro do less (adendo 2026-09-14: substitui o Pomodoro
/// configuravel do PRD 6.2 por escolha fixa - "menos e mais"). Cada tarefa do dia inicia
/// num destes presets. Duracoes em segundos.
///
/// Pomodoro classico: N blocos de foco intercalados com pausa curta e, apos o N-esimo,
/// uma pausa longa (`cyclesUntilLongBreak`).
enum PomodoroPreset: String, Sendable, Codable, CaseIterable {
    case short   // 25 / 5
    case long    // 50 / 10

    /// Duracao do bloco de foco.
    var focus: TimeInterval {
        switch self {
        case .short: return 25 * 60
        case .long:  return 50 * 60
        }
    }

    /// Duracao da pausa curta.
    var shortBreak: TimeInterval {
        switch self {
        case .short: return 5 * 60
        case .long:  return 10 * 60
        }
    }

    /// Duracao da pausa longa (apos `cyclesUntilLongBreak` blocos de foco).
    var longBreak: TimeInterval {
        switch self {
        case .short: return 15 * 60
        case .long:  return 20 * 60
        }
    }

    /// Blocos de foco ate a pausa longa (PRD 6.2: padrao 4).
    var cyclesUntilLongBreak: Int { 4 }

    /// Rotulo curto para a interface (ex.: "25 / 5").
    var label: String {
        switch self {
        case .short: return "25 / 5"
        case .long:  return "50 / 10"
        }
    }
}
