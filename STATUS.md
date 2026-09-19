# STATUS - less (app de foco iOS)

> STATUS de PROJETO (pessoal do Joao, nao-cliente). Fonte da verdade do estado do app.
> Atualizar AQUI ao "fechar a sessao". Rollup do workspace: ../STATUS.md.
> Spec: PRD.md · Execucao: ROADMAP.md · Pre-requisitos: PROVISIONING.md · Mac: MAC-HANDOFF.md.

- **Tipo:** app iOS nativo (Swift 6 / SwiftUI / SwiftData / AVAudioEngine), local-first, offline.
- **Codigo mora em:** `~/Developer/less` no Mac (`github.com/jfilhocf/less`). Historico comeca
  em 2026-08-29; migrado do Windows para o Mac em 2026-09-16.
- **Onde compila:** **Mac** (autoria + compilacao + testes + device); CI (GitHub Actions/macOS)
  como rede de seguranca a cada push.
- **Bundle id:** `cloud.convextech.less` · **Idiomas:** pt-BR + en-US · **Marca:** dark-first, acento teal `#5EC7BF`.

## Estado atual (2026-09-08)

- **Fase 0 (Fundacao) VERIFICADA NO CI - VERDE.** Repo `github.com/jfilhocf/less` (publico ate
  Fase 6) criado e pushado; GitHub Actions rodou `xcodegen generate` + `xcodebuild test` no
  simulador iOS (macos-15) e TODOS os steps passaram (run 34297221631). Primeira compilacao
  Swift real do projeto - o codigo compila limpo e os testes de sanidade passam.
  - `project.yml` (XcodeGen): target app `less` + target de teste `lessTests`, Swift 6 strict
    concurrency, `UIBackgroundModes=audio`, iOS 17, iPhone-only.
  - Shell de 3 abas (Player/Biblioteca/Ajustes) + 4 protocolos de servico (sem impl).
  - `PrivacyInfo.xcprivacy` (coleta zero, UserDefaults CA92.1), Assets (AppIcon placeholder +
    AccentColor teal), `Localizable.xcstrings` pt-BR/en-US, `.gitattributes` LF.
  - CI `.github/workflows/ci.yml`: escolhe simulador, build + test sem assinatura.
- **Decisoes do PRD 14 travadas em batch** (ver ROADMAP 2): nome=less, bundle, acento teal,
  ambiente procedural-primeiro, dark-first, bilingue, tier gratuito adiado.
- **Correcoes ao PRD aplicadas** (ROADMAP 3): ODR deprecado -> ambientes in-bundle < 200 MB;
  repo publico durante build; String Catalog bilingue desde ja.

## Migracao para o Mac (2026-09-16) - o Mac virou o autor principal

- **Decisao do Joao:** o Mac passa a ser onde o `less` e autorado, compilado, testado e rodado
  em device. O desktop Windows sai do fluxo (outros projetos + consulta pontual). Acaba o ciclo
  "escrever no Windows -> push -> esperar o CI dizer se compila": o erro de compilacao agora
  aparece na hora.
- **Ambiente (verificado):** Xcode 26.6 / Swift 6.3.3, Homebrew, XcodeGen, `gh`, Claude Code.
  Codigo em `~/Developer/less`. `git` como `jfilhocf <jfilhocf@gmail.com>` (o historico do
  Windows usa o nome `Joao (Convex)` com o mesmo e-mail - a atribuicao no GitHub e a mesma).
- **Build local VERDE:** `xcodegen generate` + `xcodebuild test` = compilacao limpa e **15 testes
  em 3 suites** passando (`DailyTaskRules`, `PomodoroEngine`, `Sanidade`). O Xcode local e varias
  versoes mais novo que o `macos-15` do CI e, mesmo com `SWIFT_STRICT_CONCURRENCY: complete`,
  nao acusou nada - o codigo autorado no Windows estava solido.
- **Bug de documentacao corrigido:** README/CLAUDE/MAC-HANDOFF fixavam
  `-destination name=iPhone 16 Pro`, aparelho que **nao existe** no Xcode 26 (runtime iOS 26.5,
  simuladores iPhone 17/Air) - o comando documentado quebrava no Mac. Agora resolvem o UDID em
  tempo de execucao, como o `ci.yml` ja fazia. Nao fixar nome de simulador em doc nenhuma.

## Pendencias

- ~~**[BLOQUEIO CI]** repo+push+CI~~ **RESOLVIDO 2026-09-08** (repo publico no ar, CI verde).
- **[antes da Fase 6]** tornar o repo PRIVADO antes de adicionar a App Store Connect API key.
  Custo: acabam os minutos ilimitados de macOS no Actions (~200 min reais/mes).
- **[JOAO - CAMINHO CRITICO, INICIAR AGORA]** Apple Developer Program (US$ 99/ano). Mudou de
  prioridade em 2026-09-18: deixou de ser "so para submeter" e virou **pre-requisito para pedir
  a entitlement de Family Controls** (Fase 7). Enquanto a conta nao existe, o pedido nem comeca.
- **[JOAO - depois da membership]** solicitar a entitlement `com.apple.developer.family-controls`
  no portal. **Prazo INCERTO** (relatos de semanas em 2026; ha casos de aprovacao por email com o
  portal travado em "Submitted", bloqueando submissao). Cada extensao exige pedido separado.
- ~~**[Mac]** provisionamento do Mac~~ **RESOLVIDO 2026-09-16** - Xcode 26.6, Homebrew,
  XcodeGen, `gh` e Claude Code instalados; repo clonado; build e 15 testes verdes localmente.
- **[decisao adiada]** fonte dos arquivos de ambiente (.m4a) - por ora, so procedural.
- Icone/launch/screenshots finais: placeholder gerado; definitivos na Fase 5.

## Repriorizacao (2026-09-14) - nucleo de produtividade antes do audio
- **Mudanca de escopo autorizada pelo Joao** (ver PRD secao 16): entra uma **lista de tarefas
  do dia** (teto de 3/dia; incompleta rola e ocupa vaga; concluir nao devolve vaga) e o
  Pomodoro vira **dois presets fixos** (`25/5` e `50/10`), classico com pausa longa apos 4 blocos.
- **Ordem invertida:** produtividade (tarefas + Pomodoro) ANTES da trilha de audio. O audio
  (antiga Fase 1) fica adiado; DSP procedural puro ja commitado e isolado (`Sources/Services/Audio/DSP.swift`).
- **Track B (Mac):** CONCLUIDO em 2026-09-16 - o Mac virou o autor principal e a divisao
  Windows/CI acabou (ver secao abaixo). O Windows fica para outros projetos e consulta pontual.

## Feito nesta sessao (2026-09-14) - nucleo logico + testes (CI-verificavel)
- **Logica pura (testavel sem device):** `PomodoroEngine` (maquina de estados ancorada em
  timestamp + reconciliacao de N transicoes perdidas em background, PRD 6.3), `DailyTaskRules`
  (teto/rolagem), `PomodoroPreset`/`PomodoroPhase`.
- **Modelos SwiftData:** `FocusTask`, `FocusSession` (mixID->taskID), `AppSettings`. (`PomodoroConfig` substituido por preset.)
- **Servico:** `LiveTimerService` (`@MainActor @Observable`) sobre o motor puro.
- **Testes Swift Testing:** `PomodoroEngineTests` + `DailyTaskRulesTests`. **CI VERDE** (15 testes OK, run 34865687552).

## Novo escopo (2026-09-18) - bloqueio de distracao + ajustes de foco do iPhone

**Mudanca autorizada pelo Joao** (ver PRD secao 17). O `less` passa a atuar tambem sobre a
**fonte** da distracao, nao so sobre ambiente (audio) e tempo (Pomodoro).

- **Bloqueio de apps de video curto - VIAVEL.** Screen Time APIs (`FamilyControls`,
  `ManagedSettings`, `DeviceActivity`). Vira a **Fase 7**, destravada pela entitlement da Apple.
- **Bloquear so os Reels/Shorts - IMPOSSIVEL.** O Screen Time opera no nivel do app; a Apple nao
  expoe controle do que acontece dentro de app de terceiro. Nem o AppBlock faz isso. **O `less`
  bloqueia o app inteiro** - e a copy precisa dizer isso. Alternativas descartadas no `BACKLOG.md`.
- **Preto-e-branco e Modo Foco - INDIRETO.** Sem API publica; `SetFocusFilterIntent` so **reage**
  a um Foco. Caminho: o `less` expoe **App Intents** e o usuario monta um Atalho que encadeia
  Foco + filtro de cor + `less`. Entra na Fase 4b. (Saiu do `BACKLOG.md`, onde estava como
  "fora do V1".)
- **Fase 4 dividida:** `4a` minimo usavel (3 tarefas + tela de foco + Pomodoro + notificacao;
  instala no iPhone com **Apple ID gratuita**, sem os US$ 99) e `4b` completa.
- **Audio confirmado no V1**, depois da UI - o PRD define o produto como "player de audio
  integrado a um timer Pomodoro".
- **Guardrails intactos:** Screen Time e framework do sistema (2), offline e local (1), sem
  coleta (3).

## Feito nesta sessao (2026-09-18) - FASE 2 FECHADA: persistencia

- **`SwiftDataPersistenceService`** sobre SwiftData: tarefas do dia (criar / concluir / rolar /
  apagar), `AppSettings` como singleton, `FocusSession` gravada e consultada por intervalo.
  **Nao decide regra**: teto e rolagem continuam em `DailyTaskRules` (puro); o servico so aplica
  e grava. `PersistenceError.dayIsFull` distingue "dia cheio" de erro generico.
- **`ModelContainer.less()` / `.lessInMemory()`**: schema num lugar so, para app e testes nao
  divergirem. Container ligado no `lessApp.swift` via `.modelContainer(...)`.
- **11 testes novos** (total: **26 em 4 suites**, todos verdes, zero warning de concorrencia).
- **Dois bugs achados e corrigidos durante a implementacao:**
  1. `ModelContainer(for:)` sem URL explicita assume que `Application Support` existe - nao
     existe em container novo (simulador/primeiro launch). Agora o diretorio e criado e o store
     tem nome proprio (`less.store`).
  2. **`ModelContext` NAO retem o `ModelContainer`.** Guardar so o contexto fazia o container
     morrer com o escopo que o criou e o processo caia com SIGTRAP, sem erro Swift - crash mudo.
     O servico agora retem o container de proposito (ha comentario no codigo avisando).

## Feito nesta sessao (2026-09-18, parte 2) - FASE 3 FECHADA NO CI: notificacoes

- **`LiveNotificationService`**: uma notificacao local por transicao de ciclo, agendada a
  partir do `upcomingTransitions` que o `PomodoroEngine` **ja expoe** - o servico nao recalcula
  quando cada fase termina, so traduz transicao em notificacao. Disparo por **data absoluta**
  (nunca intervalo relativo, que derivaria com o app suspenso - guardrail 12.4).
- **Cancela antes de reagendar**, entao reconciliar N vezes nao acumula duplicata; e
  `cancelAll()` filtra por prefixo proprio, sem tocar notificacao de outra origem.
- **Copy bilingue** (pt-BR/en-US) no String Catalog, sem alegacao de saude nem tom de cobranca:
  a notificacao so anuncia a fase que comeca. Sem corpo quando nao ha tarefa - nada de
  engajamento (guardrail 12.9).
- **12 testes novos** (total: **38 em 5 suites**, verdes, zero warning de concorrencia).
- **Decisao de concorrencia:** `UNNotificationRequest` **nao e `Sendable`** e o Swift 6 barra
  passa-lo entre atores - erro de compilacao legitimo. Criado `PendingNotification` (tipo
  proprio, Sendable); a traducao para o tipo do sistema acontece so na borda, em
  `SystemNotificationCenter`. Efeito colateral bom: a logica do servico nao depende mais do
  framework e o teste nao precisa de centro de notificacoes.
- **Pendente:** o aceite em device da Fase 3 (matar o app com Pomodoro rodando e conferir se a
  notificacao dispara na hora certa) **depende da Fase 4a** - sem tela nao ha como iniciar um
  Pomodoro. Entra no checklist da 4a.

## Feito nesta sessao (2026-09-18, parte 3) - FASE 4a: O APP TEM TELA

- **`FocusStore`** (`@MainActor @Observable`) orquestra tarefas + Pomodoro + notificacoes.
  Continua **sem regra propria**: teto e rolagem em `DailyTaskRules`, tempo no `PomodoroEngine`.
- **`TodayTasksView`**: lista das 3 tarefas do dia, criar, concluir, aviso de quantas rolaram.
  Ao bater o teto o campo de entrada **some**, em vez de aceitar e recusar depois - a restricao
  e do produto, nao erro do usuario.
- **`FocusSessionView`**: tempo em tipografia grande, fase, pontos de ciclo, um botao principal.
- **Permissao de notificacao pedida ao iniciar o primeiro bloco**, nunca no launch.
- **13 testes novos** (total: **51 em 6 suites**, verdes, zero warning).
- **RECONCILIACAO VERIFICADA DE VERDADE:** app morto no simulador com Pomodoro rodando,
  reaberto 45 s depois -> voltou na tela de foco com o tempo ja descontado. Fecha o aceite que
  estava pendente da Fase 3. Teste deterministico cobre ate varias transicoes perdidas de uma vez.
- **Bug corrigido:** `canCreate` lia `Date()` solto enquanto o resto do store usava a data
  injetada - no app funcionava por coincidencia, mas o estado exibido e o consultado podiam ser
  de dias diferentes. Agora o store fixa um `dayKey` por recarga e tudo deriva dele.
- **`seedDemo`** em `#if DEBUG` popula o dia via argumento de launch (`-seedDemo`,
  `-seedRunning`) para inspecionar a interface no simulador. **Nao existe no build de release.**

## Proximo passo
- ~~**Fase 2** - `PersistenceService`~~ **FEITA 2026-09-18** (26 testes).
- ~~**Fase 3** - `NotificationService`~~ **FEITA 2026-09-18** (38 testes).
- ~~**Fase 4a** - minimo usavel~~ **CONSTRUIDA 2026-09-18** (51 testes).
- **AGORA E COM O JOAO: usar o app no proprio iPhone, no proprio dia.** Instala com Apple ID
  gratuita (7 dias), sem os US$ 99. E o unico jeito de saber se as regras que ele inventou
  (teto de 3, rolagem que ocupa vaga) funcionam na pratica - e se a notificacao dispara certo
  com o aparelho bloqueado. **Nao construir a 4b antes desse retorno**: seria construir Ajustes
  em volta de uma regra ainda nao validada.
- Depois: 4b (+ App Intents) -> Audio -> Fase 7 (bloqueio) -> Compliance -> Submissao.

## Historico
- 2026-09-18 - **Documentacao sincronizada + novo escopo (PRD 17).** O `ROADMAP.md` estava
  desatualizado em duas ondas (nao absorveu a repriorizacao de 14/09 e ainda descrevia o mundo
  Windows/PAT); reescrito com **tabela de ordem de execucao** - a numeracao das fases virou
  identificador estavel, nao ordem (ha ~45 referencias a "Fase N" em 6 docs; renumerar quebraria
  35 delas). Nova Fase 7 (bloqueio), Fase 4 dividida em 4a/4b, audio confirmado no V1 apos a UI.
  Pesquisa de viabilidade das 3 ideias novas registrada no PRD 17 e no BACKLOG.
- 2026-08-29 - Projeto criado. PRD lido e reestruturado em 2 tracks (autoria Windows / build Mac)
  com Definition of Ready por fase. Fase 0 autorada (shell + build config + CI + docs). Repo local (e9fbfd5).
- 2026-08-30 - Sessao encerrada. Fase 0 commitada e validada estruturalmente (YAML/JSON/plist);
  compilacao Swift ainda NAO verificada. Decisao a/b acima em aberto; bloqueio do CI = PAT ausente.
- 2026-09-08 - PAT ja estava no cofre (bloqueio caiu). Repo `jfilhocf/less` criado PUBLICO,
  push da Fase 0, **CI VERDE** (run 34297221631: xcodegen + xcodebuild test, todos steps OK).
  Fase 0 verificada de verdade. Proximo: Fase 1 (motor de audio).
- 2026-09-08 (fim do dia) - Joao comecou a provisionar o Mac (Track B, antecipado): Homebrew
  instalado; travou em achar o Xcode na App Store (hipotese: macOS < 14.5). Retoma amanha 09/09.
- 2026-09-16 - **Migracao para o Mac concluida.** Ambiente provisionado do zero (git, `gh`,
  clone em `~/Developer/less`), `xcodegen generate` + `xcodebuild test` **VERDES localmente**
  (15 testes, 3 suites) no Xcode 26.6/Swift 6.3 - bem mais novo que o Xcode do CI e ainda assim
  compilacao limpa sob strict concurrency. Docs realinhadas (Mac = autor principal) e comando de
  build corrigido: `iPhone 16 Pro` nao existe no Xcode 26, agora o simulador e resolvido por UDID.
- 2026-09-14 - Xcode 16+ instalado no Mac; Joao instalando o resto e o Claude Code no terminal do Mac.
  Repriorizacao autorizada: nucleo de produtividade (tarefas do dia + Pomodoro por preset) antes do
  audio (PRD secao 16). Autorada a logica pura (PomodoroEngine, DailyTaskRules), modelos SwiftData e
  testes; pushado e **CI verde** (run 34865687552). DSP de audio commitado (parcial) e adiado.
