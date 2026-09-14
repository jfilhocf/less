import Foundation

/// Resultado do calculo de estado do Pomodoro num dado instante.
struct PomodoroStatus: Sendable, Equatable {
    /// Indice do segmento atual na sequencia (0 = primeiro bloco de foco).
    let segmentIndex: Int
    /// Fase atual.
    let phase: PomodoroPhase
    /// Tempo restante no segmento atual, em segundos.
    let remaining: TimeInterval
    /// Blocos de foco JA concluidos (fechados) ate agora.
    let completedFocusBlocks: Int
}

/// Uma transicao futura de fase, para agendar notificacao local (PRD 6.3).
struct PomodoroTransition: Sendable, Equatable {
    let at: Date
    let entering: PomodoroPhase
}

/// Motor puro do Pomodoro (PRD 6; ADR-05: ancorado em timestamp, NUNCA contagem
/// incremental - guardrail 12.4).
///
/// E deliberadamente sem estado mutavel e sem dependencia de framework: dado o preset,
/// o instante de inicio e um "agora", calcula por aritmetica qual fase esta ativa,
/// quanto falta e quantos blocos de foco fecharam. Isso resolve de graca a "correcao
/// em background" (PRD 6.3): mesmo que o app fique horas suspenso e perca N transicoes,
/// `status(elapsed:)` devolve o estado correto direto do tempo decorrido. Puro = testavel
/// no CI sem device e sem relogio real.
///
/// Sequencia (para `cyclesUntilLongBreak = N`): um "super-ciclo" tem 2N segmentos -
/// [foco, pausa curta] repetido N-1 vezes, depois [foco, pausa longa]. Ex. N=4:
/// foco, curta, foco, curta, foco, curta, foco, LONGA, e repete.
struct PomodoroEngine: Sendable {
    let preset: PomodoroPreset

    private var periodLength: Int { 2 * preset.cyclesUntilLongBreak }

    /// Fase do segmento de indice `index` (indices pares = foco).
    func phase(at index: Int) -> PomodoroPhase {
        let pos = index % periodLength
        if pos % 2 == 0 { return .focus }
        if pos == periodLength - 1 { return .longBreak }
        return .shortBreak
    }

    /// Duracao do segmento de indice `index`.
    func duration(at index: Int) -> TimeInterval {
        switch phase(at: index) {
        case .focus:      return preset.focus
        case .shortBreak: return preset.shortBreak
        case .longBreak:  return preset.longBreak
        }
    }

    /// Estado do Pomodoro apos `elapsed` segundos de execucao efetiva (ja descontadas
    /// as pausas do usuario, que o servico trata ajustando a ancora).
    func status(elapsed: TimeInterval) -> PomodoroStatus {
        let elapsed = max(0, elapsed)
        var index = 0
        var accumulated: TimeInterval = 0
        // Limite de seguranca: mesmo dias suspenso nao chegam perto disso.
        let safetyCap = 1_000_000
        while index < safetyCap {
            let segment = duration(at: index)
            if elapsed < accumulated + segment {
                return PomodoroStatus(
                    segmentIndex: index,
                    phase: phase(at: index),
                    remaining: (accumulated + segment) - elapsed,
                    completedFocusBlocks: completedFocusBlocks(before: index)
                )
            }
            accumulated += segment
            index += 1
        }
        return PomodoroStatus(
            segmentIndex: index,
            phase: phase(at: index),
            remaining: 0,
            completedFocusBlocks: completedFocusBlocks(before: index)
        )
    }

    /// Estado a partir de datas absolutas (conveniencia).
    func status(start: Date, now: Date) -> PomodoroStatus {
        status(elapsed: now.timeIntervalSince(start))
    }

    /// Numero de segmentos de foco totalmente concluidos antes do indice `index`.
    /// Indices de foco sao os pares; a contagem em [0, index) e (index + 1) / 2.
    private func completedFocusBlocks(before index: Int) -> Int {
        (index + 1) / 2
    }

    /// Proximas transicoes de fase apos `now`, para agendar notificacoes (PRD 6.3).
    /// Retorna no maximo `limit` transicoes (o iOS limita notificacoes pendentes).
    func upcomingTransitions(start: Date, now: Date, limit: Int = 8) -> [PomodoroTransition] {
        var result: [PomodoroTransition] = []
        var index = 0
        var boundary: TimeInterval = 0
        let safetyCap = 1_000_000
        while index < safetyCap && result.count < limit {
            boundary += duration(at: index)
            let at = start.addingTimeInterval(boundary)
            if at > now {
                // a transicao entra na fase do PROXIMO segmento
                result.append(PomodoroTransition(at: at, entering: phase(at: index + 1)))
            }
            index += 1
        }
        return result
    }
}
