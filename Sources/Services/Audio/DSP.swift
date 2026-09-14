import Foundation

/// Sintese procedural pura do motor de audio (PRD 5.2, 5.4; guardrail 12.5: binaural
/// e ruido SEMPRE por sintese, nunca arquivo).
///
/// Tudo aqui e valor puro e deterministico (sem AVFoundation, sem estado global),
/// para rodar identico no CI e no device e ser verificavel por teste unitario. As
/// structs guardam a fase/estado do gerador e sao mutadas UMA vez por amostra dentro
/// do bloco de render (thread de audio) - nunca pela main thread (guardrail 12.11).

// MARK: - Limites do binaural (PRD 5.2, obrigatorios)

enum BinauralLimits {
    /// Portadora entre 100 Hz e 500 Hz (percepcao do batimento degrada acima de ~1 kHz).
    static let carrierRange: ClosedRange<Double> = 100...500
    /// Batimento entre 0,5 Hz e 40 Hz (acima disso deixa de ser percebido como pulsacao).
    static let beatRange: ClosedRange<Double> = 0.5...40
    /// Amplitude por canal limitada a 0.5 do fundo de escala para nao clipar no somatorio.
    static let maxAmplitude: Double = 0.5

    static func clampCarrier(_ hz: Double) -> Double {
        min(max(hz, carrierRange.lowerBound), carrierRange.upperBound)
    }
    static func clampBeat(_ hz: Double) -> Double {
        min(max(hz, beatRange.lowerBound), beatRange.upperBound)
    }
}

// MARK: - Voz binaural (PRD 5.2)

/// Duas senoides puras, uma por canal: esquerda em `carrier`, direita em `carrier + beat`.
/// A diferenca de frequencia e o batimento binaural percebido. A frequencia e lida a cada
/// amostra, entao mudancas interpoladas pelo chamador nunca produzem degrau (PRD 5.2).
struct BinauralVoice {
    private var phaseL: Double = 0
    private var phaseR: Double = 0
    let sampleRate: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// Gera uma amostra estereo. `carrier`/`beat` ja devem vir dentro dos limites.
    mutating func render(carrier: Double, beat: Double, amplitude: Double) -> (left: Float, right: Float) {
        let left = Float(sin(phaseL) * amplitude)
        let right = Float(sin(phaseR) * amplitude)

        let twoPi = 2.0 * Double.pi
        phaseL += twoPi * carrier / sampleRate
        phaseR += twoPi * (carrier + beat) / sampleRate
        if phaseL >= twoPi { phaseL -= twoPi }
        if phaseR >= twoPi { phaseR -= twoPi }

        return (left, right)
    }
}

// MARK: - Ruido (PRD 5.4)

enum NoiseColor: String, Sendable, CaseIterable {
    case white
    case pink
    case brown
}

/// Gerador xorshift64 - PRNG rapido, deterministico (seed fixa) e sem alocacao, seguro
/// para a thread de audio. Deterministico tambem torna o teste reprodutivel.
struct XorShift64 {
    private var state: UInt64

    init(seed: UInt64) {
        // evita o estado degenerado 0
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Amostra uniforme em [-1, 1).
    mutating func nextUnit() -> Double {
        // 53 bits de mantissa -> [0,1), depois mapeia para [-1,1)
        let u = Double(next() >> 11) * (1.0 / 9007199254740992.0)
        return u * 2.0 - 1.0
    }
}

/// Gera ruido branco, rosa e marrom proceduralmente. Guarda o estado dos filtros
/// entre amostras; deve viver na thread de audio (uma instancia por no de render).
struct NoiseGenerator {
    private var rng: XorShift64

    // Ruido rosa - metodo de Paul Kellet (aproxima -3 dB/oitava com 7 polos).
    private var b0: Double = 0, b1: Double = 0, b2: Double = 0
    private var b3: Double = 0, b4: Double = 0, b5: Double = 0, b6: Double = 0

    // Ruido marrom - integrador com vazamento (controla a deriva de DC, PRD 5.4).
    private var brown: Double = 0
    private let brownLeak: Double = 0.02

    init(seed: UInt64 = 0xDEADBEEF) {
        rng = XorShift64(seed: seed)
    }

    /// Uma amostra da cor pedida, em [-1, 1].
    mutating func render(_ color: NoiseColor) -> Float {
        let white = rng.nextUnit()
        switch color {
        case .white:
            return Float(white)
        case .pink:
            b0 = 0.99886 * b0 + white * 0.0555179
            b1 = 0.99332 * b1 + white * 0.0750759
            b2 = 0.96900 * b2 + white * 0.1538520
            b3 = 0.86650 * b3 + white * 0.3104856
            b4 = 0.55000 * b4 + white * 0.5329522
            b5 = -0.7616 * b5 - white * 0.0168980
            let pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
            b6 = white * 0.115926
            return Float(min(max(pink, -1), 1))
        case .brown:
            // integrador com vazamento + tanh: limita a [-1,1] e mata a deriva de DC
            // sem introduzir clipping duro.
            brown = brown * (1 - brownLeak) + white * brownLeak
            return Float(tanh(brown * 8))
        }
    }
}

// MARK: - Rampa de fade (PRD 5.2: fade in/out de 300 ms para eliminar clique)

/// Suaviza o ganho de uma camada de 0..1 rumo a um alvo, em passo constante por amostra.
/// Uma transicao de 0 para 1 (ou vice-versa) leva `durationMs` (padrao 300 ms). Isso
/// remove clique em toda mudanca de estado e da o crossfade entre valores de volume.
struct LinearRamp {
    private(set) var current: Double
    private var target: Double
    private let step: Double

    init(sampleRate: Double, durationMs: Double = 300, initial: Double = 0) {
        current = initial
        target = initial
        step = 1.0 / (sampleRate * durationMs / 1000.0)
    }

    mutating func setTarget(_ value: Double) {
        target = min(max(value, 0), 1)
    }

    /// Avanca uma amostra rumo ao alvo e devolve o ganho atual.
    mutating func next() -> Double {
        if current < target {
            current = min(current + step, target)
        } else if current > target {
            current = max(current - step, target)
        }
        return current
    }
}
