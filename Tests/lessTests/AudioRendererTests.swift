import Testing
import Foundation
@testable import less

/// Testes da Fase 1: sintese procedural e mixagem.
///
/// O renderer gera amostras sem AVFoundation, entao da para **medir o sinal de verdade**
/// no CI - contar cruzamentos por zero para conferir a frequencia, medir o pico para
/// conferir o teto de amplitude, observar o ganho subindo para conferir o fade.
@Suite("AudioRenderer")
struct AudioRendererTests {
    let sampleRate = 44_100.0

    /// Renderiza `seconds` e devolve os dois canais.
    private func render(
        _ renderer: AudioRenderer,
        seconds: Double
    ) -> (left: [Float], right: [Float]) {
        let frames = Int(sampleRate * seconds)
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                renderer.render(frameCount: frames, left: l.baseAddress!, right: r.baseAddress!)
            }
        }
        return (left, right)
    }

    /// Frequencia estimada por cruzamentos por zero (dois cruzamentos = um ciclo).
    private func frequency(of samples: [Float], seconds: Double) -> Double {
        var crossings = 0
        for i in 1..<samples.count where (samples[i - 1] < 0) != (samples[i] < 0) {
            crossings += 1
        }
        return Double(crossings) / 2.0 / seconds
    }

    // MARK: Binaural (PRD 5.2)

    @Test("binaural poe frequencias diferentes em cada ouvido - a diferenca e o batimento")
    func binauralSeparatesChannels() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        renderer.update(AudioParameters(
            layers: [.binaural(carrier: 200, beat: 10)], masterVolume: 1
        ))

        // descarta o primeiro meio segundo (fade-in) e mede o regime estavel
        _ = render(renderer, seconds: 0.5)
        let (left, right) = render(renderer, seconds: 2)

        let fL = frequency(of: left, seconds: 2)
        let fR = frequency(of: right, seconds: 2)

        #expect(abs(fL - 200) < 2)
        #expect(abs(fR - 210) < 2)
        #expect(abs((fR - fL) - 10) < 1) // o batimento pedido
    }

    @Test("portadora e batimento fora dos limites sao presos na faixa segura")
    func clampsOutOfRangeFrequencies() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        // 2000 Hz e 200 Hz de batimento estao muito fora do PRD 5.2
        renderer.update(AudioParameters(layers: [.binaural(carrier: 2000, beat: 200)]))

        _ = render(renderer, seconds: 0.5)
        let (left, right) = render(renderer, seconds: 2)

        let fL = frequency(of: left, seconds: 2)
        let fR = frequency(of: right, seconds: 2)

        #expect(abs(fL - BinauralLimits.carrierRange.upperBound) < 3) // preso em 500
        #expect(abs((fR - fL) - BinauralLimits.beatRange.upperBound) < 2) // preso em 40
    }

    @Test("amplitude do binaural respeita o teto de 0.5 por canal")
    func binauralRespectsAmplitudeCeiling() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        renderer.update(AudioParameters(layers: [.binaural(carrier: 200, beat: 10)]))

        _ = render(renderer, seconds: 0.5)
        let (left, right) = render(renderer, seconds: 1)

        let peak = max(left.map { abs($0) }.max() ?? 0, right.map { abs($0) }.max() ?? 0)
        #expect(peak <= Float(BinauralLimits.maxAmplitude) + 0.01)
        #expect(peak > 0.4) // e de fato esta tocando, nao em silencio
    }

    // MARK: Fades (PRD 5.2)

    @Test("camada entra em fade, sem estalo: comeca em zero e sobe")
    func layerFadesIn() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        renderer.update(AudioParameters(layers: [.noise(.white)]))

        // 10 ms iniciais: o ganho mal saiu de zero (a rampa leva 300 ms)
        let (early, _) = render(renderer, seconds: 0.01)
        let earlyPeak = early.map { abs($0) }.max() ?? 0

        _ = render(renderer, seconds: 0.5)
        let (settled, _) = render(renderer, seconds: 0.5)
        let settledPeak = settled.map { abs($0) }.max() ?? 0

        #expect(earlyPeak < settledPeak / 3)
        #expect(settledPeak > 0.1)
    }

    @Test("camada removida sai em fade e depois silencia de vez")
    func layerFadesOut() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        renderer.update(AudioParameters(layers: [.noise(.white)]))
        _ = render(renderer, seconds: 1) // estabiliza

        renderer.update(AudioParameters(layers: []))
        _ = render(renderer, seconds: 0.5) // consome o fade de saida
        let (after, _) = render(renderer, seconds: 0.2)

        #expect((after.map { abs($0) }.max() ?? 0) == 0)
    }

    @Test("mudar so o batimento NAO refaz a camada - interpola em vez de dar fade")
    func changingBeatInterpolates() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        renderer.update(AudioParameters(layers: [.binaural(carrier: 200, beat: 6)]))
        _ = render(renderer, seconds: 1)

        renderer.update(AudioParameters(layers: [.binaural(carrier: 200, beat: 20)]))
        let (duringChange, _) = render(renderer, seconds: 0.05)

        // se tivesse recriado a voz, o ganho cairia a zero e voltaria (estalo audivel)
        #expect((duringChange.map { abs($0) }.max() ?? 0) > 0.3)
    }

    // MARK: Ruido (PRD 5.4)

    @Test("as tres cores de ruido geram sinal dentro de [-1, 1]")
    func noiseStaysInRange() {
        for color in NoiseColor.allCases {
            let renderer = AudioRenderer(sampleRate: sampleRate)
            renderer.update(AudioParameters(layers: [.noise(color)]))
            _ = render(renderer, seconds: 0.5)
            let (left, _) = render(renderer, seconds: 1)

            let peak = left.map { abs($0) }.max() ?? 0
            #expect(peak <= 1.0, "cor \(color.rawValue) estourou o fundo de escala")
            #expect(peak > 0.01, "cor \(color.rawValue) nao gerou sinal")
        }
    }

    @Test("ruido marrom tem mais energia grave que o branco")
    func brownIsDarkerThanWhite() {
        func averageStep(_ color: NoiseColor) -> Double {
            let renderer = AudioRenderer(sampleRate: sampleRate)
            renderer.update(AudioParameters(layers: [.noise(color)]))
            _ = render(renderer, seconds: 0.5)
            let (samples, _) = render(renderer, seconds: 1)
            // diferenca media entre amostras vizinhas = proxy de conteudo agudo
            var sum = 0.0
            for i in 1..<samples.count { sum += abs(Double(samples[i] - samples[i - 1])) }
            return sum / Double(samples.count - 1)
        }

        // marrom e integrado: varia devagar. branco pula a cada amostra.
        #expect(averageStep(.brown) < averageStep(.white))
    }

    // MARK: Mixagem (PRD 5.1)

    @Test("teto de 4 camadas - a quinta e descartada")
    func capsAtFourLayers() {
        let params = AudioParameters(layers: [
            .binaural(carrier: 200, beat: 10),
            .noise(.white), .noise(.pink), .noise(.brown),
            .binaural(carrier: 300, beat: 20),
        ])
        #expect(params.capped().layers.count == AudioParameters.maxLayers)
    }

    @Test("somatorio de varias camadas nao clipa")
    func mixDoesNotClip() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        renderer.update(AudioParameters(
            layers: [.binaural(carrier: 200, beat: 10), .noise(.white),
                     .noise(.pink), .noise(.brown)],
            masterVolume: 1
        ))
        _ = render(renderer, seconds: 0.5)
        let (left, right) = render(renderer, seconds: 1)

        let peak = max(left.map { abs($0) }.max() ?? 0, right.map { abs($0) }.max() ?? 0)
        #expect(peak < 1.0)
    }

    @Test("volume master em zero silencia tudo")
    func masterVolumeZeroSilences() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        renderer.update(AudioParameters(layers: [.noise(.white)], masterVolume: 1))
        _ = render(renderer, seconds: 1)

        renderer.update(AudioParameters(layers: [.noise(.white)], masterVolume: 0))
        _ = render(renderer, seconds: 0.5) // fade do master
        let (left, _) = render(renderer, seconds: 0.2)

        #expect((left.map { abs($0) }.max() ?? 0) == 0)
    }

    @Test("o limitador comprime e nunca ultrapassa o fundo de escala")
    func softClipNeverExceedsUnity() {
        #expect(AudioRenderer.softClip(0.5) == 0.5)    // abaixo do joelho, intocado
        #expect(AudioRenderer.softClip(-0.5) == -0.5)

        // comprime: a saida e muito menor que a entrada
        #expect(AudioRenderer.softClip(3.0) < 1.0)
        #expect(AudioRenderer.softClip(-3.0) > -1.0)

        // entrada absurda satura em 1.0 exato (limite de `tanh` em ponto flutuante) - o que
        // importa e nunca PASSAR de 1: acima disso a conversao para inteiro daria wraparound.
        for input in [1.0, 3.0, 50.0, 1000.0] {
            #expect(abs(AudioRenderer.softClip(input)) <= 1.0)
            #expect(abs(AudioRenderer.softClip(-input)) <= 1.0)
        }
    }

    @Test("sem camada nenhuma, o motor gera silencio digital")
    func noLayersMeansSilence() {
        let renderer = AudioRenderer(sampleRate: sampleRate)
        let (left, right) = render(renderer, seconds: 0.5)
        #expect((left.map { abs($0) }.max() ?? 0) == 0)
        #expect((right.map { abs($0) }.max() ?? 0) == 0)
    }

    // MARK: Determinismo

    @Test("mesma seed, mesmo sinal - render reprodutivel")
    func renderIsDeterministic() {
        func firstSamples() -> [Float] {
            let renderer = AudioRenderer(sampleRate: sampleRate)
            renderer.update(AudioParameters(layers: [.noise(.pink)]))
            return render(renderer, seconds: 0.1).left
        }
        #expect(firstSamples() == firstSamples())
    }
}
