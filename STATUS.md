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
- **[Joao, quando puder]** Apple Developer Program (US$ 99/ano) - iniciar cedo (prazo de dias).
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

## Proximo passo
- ~~Confirmar CI verde deste incremento~~ **CI VERDE 2026-09-14** (run 34865687552: compilou
  limpo + 15 testes passaram). Nucleo de produtividade validado.
- Depois: `PersistenceService`/servico de tarefas sobre SwiftData (criar/rolar/concluir usando
  `DailyTaskRules`), `NotificationService` (agendar transicoes via `upcomingTransitions`), e a
  UI da Fase 4 (lista de 3 tarefas + tela de foco). Audio retoma apos o nucleo de produtividade.

## Historico
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
