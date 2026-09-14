import Foundation
import Observation

/// Contrato do timer Pomodoro (PRD 6; ADR-05). A logica de calculo vive em
/// `PomodoroEngine` (pura, testavel); este servico so guarda a ancora de tempo e
/// expoe o estado observavel para a UI. Ancorado em `Date` absoluto, NUNCA contagem
/// incremental (guardrail 12.4). `@MainActor` porque so alimenta a interface; o motor
/// de audio e que fica fora da main thread (ADR-06).
@MainActor
protocol TimerService: Sendable {
    var phase: PomodoroPhase { get }
    var remaining: TimeInterval { get }
    var isRunning: Bool { get }

    func start(preset: PomodoroPreset, at now: Date)
    func pause(at now: Date)
    func resume(at now: Date)
    func reset()
    /// Recalcula o estado a partir do relogio (retorno do background, PRD 6.3).
    func reconcile(now: Date)
}

/// Implementacao concreta. Guarda apenas a ancora (`startDate`) e o tempo congelado ao
/// pausar (`pausedElapsed`); todo o estado derivado sai do `PomodoroEngine`, o que faz a
/// correcao de multiplas transicoes perdidas em background ser automatica (PRD 6.3).
@MainActor
@Observable
final class LiveTimerService: TimerService {
    private(set) var phase: PomodoroPhase = .focus
    private(set) var remaining: TimeInterval = 0
    private(set) var completedFocusBlocks: Int = 0
    private(set) var segmentIndex: Int = 0

    private var preset: PomodoroPreset = .short
    private var startDate: Date?
    /// Tempo decorrido congelado enquanto pausado (nil = rodando ou ocioso).
    private var pausedElapsed: TimeInterval?

    var isRunning: Bool { startDate != nil && pausedElapsed == nil }

    func start(preset: PomodoroPreset, at now: Date = Date()) {
        self.preset = preset
        self.startDate = now
        self.pausedElapsed = nil
        reconcile(now: now)
    }

    func pause(at now: Date = Date()) {
        guard let start = startDate, pausedElapsed == nil else { return }
        pausedElapsed = max(0, now.timeIntervalSince(start))
        reconcile(now: now)
    }

    func resume(at now: Date = Date()) {
        guard let paused = pausedElapsed else { return }
        // reancora o inicio para tras, de modo que o tempo decorrido continue de onde parou
        startDate = now.addingTimeInterval(-paused)
        pausedElapsed = nil
        reconcile(now: now)
    }

    func reset() {
        startDate = nil
        pausedElapsed = nil
        phase = .focus
        remaining = preset.focus
        completedFocusBlocks = 0
        segmentIndex = 0
    }

    func reconcile(now: Date = Date()) {
        guard let start = startDate else { return }
        let elapsed = pausedElapsed ?? max(0, now.timeIntervalSince(start))
        let status = PomodoroEngine(preset: preset).status(elapsed: elapsed)
        phase = status.phase
        remaining = status.remaining
        completedFocusBlocks = status.completedFocusBlocks
        segmentIndex = status.segmentIndex
    }
}
