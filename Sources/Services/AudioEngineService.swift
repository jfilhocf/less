import Foundation
import AVFoundation

/// Contrato do motor de audio (PRD 5; ADR-02, ADR-06).
///
/// A implementacao sintetiza ondas binaurais e ruido em tempo real via
/// `AVAudioSourceNode`, mixa ate 4 camadas com volume independente e configura a
/// `AVAudioSession` para tocar em background. O render NUNCA e feito pela main thread
/// (guardrail 12.11) e a sintese e sempre procedural, nunca arquivo (guardrail 12.5).
///
/// Ambientes por arquivo (PRD 5.5) ficam para a trilha de ambiente, quando houver os
/// `.m4a` licenciados: o grafo ja tem o lugar deles, mas nada e carregado por ora.
@MainActor
protocol AudioEngineService: Sendable {
    var isRunning: Bool { get }
    /// Aviso do PRD 5.7: binaural no alto-falante nao funciona (precisa dos dois ouvidos).
    var isOutputMono: Bool { get }

    func start() throws
    func stop()
    /// Substitui o conjunto de camadas ativas. Entradas e saidas fazem fade de 300 ms.
    func setLayers(_ layers: [AudioLayer])
    func setMasterVolume(_ volume: Double)
}

/// Implementacao sobre `AVAudioEngine`.
@MainActor
final class LiveAudioEngineService: AudioEngineService {
    private let engine = AVAudioEngine()
    private let renderer: AudioRenderer
    private var sourceNode: AVAudioSourceNode?
    private var parameters = AudioParameters()
    private var observers: [NSObjectProtocol] = []

    private(set) var isRunning = false

    init(sampleRate: Double = 44_100) {
        self.renderer = AudioRenderer(sampleRate: sampleRate)
    }

    /// `true` quando a saida atual nao tem separacao estereo util (alto-falante do aparelho).
    var isOutputMono: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { $0.portType == .builtInSpeaker }
    }

    // MARK: Ciclo de vida

    func start() throws {
        guard !isRunning else { return }

        try configureSession()
        buildGraphIfNeeded()
        observeSessionEvents()

        try engine.start()
        isRunning = true
        renderer.update(parameters)
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Camadas

    func setLayers(_ layers: [AudioLayer]) {
        parameters.layers = layers
        renderer.update(parameters)
    }

    func setMasterVolume(_ volume: Double) {
        parameters.masterVolume = min(max(volume, 0), 1)
        renderer.update(parameters)
    }

    // MARK: Grafo (PRD 5.1)

    private func buildGraphIfNeeded() {
        guard sourceNode == nil else { return }

        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.outputNode.outputFormat(forBus: 0).sampleRate,
            channels: 2
        )!

        // O bloco roda na thread de audio a cada bloco de amostras. Ele so repassa para o
        // renderer - toda a regra esta la, o que mantem isto minimo e auditavel.
        let node = AVAudioSourceNode(format: format) { [renderer] _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }

            renderer.render(frameCount: Int(frameCount), left: left, right: right)
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
    }

    // MARK: Sessao (PRD 5.6)

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // `.playback` e o que permite continuar com a tela apagada, junto do
        // UIBackgroundModes=audio ja declarado no project.yml.
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func observeSessionEvents() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        // `Notification` nao e `Sendable`, entao os valores sao extraidos AQUI e so os
        // `UInt` atravessam para a main actor. Mandar a notificacao inteira e erro de
        // compilacao sob strict concurrency - e com razao: e objeto de classe mutavel.

        // Chamada telefonica, alarme, outro app: pausa e so volta se o sistema permitir.
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(typeRaw: type, optionsRaw: options)
            }
        })

        // Fone removido: pausa. E o comportamento que o usuario espera - PRD 5.6.
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated { self?.handleRouteChange(reasonRaw: reason) }
        })
    }

    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
            return
        }

        switch type {
        case .began:
            engine.pause()
            isRunning = false
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            // So retoma se o sistema disser que pode - retomar por conta propria
            // atropelaria o app que interrompeu.
            if options.contains(.shouldResume) { try? start() }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonRaw: UInt?) {
        guard let reasonRaw,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }

        if reason == .oldDeviceUnavailable {
            engine.pause()
            isRunning = false
        }
    }
}
