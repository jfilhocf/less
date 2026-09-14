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
}
