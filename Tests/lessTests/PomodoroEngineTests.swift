import Testing
import Foundation
@testable import less

/// Testes do motor puro do Pomodoro (PRD 6; ADR-05). Cobrem a "correcao em background"
/// (PRD 6.3): dado o tempo decorrido, o estado tem de sair correto mesmo com N transicoes
/// perdidas - e o requisito que mais falha em apps do tipo.
@Suite("PomodoroEngine")
struct PomodoroEngineTests {
    // Preset curto: foco 1500, curta 300, longa 900, 4 blocos ate a longa.
    // Segmentos: [1500, 300, 1500, 300, 1500, 300, 1500, 900], soma = 7800.
    let engine = PomodoroEngine(preset: .short)

    @Test("comeca em foco com o bloco inteiro pela frente")
    func startsInFocus() {
        let s = engine.status(elapsed: 0)
        #expect(s.phase == .focus)
        #expect(s.segmentIndex == 0)
        #expect(s.remaining == 1500)
        #expect(s.completedFocusBlocks == 0)
    }

    @Test("no fim exato do foco entra na pausa curta")
    func focusToShortBreak() {
        let s = engine.status(elapsed: 1500)
        #expect(s.phase == .shortBreak)
        #expect(s.segmentIndex == 1)
        #expect(s.remaining == 300)
        #expect(s.completedFocusBlocks == 1)
    }

    @Test("meio do segundo bloco de foco")
    func midSecondFocus() {
        let s = engine.status(elapsed: 1500 + 300 + 100) // 100s dentro do foco 2
        #expect(s.phase == .focus)
        #expect(s.segmentIndex == 2)
        #expect(s.remaining == 1400)
        #expect(s.completedFocusBlocks == 1)
    }

    @Test("apos 4 blocos de foco vem a pausa longa")
    func longBreakAfterFourFocus() {
        // fim do 4o foco = 1500+300+1500+300+1500+300+1500 = 6900
        let s = engine.status(elapsed: 6900 + 50)
        #expect(s.phase == .longBreak)
        #expect(s.segmentIndex == 7)
        #expect(s.remaining == 850)
        #expect(s.completedFocusBlocks == 4)
    }

    @Test("multiplas transicoes perdidas em background reconciliam certo")
    func reconcilesManyMissedTransitions() {
        // um super-ciclo = 7800s; 7800 + 1600 cai na pausa CURTA do 2o ciclo:
        // no periodo novo -> foco1 (0..1500), pausa curta (1500..1800); 1600 = 100s na pausa.
        let s = engine.status(elapsed: 7800 + 1600)
        #expect(s.phase == .shortBreak)
        #expect(s.remaining == 200)          // 1800 - 1600
        #expect(s.completedFocusBlocks == 5) // 4 do 1o ciclo + 1 do 2o
    }

    @Test("preset longo tem duracoes proprias")
    func longPreset() {
        let e = PomodoroEngine(preset: .long)
        let s = e.status(elapsed: 0)
        #expect(s.phase == .focus)
        #expect(s.remaining == 3000) // 50 min
        // fim do foco -> pausa de 10 min
        #expect(e.status(elapsed: 3000).phase == .shortBreak)
        #expect(e.status(elapsed: 3000).remaining == 600)
    }

    @Test("elapsed negativo e tratado como inicio")
    func negativeElapsedClamped() {
        let s = engine.status(elapsed: -50)
        #expect(s.phase == .focus)
        #expect(s.remaining == 1500)
    }

    @Test("proximas transicoes sao datas absolutas em ordem")
    func upcomingTransitions() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let now = start // ainda no comeco
        let t = engine.upcomingTransitions(start: start, now: now, limit: 3)
        #expect(t.count == 3)
        #expect(t[0].entering == .shortBreak)
        #expect(t[0].at == start.addingTimeInterval(1500))
        #expect(t[1].entering == .focus)
        #expect(t[1].at == start.addingTimeInterval(1800))
        #expect(t[2].entering == .shortBreak)
        #expect(t[2].at == start.addingTimeInterval(3300))
    }

    // MARK: Tempo de foco x tempo de relogio

    @Test("tempo de foco desconta as pausas - 25+5+25 sao 50 de foco, nao 55")
    func focusedSecondsExcludesBreaks() {
        let engine = PomodoroEngine(preset: .short)
        // 55 min corridos = foco 25 + pausa 5 + foco 25
        #expect(engine.focusedSeconds(elapsed: 55 * 60) == 50 * 60)
    }

    @Test("dentro do primeiro bloco, foco e o proprio tempo decorrido")
    func focusedSecondsInsideFirstBlock() {
        let engine = PomodoroEngine(preset: .short)
        #expect(engine.focusedSeconds(elapsed: 10 * 60) == 10 * 60)
        #expect(engine.focusedSeconds(elapsed: 0) == 0)
    }

    @Test("tempo parado na pausa nao acrescenta foco")
    func breakTimeAddsNothing() {
        let engine = PomodoroEngine(preset: .short)
        // 25 de foco fechados, depois 1, 3 e 5 min de pausa: foco congela em 25
        #expect(engine.focusedSeconds(elapsed: 25 * 60) == 25 * 60)
        #expect(engine.focusedSeconds(elapsed: 26 * 60) == 25 * 60)
        #expect(engine.focusedSeconds(elapsed: 28 * 60) == 25 * 60)
        #expect(engine.focusedSeconds(elapsed: 30 * 60) == 25 * 60)
    }

    @Test("a pausa longa tambem nao conta como foco")
    func longBreakAddsNothing() {
        let engine = PomodoroEngine(preset: .short)
        // 4 blocos de foco + 3 pausas curtas = 115 min corridos, 100 de foco
        #expect(engine.focusedSeconds(elapsed: 115 * 60) == 100 * 60)
        // +15 min de pausa longa: relogio anda 15, foco nao anda nada
        #expect(engine.focusedSeconds(elapsed: 130 * 60) == 100 * 60)
        // recomeca o foco no 5o bloco
        #expect(engine.focusedSeconds(elapsed: 140 * 60) == 110 * 60)
    }

    @Test("preset longo tem sua propria conta de foco")
    func focusedSecondsLongPreset() {
        let engine = PomodoroEngine(preset: .long)
        // 50 de foco + 10 de pausa + 50 de foco = 110 corridos, 100 de foco
        #expect(engine.focusedSeconds(elapsed: 110 * 60) == 100 * 60)
    }

    @Test("elapsed negativo nao vira foco negativo")
    func focusedSecondsNeverNegative() {
        #expect(PomodoroEngine(preset: .short).focusedSeconds(elapsed: -100) == 0)
    }
}
