# PRD e Plano de Arquitetura: App de Foco (iOS)

> Documento de especificação para execução assistida por agente de código.
> Versão 1.0. Data: 29/08/2026.
> Leia este arquivo por completo antes de escrever qualquer linha de código.

---

## 0. Como usar este documento

Este arquivo é a fonte de verdade do produto. Regras de uso pelo agente:

1. Nenhuma funcionalidade fora do escopo definido na seção 2 deve ser implementada sem autorização explícita.
2. As decisões de arquitetura da seção 3 são fechadas. Se você discordar de alguma, pare e apresente o contra-argumento antes de implementar diferente.
3. Os guardrails da seção 12 são restrições rígidas. Violá-los é falha de execução, mesmo que o código funcione.
4. Implemente por fases (seção 11). Não avance de fase sem cumprir os critérios de aceite da fase anterior.

---

## 1. Contexto e objetivo

### 1.1 Problema

Trabalho e estudo em blocos de concentração exigem duas coisas que hoje estão espalhadas em apps diferentes: um ambiente sonoro que sustente o foco e uma estrutura de tempo que force pausas. Os apps existentes na categoria resolvem uma das duas e carregam excesso de interface, gamificação e assinatura agressiva.

### 1.2 Proposta

Um app iOS único que combina player de áudio de foco (ondas binaurais + ruídos + ambientes naturais) com timer Pomodoro, em interface deliberadamente reduzida. O áudio e o ciclo de tempo são integrados: iniciar o Pomodoro inicia o som, a pausa muda o estado sonoro.

### 1.3 Princípios de produto

- **Silêncio visual.** Cada elemento na tela precisa justificar sua existência. Na dúvida, remova.
- **Zero fricção de entrada.** O app abre e toca. Sem onboarding obrigatório, sem conta, sem tutorial.
- **Honestidade sobre o efeito.** Nenhuma promessa terapêutica. Ver seção 10.
- **Privacidade por ausência.** O app não coleta dado porque não precisa de dado.

### 1.4 Plataforma

iOS apenas. iPhone. iOS 17.0 como target mínimo (necessário para SwiftData e `@Observable`). iPad e watchOS ficam fora do V1.

### 1.5 Métricas de sucesso

| Métrica | Definição | Meta V1 |
|---|---|---|
| D7 retention | % de usuários que abrem o app 7 dias após instalar | > 20% |
| Minutos por sessão ativa | Mediana de minutos de áudio por sessão | > 25 min |
| Ciclos Pomodoro completos | % de ciclos iniciados que chegam ao fim | > 60% |
| Crash-free sessions | Métrica do App Store Connect | > 99,5% |

Download não é métrica de sucesso e não deve ser tratado como tal.

---

## 2. Escopo

### 2.1 Dentro do V1

1. **Player de ondas binaurais** por faixa (delta, teta, alfa, beta, gama), com frequência portadora e frequência de batimento explícitas e ajustáveis dentro de limites seguros.
2. **Player de ruído** gerado proceduralmente: branco, rosa e marrom.
3. **Player de ambientes** a partir de arquivos licenciados: chuva, fogueira, cachoeira, pássaros/jardim.
4. **Mixagem simultânea** de até 4 camadas com volume independente por camada.
5. **Mixes salvos** pelo usuário (nome + composição de camadas + volumes).
6. **Timer Pomodoro** configurável: duração de foco, pausa curta, pausa longa, número de ciclos até a pausa longa, autostart do próximo bloco.
7. **Integração áudio + timer**: o áudio segue o estado do ciclo.
8. **Reprodução em background** com controles na tela de bloqueio, Central de Controle e fones.
9. **Detecção de rota de saída** com aviso quando o binaural estiver tocando sem fone estéreo.
10. **Histórico de sessões** local e estatística simples (minutos por dia, ciclos completos, sequência de dias).
11. **Timer de sono** (encerrar áudio após X minutos com fade out).

### 2.2 Fora do V1 (não implementar)

- Conta de usuário, login, cadastro
- Backend, API própria, banco remoto
- Sincronização entre dispositivos
- Compras dentro do app e paywall
- SDK de analytics de terceiros
- Widgets, Live Activity, App Intents, atalhos
- watchOS, iPad, macOS
- Integração com HealthKit, Apple Music ou Spotify
- Qualquer funcionalidade social, ranking ou compartilhamento

### 2.3 Preparado, mas não ativado

O modelo de dados deve conter o campo `isPremium` em `SoundPreset` desde o início, sempre com valor `false` no V1. Isso evita migração de schema quando a monetização for introduzida. Não implemente nenhuma lógica de paywall.

---

## 3. Decisões de arquitetura (fechadas)

### ADR-01: Local-first, sem backend

**Decisão:** o app roda 100% no dispositivo. Não haverá servidor, API ou banco remoto no V1.

**Justificativa:** todo o estado do produto (catálogo de sons, configurações, histórico) é pequeno, pessoal e não precisa ser compartilhado. Um backend adicionaria custo recorrente, superfície de ataque, latência, dependência de conectividade e obrigações de LGPD, sem entregar nenhum valor correspondente ao usuário.

**Consequência:** o catálogo de sons é definido em código ou em um JSON embarcado no bundle, versionado junto com o app.

### ADR-02: Áudio binaural e ruído gerados proceduralmente

**Decisão:** ondas binaurais e ruídos (branco, rosa, marrom) são sintetizados em tempo real via `AVAudioSourceNode`. Não usar arquivos de áudio para esses tipos.

**Justificativa:** senoides e ruído são matematicamente triviais de gerar. Isso elimina megabytes de bundle, remove o problema de emenda de loop, permite duração infinita e permite mudar frequência em tempo real sem recarregar arquivo.

**Consequência:** apenas os ambientes naturais (chuva, fogueira, cachoeira, pássaros) usam arquivos.

### ADR-03: Persistência com SwiftData

**Decisão:** SwiftData para todo o estado persistente. Sem Core Data direto, sem Realm, sem SQLite manual.

**Justificativa:** volume de dados baixo, modelo simples, integração nativa com SwiftUI e `@Observable`, menor superfície de código.

### ADR-04: Arquitetura MVVM com serviços injetados

**Decisão:** SwiftUI + `@Observable` (framework Observation) + MVVM leve. Serviços (`AudioEngineService`, `TimerService`, `PersistenceService`, `NotificationService`) são protocolos com implementação concreta, injetados via ambiente.

**Justificativa:** TCA ou arquiteturas com redutor seriam desproporcionais ao escopo. MVVM com protocolos entrega testabilidade suficiente sem sobrecarga estrutural.

### ADR-05: Timer ancorado em timestamp, não em contagem

**Decisão:** o `TimerService` calcula o tempo restante a partir de um instante absoluto de referência (`Date` para persistência, `ContinuousClock` para precisão em sessão). Um `Timer` ou `TimelineView` serve apenas para atualizar a interface.

**Justificativa:** o iOS suspende timers quando o app vai para background sem áudio ativo. Contagem incremental deriva e produz o bug clássico de "o Pomodoro parou enquanto eu estava no WhatsApp".

**Consequência:** transições de ciclo em background são garantidas por notificações locais agendadas, não pelo tick do timer.

### ADR-06: Swift 6 com concorrência estrita

**Decisão:** Swift 6 language mode, strict concurrency habilitado. O `AudioEngineService` é isolado em um ator próprio. Nunca acessar o motor de áudio da thread principal em operações de render.

---

## 4. Stack técnica

| Camada | Escolha |
|---|---|
| Linguagem | Swift 6 |
| UI | SwiftUI + Observation |
| Áudio | AVFoundation, AVAudioEngine, AVAudioSession |
| Controles externos | MediaPlayer (MPNowPlayingInfoCenter, MPRemoteCommandCenter) |
| Persistência | SwiftData |
| Notificações | UserNotifications |
| Testes | Swift Testing (não XCTest) |
| Dependências externas | Nenhuma |

**Regra de dependência:** zero pacotes de terceiros no V1. Se você acreditar que alguma dependência é indispensável, pare e justifique antes de adicionar.

---

## 5. Especificação do motor de áudio

### 5.1 Grafo do AVAudioEngine

```
[BinauralSourceNode]  --> pan L (-1.0) --\
                                          >--> [BinauralMixer] --\
[BinauralSourceNode]  --> pan R (+1.0) --/                        \
                                                                   >--> [MainMixer] --> [Output]
[NoiseSourceNode]     --> volume ------------------------------->  /
                                                                  /
[AmbiencePlayerNode 1] --> volume ----------------------------->  /
[AmbiencePlayerNode 2] --> volume ----------------------------->  /
```

- Cada camada tem controle de volume independente (0.0 a 1.0).
- O `MainMixer` aplica o volume master e o fade global.
- Máximo de 4 camadas ativas simultâneas para preservar bateria e CPU.

### 5.2 Geração de ondas binaurais

Duas senoides puras, uma em cada canal:

- Canal esquerdo: frequência `carrier`
- Canal direito: frequência `carrier + beat`
- O batimento percebido corresponde à diferença entre as duas frequências

**Restrições técnicas obrigatórias:**

- Frequência portadora entre 100 Hz e 500 Hz. A percepção do batimento binaural é mais consistente com portadoras baixas e degrada acima de aproximadamente 1000 Hz.
- Frequência de batimento entre 0,5 Hz e 40 Hz. Acima disso o batimento deixa de ser percebido como pulsação.
- Aplicar fade in e fade out de 300 ms em toda mudança de estado, para eliminar clique.
- Mudança de frequência em tempo real deve ser interpolada, nunca aplicada em degrau.
- Amplitude limitada a 0.5 do fundo de escala por canal para evitar clipping no somatório das camadas.

### 5.3 Catálogo de frequências

| Faixa | Batimento (Hz) | Portadora sugerida | Rótulo permitido na interface |
|---|---|---|---|
| Delta | 0,5 a 4 | 100 Hz | Repouso profundo |
| Teta | 4 a 8 | 150 Hz | Estados de relaxamento profundo e criatividade |
| Alfa | 8 a 13 | 200 Hz | Relaxamento alerta |
| Beta | 13 a 30 | 250 Hz | Estado de vigília e atenção sustentada |
| Gama | 30 a 40 | 300 Hz | Atenção intensa |

Presets iniciais sugeridos: Delta 2 Hz, Teta 6 Hz, Alfa 10 Hz, Beta 18 Hz, Gama 40 Hz.

A coluna de rótulos é descritiva do estado cerebral associado na literatura, não da promessa de efeito. Ver seção 10.2 para as regras de redação.

### 5.4 Geração de ruído

- **Branco:** ruído uniforme, densidade espectral plana.
- **Rosa:** filtro que atenua 3 dB por oitava. Implementar por filtro Voss-McCartney ou IIR de baixa ordem.
- **Marrom:** integração do ruído branco com controle de deriva de DC.

Todos gerados em `AVAudioSourceNode`. Nenhum arquivo.

### 5.5 Ambientes por arquivo

- Formato: AAC em contêiner `.m4a`, 44,1 kHz, estéreo, 128 a 160 kbps.
- Duração do loop: 30 a 60 segundos.
- Corte obrigatório em zero-crossing com crossfade de 500 ms a 1 s para eliminar emenda audível.
- Meta de tamanho total do bundle de áudio: abaixo de 150 MB. Se ultrapassar, migrar para On-Demand Resources da Apple.

### 5.6 Sessão de áudio e background

Configuração obrigatória:

- `Info.plist`: `UIBackgroundModes` com o valor `audio`.
- `AVAudioSession` categoria `.playback`, modo `.default`.
- Tratar interrupções (`AVAudioSession.interruptionNotification`): pausar em chamada, retomar quando permitido.
- Tratar mudança de rota (`routeChangeNotification`): pausar quando o fone for removido, comportamento padrão esperado pelo usuário.
- Popular `MPNowPlayingInfoCenter` com título do mix, estado e tempo decorrido.
- Registrar comandos em `MPRemoteCommandCenter`: play, pause, toggle.

### 5.7 Detecção de fone

Ondas binaurais dependem de separação estéreo entre os ouvidos. Quando a rota de saída for alto-falante e houver camada binaural ativa, exibir aviso persistente e discreto na interface do player: "Ondas binaurais precisam de fones de ouvido". Não bloquear a reprodução, apenas informar.

---

## 6. Especificação do timer Pomodoro

### 6.1 Máquina de estados

```
idle -> focusing -> shortBreak -> focusing -> ... -> longBreak -> idle|focusing
         |                |                              |
         v                v                              v
      paused           paused                        paused
```

Regras:

- Após N blocos de foco (N configurável, padrão 4), a pausa é longa.
- `autostart` define se o próximo estado inicia automaticamente ou aguarda ação.
- Pausar preserva o tempo restante. Retomar recalcula o instante-alvo.

### 6.2 Configuração padrão

| Parâmetro | Padrão | Faixa permitida |
|---|---|---|
| Foco | 25 min | 5 a 120 min |
| Pausa curta | 5 min | 1 a 30 min |
| Pausa longa | 15 min | 5 a 60 min |
| Ciclos até pausa longa | 4 | 2 a 8 |
| Autostart | desligado | booleano |

### 6.3 Correção em background

Esta é a parte que mais falha em implementações desse tipo. Requisitos:

1. Persistir `targetDate` (instante absoluto do fim do bloco atual) em cada transição de estado.
2. Ao voltar para foreground, recalcular o estado a partir de `Date.now` comparado ao `targetDate` persistido, incluindo o caso de múltiplas transições perdidas.
3. Agendar notificação local para cada transição prevista, com o gatilho no instante-alvo.
4. Cancelar notificações pendentes ao pausar, resetar ou reconfigurar.
5. Se o áudio estiver tocando, o processo permanece vivo e a transição ocorre em tempo real. Se não estiver, a notificação é o único mecanismo confiável.

### 6.4 Comportamento sonoro por estado

- **focusing:** mix selecionado toca normalmente.
- **shortBreak / longBreak:** por padrão o áudio faz fade out. Configurável para manter tocando ou trocar para um mix de pausa.
- **Transição:** sinal sonoro curto e discreto, além de haptic (`UINotificationFeedbackGenerator`).

---

## 7. Modelo de dados (SwiftData)

```swift
@Model final class SoundPreset {
    var id: UUID
    var kind: SoundKind          // .binaural, .noise, .ambience
    var name: String
    var descriptionText: String
    var carrierHz: Double?       // apenas .binaural
    var beatHz: Double?          // apenas .binaural
    var noiseColor: NoiseColor?  // apenas .noise
    var fileName: String?        // apenas .ambience
    var category: String
    var isPremium: Bool          // sempre false no V1
    var sortOrder: Int
}

@Model final class Mix {
    var id: UUID
    var name: String
    var layers: [MixLayer]       // relação
    var createdAt: Date
    var lastUsedAt: Date?
    var isFavorite: Bool
}

@Model final class MixLayer {
    var id: UUID
    var presetID: UUID
    var volume: Double           // 0.0 a 1.0
    var mix: Mix?                // relação inversa
}

@Model final class PomodoroConfig {
    var id: UUID
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var cyclesUntilLongBreak: Int
    var autostartEnabled: Bool
    var soundDuringBreak: Bool
}

@Model final class FocusSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var effectiveSeconds: Int
    var mixID: UUID?
    var completedCycles: Int
    var wasInterrupted: Bool
}

@Model final class AppSettings {
    var id: UUID
    var masterVolume: Double
    var hapticsEnabled: Bool
    var headphoneWarningEnabled: Bool
    var sleepTimerMinutes: Int?
    var appearance: String       // system, light, dark
}
```

**Regras de modelagem:**

- Estatísticas (minutos por dia, sequência de dias, total acumulado) são **derivadas em runtime** a partir de `FocusSession`. Não criar entidade de agregado nem persistir contador.
- `SoundPreset` do catálogo padrão é semeado no primeiro launch a partir de um JSON no bundle. Usuário não edita preset padrão, apenas cria `Mix`.
- `AppSettings` e `PomodoroConfig` são singletons: garantir instância única na inicialização.

---

## 8. Fluxo de telas

### 8.1 Estrutura de navegação

Três telas no total. Sem tab bar aninhada, sem menu hambúrguer.

```
[Player]  <->  [Biblioteca]  <->  [Ajustes]
```

Navegação por `TabView` com três itens ou por gesto horizontal. O Player é a tela inicial.

### 8.2 Player (tela principal)

Elementos, em ordem de hierarquia visual:

1. Tempo restante do bloco atual, em tipografia grande. Se o Pomodoro estiver ocioso, mostra o tempo decorrido da sessão de áudio.
2. Indicador de estado (foco, pausa curta, pausa longa) discreto.
3. Indicador de progresso dos ciclos (pontos, não barra).
4. Botão primário único: iniciar / pausar.
5. Camadas ativas com controle de volume, colapsáveis.
6. Acesso à biblioteca.

Nada mais. Sem banner, sem card promocional, sem dica do dia.

### 8.3 Biblioteca

Lista agrupada por tipo: Binaural, Ruídos, Ambientes, Meus mixes.

Cada item binaural mostra nome, faixa, valor em Hz e a descrição curta. Toque adiciona à mixagem ativa. Toque longo abre detalhe com o controle de frequência.

### 8.4 Ajustes

Configuração do Pomodoro, volume master, aparência, haptics, timer de sono, aviso de fone, sobre o app, política de privacidade, créditos de áudio.

### 8.5 Diretrizes visuais

- Paleta reduzida: fundo escuro por padrão, um acento único, tipografia em dois pesos.
- Suportar Dynamic Type até `accessibility3` sem quebra de layout.
- Suportar Reduce Motion. Nenhuma animação essencial à compreensão.
- Contraste mínimo AA (4.5:1) em todo texto.
- VoiceOver em todos os controles, com rótulos descritivos, incluindo os sliders de volume.

---

## 9. Requisitos não funcionais

| Requisito | Alvo |
|---|---|
| Tempo até primeiro som | < 1,5 s do launch a frio |
| Consumo de CPU em reprodução | < 8% em iPhone 12 |
| Consumo de bateria | < 3% por hora de reprodução em tela apagada |
| Latência de resposta da UI | < 100 ms em qualquer toque |
| Tamanho do app | < 200 MB |
| Estabilidade do áudio | Zero glitch, clique ou dropout em 60 min de reprodução contínua |

---

## 10. Conformidade com a App Store

### 10.1 Requisitos obrigatórios

1. **Privacy manifest.** Incluir `PrivacyInfo.xcprivacy` no target do app. Desde 1º de maio de 2024 o App Store Connect rejeita builds que não declaram o uso de "required reason APIs". `UserDefaults` está nessa lista e será usado. Declarar `NSPrivacyAccessedAPICategoryUserDefaults` com o código de motivo apropriado.
2. **Privacy nutrition label.** Declarar coleta zero, o que é verdade neste projeto.
3. **Política de privacidade.** Página pública obrigatória, mesmo sem coleta.
4. **Créditos de áudio.** Tela de créditos listando origem e licença de cada arquivo de ambiente.

### 10.2 Regras de redação (crítico)

A diretriz 1.4.1 da App Store exige que apps divulguem dados e metodologia para sustentar alegações relacionadas a medições de saúde, e determina rejeição quando isso não pode ser validado. A evidência científica sobre ondas binaurais é modesta e inconsistente entre estudos. Portanto:

**Proibido em qualquer texto do app, da App Store ou de material de divulgação:**

- "trata", "cura", "reduz ansiedade", "melhora TDAH", "aumenta o QI"
- "cientificamente comprovado", "clinicamente testado"
- Qualquer verbo que prometa resultado individual
- Qualquer menção a condição médica ou diagnóstico

**Permitido:**

- "associado a", "comumente relacionado a", "muitas pessoas usam para"
- Descrição factual da faixa de frequência e do fenômeno acústico
- Menção a estados cerebrais como categoria descritiva (alfa, beta, teta)

**Obrigatório:** aviso na tela de detalhe do binaural e na tela "Sobre", com texto no seguinte espírito: "Este app é uma ferramenta de bem-estar e produtividade, não um dispositivo médico. Os efeitos das ondas binaurais variam entre pessoas e a evidência científica é limitada. Consulte um profissional de saúde antes de usar se você tem epilepsia, usa marca-passo ou tem alguma condição neurológica."

### 10.3 Licenciamento de áudio

Nenhum arquivo de áudio entra no repositório sem registro correspondente em `ASSETS_LICENSES.md`, contendo: nome do arquivo, fonte, autor, tipo de licença, link e data de aquisição.

**Licenças aceitáveis:** CC0, licença comercial paga (Artlist, Epidemic Sound, Soundstripe), gravação própria.

**Licenças a evitar:** CC-BY (exige atribuição visível e cria dependência), CC-NC (impede monetização futura).

---

## 11. Roadmap de execução por fases

### Fase 0: Fundação

**Entrega:** projeto Xcode configurado e compilando.

- Projeto SwiftUI, iOS 17.0, Swift 6 com strict concurrency
- Estrutura de pastas: `App/`, `Features/`, `Services/`, `Models/`, `Resources/`
- `Info.plist` com `UIBackgroundModes: audio`
- `PrivacyInfo.xcprivacy` criado
- Protocolos dos serviços definidos, sem implementação

**Critério de aceite:** o app compila, abre e mostra uma tela vazia. `swift build` sem warning de concorrência.

### Fase 1: Motor de áudio

**Entrega:** geração de som funcionando, sem interface definitiva.

- `AudioEngineService` com o grafo da seção 5.1
- Geração binaural com controle de portadora e batimento
- Geração de ruído branco, rosa e marrom
- Reprodução de arquivo de ambiente em loop com crossfade
- Mixagem de até 4 camadas com volume independente
- Fade in e fade out de 300 ms
- Configuração de `AVAudioSession` e background mode
- Tratamento de interrupção e mudança de rota

**Critério de aceite:** tela de teste com sliders que gera binaural de 10 Hz, mistura com chuva, toca por 30 minutos em background sem glitch, e responde ao botão do fone.

### Fase 2: Persistência e catálogo

**Entrega:** dados modelados e catálogo semeado.

- Todos os `@Model` da seção 7
- Seed do catálogo padrão a partir de JSON no bundle
- CRUD de `Mix`
- Singletons de `AppSettings` e `PomodoroConfig`

**Critério de aceite:** criar um mix, fechar o app, reabrir e o mix persiste com os volumes corretos.

### Fase 3: Timer Pomodoro

**Entrega:** ciclo Pomodoro correto e confiável.

- `TimerService` ancorado em timestamp
- Máquina de estados da seção 6.1
- Notificações locais para transições
- Recuperação de estado ao voltar do background, incluindo transições perdidas
- Integração com o áudio por estado
- Registro de `FocusSession`

**Critério de aceite:** iniciar bloco de 25 min, matar o app, esperar 30 min, reabrir e o app reconhece que o bloco terminou e a pausa começou. Notificação disparou no instante correto.

### Fase 4: Interface

**Entrega:** as três telas da seção 8, funcionais e acessíveis.

- Player, Biblioteca e Ajustes
- Controles na tela de bloqueio via `MPNowPlayingInfoCenter`
- Aviso de fone
- Timer de sono
- Estatísticas derivadas

**Critério de aceite:** navegação completa por VoiceOver. Dynamic Type em `accessibility3` sem sobreposição. Reduce Motion respeitado.

### Fase 5: Polimento e submissão

- Ícone e tela de launch
- Textos revisados contra as regras da seção 10.2
- `ASSETS_LICENSES.md` completo
- Política de privacidade publicada
- Screenshots e ficha da App Store
- Build no TestFlight

**Critério de aceite:** build aceito pelo App Store Connect sem erro de privacy manifest.

---

## 12. Guardrails para o agente

Restrições rígidas. Não contorne nenhuma delas por conveniência de implementação.

1. **Não crie backend, API, banco remoto ou qualquer chamada de rede.** O app é offline por definição.
2. **Não adicione dependência de terceiros.** Se achar indispensável, pare e justifique.
3. **Não adicione SDK de analytics, crash reporting de terceiros ou qualquer telemetria.**
4. **Não use `Timer` ou contagem incremental para controlar o Pomodoro.** Apenas timestamp absoluto.
5. **Não gere arquivos de áudio para binaural ou ruído.** Síntese procedural apenas.
6. **Não escreva copy com alegação de saúde.** Consulte a seção 10.2 antes de escrever qualquer texto visível.
7. **Não adicione arquivo de áudio ao projeto sem o registro correspondente em `ASSETS_LICENSES.md`.**
8. **Não implemente paywall, compra ou lógica de assinatura.**
9. **Não adicione gamificação, conquistas, badges, streaks visuais agressivas ou notificação de engajamento.** A única notificação permitida é a transição de ciclo do Pomodoro.
10. **Não aumente o escopo.** Se identificar uma oportunidade de melhoria fora do escopo, anote em `BACKLOG.md` e siga em frente.
11. **Não acesse o motor de áudio a partir da main thread em operações de render.**
12. **Não persista dado que possa ser derivado.**

---

## 13. Definition of Done

Uma fase só está concluída quando:

- [ ] Compila sem warning em Swift 6 strict concurrency
- [ ] Os critérios de aceite da fase foram verificados manualmente em dispositivo físico
- [ ] Testes unitários existem para a lógica do `TimerService` e para o cálculo de estatísticas
- [ ] Nenhum guardrail da seção 12 foi violado
- [ ] `STATUS.md` foi atualizado com o que foi feito, o que ficou pendente e as decisões tomadas

---

## 14. Decisões pendentes do João

Itens que o agente **não deve decidir sozinho**. Pergunte antes de implementar:

1. Nome do app e bundle identifier.
2. Paleta de cores e acento único.
3. Fonte dos arquivos de ambiente: comprar licença, usar CC0 ou gravar.
4. Se o app terá modo claro ou será dark-only.
5. Idiomas na v1: apenas português ou português e inglês.
6. Definição do tier gratuito permanente, para não haver paywall retroativo no futuro.

---

## 15. Referências

- Apple. *App Review Guidelines*, seção 1.4.1 (Safety, Physical Harm). https://developer.apple.com/app-store/review/guidelines/
- Apple. *Privacy manifest files* e *Describing use of required reason API*. Obrigatório no App Store Connect desde 01/05/2024.
- Garcia-Argibay, M., Santed, M. A., Reales, J. M. (2019). *Efficacy of binaural auditory beats in cognition, anxiety, and pain perception: a meta-analysis*. Psychological Research, 83(2), 357-372. doi:10.1007/s00426-018-1066-8. Efeito geral g = 0,45 sobre memória, atenção, ansiedade e dor.
- Basu, S., Banerjee, B. (2023). *Potential of binaural beats intervention for improving memory and attention: insights from meta-analysis and systematic review*. Psychological Research, 87, 951-963. doi:10.1007/s00426-022-01706-7. Resultados mistos nos domínios de atenção e memória.
- Oster, G. (1973). *Auditory beats in the brain*. Scientific American, 229(4), 94-102. Base do limite de percepção por frequência portadora.

---

## 16. Adendo (2026-09-14): Tarefas do dia + Pomodoro por preset

Mudança de escopo **autorizada pelo João** (dono do produto). Prioriza o núcleo de
produtividade antes da trilha de áudio (que passa a vir depois). Adiciona uma lista de
tarefas ao less e simplifica o Pomodoro para dois presets fixos.

### 16.1 Lista de tarefas do dia
- **Teto de 3 tarefas por dia.** Restrição deliberada, alinhada ao princípio "less" (não é
  limitação técnica). Concluir uma tarefa **não** devolve a vaga - as 3 são o compromisso do dia.
- **Rolagem que ocupa vaga.** Tarefa não concluída rola para o dia seguinte e ocupa uma das
  3 vagas (ex.: 1 rolada + 2 novas). A rolagem nunca descarta tarefa; se houver mais de 3
  pendentes acumuladas, todas rolam e bloqueiam a criação até o usuário zerar o atraso.
- Regras puras em `DailyTaskRules`; persistência em `FocusTask` (`@Model`, nome evita colisão
  com `Swift.Task`). Chave de dia = `"yyyy-MM-dd"` local (ordenável).

### 16.2 Pomodoro por preset (substitui o 6.2 configurável)
- **Dois presets fixos**, escolhidos ao iniciar a tarefa - sem tela de configuração de duração:
  - **`25/5`**: foco 25 min, pausa curta 5 min, pausa longa 15 min.
  - **`50/10`**: foco 50 min, pausa curta 10 min, pausa longa 20 min.
- **Pomodoro clássico com pausa longa**: foco → pausa curta em loop; após 4 blocos de foco,
  pausa longa; e repete. `cyclesUntilLongBreak = 4` (mantém o padrão do 6.2).
- Máquina de estados e correção em background do 6.1/6.3 **continuam valendo**. O `PomodoroConfig`
  configurável do modelo 7 é substituído pelo enum `PomodoroPreset`.

### 16.3 O que muda no roadmap
- Ordem de execução invertida: **núcleo de produtividade (tarefas + Pomodoro) antes do áudio.**
  A trilha de áudio (antiga Fase 1) fica adiada; o DSP procedural puro já está commitado e isolado.
- Modelos afetados (seção 7): entra `FocusTask`; `FocusSession.mixID` vira `taskID`; sai
  `PomodoroConfig` (vira `PomodoroPreset`). Demais guardrails (seção 12) intactos.
