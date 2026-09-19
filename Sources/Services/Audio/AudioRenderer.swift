import Foundation
import os

/// Uma camada do mix (PRD 5.1). Valor `Sendable`, para atravessar da interface ate a
/// thread de audio sem carregar objeto mutavel junto.
enum AudioLayer: Sendable, Equatable, Hashable {
    /// Duas senoides, uma por canal; a diferenca e o batimento percebido (PRD 5.2).
    case binaural(carrier: Double, beat: Double)
    /// Ruido procedural - nunca arquivo (guardrail 12.5).
    case noise(NoiseColor)

    /// Identidade que ignora os parametros: mudar o batimento de 6 para 10 Hz e a MESMA
    /// camada com outro valor (interpola), nao uma camada nova (que faria fade).
    var identity: String {
        switch self {
        case .binaural:        return "binaural"
        case .noise(let cor):  return "noise.\(cor.rawValue)"
        }
    }
}

/// O que a interface pede ao motor. Trafega inteiro, de uma vez, para o render nunca
/// pegar um estado meio atualizado.
struct AudioParameters: Sendable, Equatable {
    var layers: [AudioLayer] = []
    var masterVolume: Double = 1.0

    /// Maximo de camadas simultaneas (PRD 5.1: preservar bateria e CPU).
    static let maxLayers = 4

    /// Aplica o teto de camadas descartando o excedente.
    func capped() -> AudioParameters {
        guard layers.count > Self.maxLayers else { return self }
        var copy = self
        copy.layers = Array(layers.prefix(Self.maxLayers))
        return copy
    }
}

/// Gera as amostras do mix.
///
/// **Vive na thread de audio.** Nada aqui aloca, trava ou chama Foundation no caminho
/// quente - sao as regras de um render callback, e violar qualquer uma vira glitch audivel
/// (guardrail 12.11). Por isso:
/// - os parametros chegam por `update(_:)` (thread da interface) e sao lidos no render com
///   `withLockIfAvailable`: se a trava estiver ocupada naquele instante, o render segue com
///   os parametros anteriores em vez de esperar. Um bloco de atraso e inaudivel; um bloco
///   perdido, nao;
/// - camada que entra sobe de 0 a 1 em 300 ms e camada que sai desce a 0 antes de sumir,
///   entao nenhuma mudanca produz clique (PRD 5.2);
/// - a frequencia e interpolada por amostra, nunca aplicada em degrau (PRD 5.2).
///
/// E uma classe comum (nao ator) de proposito: `render` e chamado de forma sincrona pelo
/// `AVAudioSourceNode` e nao pode suspender.
final class AudioRenderer: @unchecked Sendable {
    private let sampleRate: Double
    private let pending: OSAllocatedUnfairLock<AudioParameters>

    /// Estado dos geradores - tocado SO pelo render.
    private var voices: [String: Voice] = [:]
    private var master: LinearRamp
    private var appliedLayers: [AudioLayer] = []

    private struct Voice {
        var layer: AudioLayer
        var gain: LinearRamp
        var binaural: BinauralVoice
        var noise: NoiseGenerator
        var carrier: ValueRamp
        var beat: ValueRamp
        /// Saindo: quando o ganho chegar a zero, a voz e removida.
        var isRetiring = false
    }

    init(sampleRate: Double = 44_100) {
        self.sampleRate = sampleRate
        self.pending = OSAllocatedUnfairLock(initialState: AudioParameters())
        self.master = LinearRamp(sampleRate: sampleRate, initial: 0)
    }

    /// Chamado pela interface. Nunca bloqueia o render por mais que um instante.
    func update(_ parameters: AudioParameters) {
        pending.withLock { $0 = parameters.capped() }
    }

    /// Preenche `frameCount` amostras em cada canal.
    func render(frameCount: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        // Tentativa sem espera: se a interface estiver escrevendo agora, usa o estado anterior.
        if let params = pending.withLockIfAvailable({ $0 }) {
            apply(params)
        }

        for frame in 0..<frameCount {
            var mixL = 0.0
            var mixR = 0.0

            for key in voices.keys {
                guard var voice = voices[key] else { continue }
                let gain = voice.gain.next()

                switch voice.layer {
                case .binaural:
                    let carrier = voice.carrier.next()
                    let beat = voice.beat.next()
                    let sample = voice.binaural.render(
                        carrier: carrier,
                        beat: beat,
                        amplitude: BinauralLimits.maxAmplitude * gain
                    )
                    mixL += Double(sample.left)
                    mixR += Double(sample.right)

                case .noise(let cor):
                    let sample = Double(voice.noise.render(cor)) * gain
                    mixL += sample
                    mixR += sample
                }

                // voz que terminou o fade de saida some do mix
                if voice.isRetiring && voice.gain.current <= 0 {
                    voices.removeValue(forKey: key)
                } else {
                    voices[key] = voice
                }
            }

            let masterGain = master.next()
            left[frame] = Float(Self.softClip(mixL * masterGain))
            right[frame] = Float(Self.softClip(mixR * masterGain))
        }
    }

    // MARK: Interno

    private func apply(_ params: AudioParameters) {
        master.setTarget(params.masterVolume)

        guard params.layers != appliedLayers else { return }
        appliedLayers = params.layers

        let wanted = Set(params.layers.map(\.identity))

        // camadas que sairam: fade de saida, nunca corte seco
        for (key, var voice) in voices where !wanted.contains(key) {
            voice.isRetiring = true
            voice.gain.setTarget(0)
            voices[key] = voice
        }

        for layer in params.layers {
            let key = layer.identity
            if var existing = voices[key] {
                // mesma camada, parametro novo: INTERPOLA, nao recria (senao haveria clique)
                existing.isRetiring = false
                existing.gain.setTarget(1)
                existing.layer = layer
                if case .binaural(let carrier, let beat) = layer {
                    existing.carrier.setTarget(BinauralLimits.clampCarrier(carrier))
                    existing.beat.setTarget(BinauralLimits.clampBeat(beat))
                }
                voices[key] = existing
            } else {
                voices[key] = makeVoice(for: layer)
            }
        }
    }

    private func makeVoice(for layer: AudioLayer) -> Voice {
        var gain = LinearRamp(sampleRate: sampleRate, initial: 0)
        gain.setTarget(1) // entra em fade-in de 300 ms

        var carrier = ValueRamp(sampleRate: sampleRate, initial: 0, span: 400)
        var beat = ValueRamp(sampleRate: sampleRate, initial: 0, span: 40)
        if case .binaural(let c, let b) = layer {
            // primeira configuracao: nada a suavizar, ja comeca no valor certo
            carrier.snap(to: BinauralLimits.clampCarrier(c))
            beat.snap(to: BinauralLimits.clampBeat(b))
        }

        // Seed por camada mantem o ruido deterministico e reprodutivel em teste, sem
        // duas camadas de ruido saindo identicas.
        let seed = UInt64(abs(layer.identity.hashValue)) | 1

        return Voice(
            layer: layer,
            gain: gain,
            binaural: BinauralVoice(sampleRate: sampleRate),
            noise: NoiseGenerator(seed: seed),
            carrier: carrier,
            beat: beat
        )
    }

    /// Compressao suave acima de 0.7. Com ate 4 camadas somadas o pico pode passar de 1;
    /// cortar seco geraria distorcao audivel, entao comprime o excedente e garante |y| < 1.
    static func softClip(_ x: Double) -> Double {
        let knee = 0.7
        guard abs(x) > knee else { return x }
        let sign: Double = x < 0 ? -1 : 1
        let over = abs(x) - knee
        return sign * (knee + (1 - knee) * tanh(over / (1 - knee)))
    }
}
