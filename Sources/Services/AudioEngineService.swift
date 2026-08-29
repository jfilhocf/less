import Foundation

/// Contrato do motor de audio (PRD 5; ADR-02, ADR-06).
///
/// A implementacao concreta (Fase 1) sintetiza ondas binaurais e ruido em tempo
/// real via `AVAudioSourceNode`, toca ambientes por arquivo em loop com crossfade,
/// mixa ate 4 camadas com volume independente e e isolada num ator proprio - por
/// isso o protocolo e `Sendable`. O motor NUNCA e acessado da main thread em
/// operacoes de render (guardrail 12.11).
///
/// Metodos previstos para a Fase 1 (ainda nao declarados, para manter a Fase 0
/// compilando sem depender de AVFoundation):
/// - `start()` / `stop()` do grafo (5.1)
/// - camada binaural com `carrier`/`beat` interpolados dentro dos limites seguros (5.2)
/// - camadas de ruido branco / rosa / marrom, geradas proceduralmente (5.4)
/// - camadas de ambiente por arquivo, em loop com crossfade (5.5)
/// - volume por camada e volume master, com fade in/out de 300 ms (5.2)
/// - `AVAudioSession` `.playback` + tratamento de interrupcao e mudanca de rota (5.6)
protocol AudioEngineService: Sendable {
}
