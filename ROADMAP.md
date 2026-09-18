# ROADMAP - execucao do "less"

Reestruturacao do PRD para **executar com o minimo de aprovacoes** e com os
pre-requisitos **antecipados** (Definition of Ready por fase). Spec do produto:
[`PRD.md`](PRD.md). Matriz de pre-requisitos: [`PROVISIONING.md`](PROVISIONING.md).

> Este documento responde **ordem e escopo**. O estado vivo ("onde paramos hoje") fica no
> [`STATUS.md`](STATUS.md) - a fonte da verdade.

---

## 1. Onde este projeto e desenvolvido

Desde **2026-09-16** o **Mac faz tudo**: autoria, compilacao, testes e device. O erro de
compilacao aparece na hora, nao tres minutos depois no CI.

| Papel | Onde |
|---|---|
| **Autoria + compilacao + testes + device** | Mac do Joao (`~/Developer/less`). Xcode 26.6 / Swift 6.3, Homebrew, XcodeGen, `gh`, Claude Code |
| **Rede de seguranca** | CI (GitHub Actions, runner macOS). Cada push em `main` regenera o projeto do zero e roda os testes. Ver [`.github/workflows/ci.yml`](.github/workflows/ci.yml) |

> **Nota historica (nao e mais instrucao).** Ate 2026-09-16 o projeto era autorado no Windows
> e compilado **so** pelo CI, porque iOS nativo nao compila no Windows e nao havia Mac
> provisionado. Esse arranjo de dois tracks (A = autoria no Windows / B = build & ship no Mac)
> explica varias decisoes deste repo, mas **deixou de valer**. Se algum dia voltar a autorar no
> Windows: **um autor por vez**, sempre via push/pull, nunca em paralelo.

---

## 2. Decisoes travadas (batch unico - fim das "decisoes pendentes do Joao")

O PRD 14 listava 6 decisoes que travariam a execucao no meio. Foram resolvidas de
uma vez (respostas do Joao + defaults sensatos), para a execucao rodar sem parar:

| # (PRD 14) | Decisao | Valor travado |
|---|---|---|
| 1 | Nome do app | **less** (minusculo) |
| 1 | Bundle identifier | **cloud.convextech.less** (default; troca trivial ao configurar o time Apple) |
| 2 | Paleta / acento | Dark-first, fundo quase-preto `#0B0B0C`, **acento teal** `#5EC7BF` (1 token so - `AccentColor`; trocavel a qualquer momento) |
| 3 | Fonte dos ambientes | **Procedural agora, arquivos depois** - binaural e ruido nao usam arquivo; os 4 ambientes entram quando o Joao definir a fonte (ver `ASSETS_LICENSES.md`) |
| 4 | Claro ou dark-only | **Dark-first, respeitando o sistema** (`AppSettings.appearance` ja preve system/light/dark) |
| 5 | Idiomas V1 | **pt-BR + en-US** (String Catalog bilingue desde o inicio) |
| 6 | Tier gratuito permanente | **Adiado** - nao bloqueia o V1 (`isPremium` sempre `false`). Anotado em `BACKLOG.md` |

Ambiente (fora do PRD 14, mas os verdadeiros bloqueios):

| Item | Situacao |
|---|---|
| Build | **PRONTO** - Mac validado em 2026-09-16 (build limpo + 15 testes verdes no Xcode 26.6) |
| Continuidade no Mac | **CONCLUIDA** - repo clonado, `gh` autenticado, ambiente completo |
| Apple Developer Program | **CAMINHO CRITICO desde 2026-09-18** - deixou de ser "so para submeter". E pre-requisito para **pedir** a entitlement de Family Controls (Fase 7), cuja fila de aprovacao e de prazo incerto. Iniciar a inscricao o quanto antes |

---

## 3. Correcoes ao PRD (aplicadas)

1. **On-Demand Resources esta DEPRECADO (iOS 27+).** O PRD 5.5 manda migrar ambientes
   para ODR se passar de 150 MB. Em vez disso: **enviar um set curado de ambientes no
   proprio bundle**, mantendo o app abaixo de 200 MB (limite de download por celular);
   se um dia precisar de packs baixaveis, usar **Background Assets**, nao ODR.
2. **Repo publico durante o build.** Runner macOS em repo privado tem multiplicador 10x
   (~200 min reais/mes no plano free); em repo **publico e ilimitado**. Como nao ha
   segredo no codigo ate existir a App Store Connect API key, o repo fica **publico**
   durante a fase de build e so vira privado na Fase 6.
   > **Custo de virar privado:** acabam os minutos ilimitados de macOS no Actions. Contar
   > com ~200 min reais/mes e, se apertar, rodar CI so em PR/release.
3. **String Catalog bilingue desde a Fase 0** (decisao 5), para nao refatorar copy depois.

---

## 4. Fases (com Definition of Ready e criterio de aceite)

Cada fase declara seus **pre-requisitos (DoR)** - o que precisa existir ANTES de comecar.

### 4.0 Ordem de execucao

**A numeracao NAO e a ordem.** Os numeros sao identificadores estaveis (ha ~45 referencias a
"Fase N" espalhadas por PRD, STATUS, PROVISIONING, README e MAC-HANDOFF; renumerar quebraria
todas). A ordem real, apos a repriorizacao do PRD 16 e o novo escopo do PRD 17:

| Ordem | Fase | Estado |
|---|---|---|
| 1o | **0** - Fundacao | **COMPLETA** - CI verde |
| 2o | **2** - Persistencia | **PARCIAL** - os `@Model` existem; falta `PersistenceService` |
| 3o | **3** - Pomodoro | **PARCIAL** - engine pronto e testado; falta `NotificationService` |
| 4o | **4a** - Minimo usavel | A FAZER - **primeiro teste em iPhone** |
| 5o | **4b** - Interface completa + App Intents | A FAZER |
| 6o | **1** - Audio | ADIADA para ca - `DSP.swift` escrito, falta o servico em volta |
| 7o | **7** - Bloqueio de apps | NOVA - destravada pela **entitlement da Apple** |
| 8o | **5** - Compliance | A FAZER |
| 9o | **6** - Device e submissao | A FAZER |

A **Fase 7** e destravada por evento externo (aprovacao da Apple), nao por ordem de trabalho.
Fica posicionada depois do audio de proposito: o tempo de fila e preenchido com trabalho util.

---

### Fase 0 - Fundacao   **[COMPLETA - CI VERDE]**
- **DoR:** nenhum recurso externo.
- **Entrega:** projeto XcodeGen compilando, shell de 3 abas, protocolos dos servicos,
  Info.plist com `UIBackgroundModes=audio`, `PrivacyInfo.xcprivacy`, asset catalog,
  String Catalog pt-BR/en-US, `.gitattributes` LF, CI macOS.
- **Aceite:** ATENDIDO - CI verde desde o run 34297221631; revalidado localmente no Mac em
  2026-09-16 (compilacao limpa sob strict concurrency + 15 testes em 3 suites).

### Fase 2 - Persistencia do nucleo de produtividade   **[PARCIAL]**
- **DoR:** nenhum.
- **Entrega:** `PersistenceService` sobre SwiftData para `FocusTask`, `FocusSession` e
  `AppSettings` - criar / rolar / concluir tarefa, **reusando as regras puras ja prontas em
  `Sources/Services/Pomodoro/DailyTaskRules.swift`** (teto de 3/dia, rolagem que ocupa vaga).
  Nao reimplementar regra: o servico so persiste o que `DailyTaskRules` decide.
- **Ja existe:** os 4 `@Model` (`FocusTask`, `FocusSession`, `AppSettings`, `PomodoroPreset`).
- **Falta:** `Sources/Services/PersistenceService.swift` e hoje **so um protocolo** (11 linhas).
- **Aceite (CI):** container SwiftData in-memory; criar tarefa, "reabrir", persiste; teto e
  rolagem batem com `DailyTaskRulesTests`.
- > **Reescopada em 2026-09-18:** "seed do catalogo via JSON" e "CRUD de `Mix`" sairam daqui -
  > sao da trilha de audio e migraram para a Fase 1.

### Fase 3 - Timer Pomodoro   **[PARCIAL]**
- **DoR:** nenhum.
- **Ja existe e esta testado:** `PomodoroEngine` (maquina de estados ancorada em timestamp
  absoluto, ADR-05, com reconciliacao de N transicoes perdidas em background - PRD 6.1/6.3) e
  `LiveTimerService` (`@MainActor @Observable`) sobre o motor puro.
- **Falta:** `Sources/Services/NotificationService.swift` e hoje **so um protocolo** (10 linhas).
  Deve agendar as transicoes a partir do **`upcomingTransitions` que o engine ja expoe** - nao
  recalcular datas por fora.
- **Aceite (CI):** testes de reconciliacao com relogio injetado (ja verdes).
  **Aceite (device):** iniciar 25 min, matar o app, esperar 30 min, reabrir -> o app sabe que o
  bloco acabou e a notificacao disparou no instante certo.

### Fase 4a - Minimo usavel   **[A FAZER - primeiro teste em iPhone]**
- **DoR:** Fases 2 e 3 fechadas. Para instalar no iPhone basta **Apple ID gratuito**
  (free provisioning, o app expira em 7 dias) - **nao** precisa dos US$ 99.
- **Entrega:** o caminho feliz, nada alem dele:
  - lista das **3 tarefas do dia** (PRD 16.1) - criar, concluir, ver a rolagem funcionando;
  - **tela de foco** com o tempo restante em tipografia grande e botao unico iniciar/pausar;
  - Pomodoro rodando nos dois presets (`25/5`, `50/10`) com a notificacao de transicao.
- **Aceite:** o Joao usa no proprio dia, no proprio iPhone, e diz o que incomoda.
- > **Por que existe:** valida cedo as regras que o Joao inventou (teto de 3, rolagem que ocupa
  > vaga). Se a regra incomodar na pratica, melhor descobrir antes de construir Ajustes em volta.

### Fase 4b - Interface completa (bilingue, acessivel)   **[A FAZER]**
- **DoR:** 4a validada em uso real.
- **Entrega:** Biblioteca e Ajustes (PRD 8.3/8.4); controles na tela de bloqueio
  (`MPNowPlayingInfoCenter`/`MPRemoteCommandCenter`); aviso de fone; timer de sono;
  estatisticas derivadas; copy pt-BR + en-US completa.
- **+ App Intents** (`iniciar foco`, `pausar`, `concluir tarefa`): expor o `less` ao app
  **Atalhos**, para o usuario montar um Atalho que encadeie **Modo Foco + filtro de cor
  preto-e-branco + iniciar o `less`** numa acao so (Siri, tela de inicio ou botao de Acao).
  Ver PRD 17.2 - e o unico caminho legitimo para esses dois ajustes do sistema.
- **Aceite (device):** VoiceOver completo; Dynamic Type ate `accessibility3` sem
  sobreposicao; Reduce Motion respeitado.

### Fase 1 - Motor de audio   **[ADIADA - entra depois da UI, ainda no V1]**
- **DoR:** nenhum recurso externo para binaural+ruido. (Ambientes: adiados ate ter os `.m4a`.)
- **Ja existe:** `Sources/Services/Audio/DSP.swift` - sintese procedural pura (binaural, ruido,
  fade), commitada e **isolada**, sem nada ligado nela.
- **Falta:** `AudioEngineService` em volta do DSP - grafo (5.1), binaural nos limites (5.2),
  ruido branco/rosa/marrom (5.4), mixagem ate 4 camadas, fades 300 ms, `AVAudioSession` +
  interrupcao/rota (5.6). Ambiente por arquivo fica com a estrutura pronta e stub.
  **+ recebido da Fase 2:** seed do catalogo via JSON no bundle e CRUD de `Mix`.
- **Aceite (CI):** o grafo constroi e a matematica de sintese passa em testes unitarios.
  **Aceite (device):** 30 min em background sem glitch; responde ao botao do fone.
- > **Por que aqui:** repriorizado em 2026-09-14 (PRD 16.3) para o nucleo de produtividade vir
  > antes. Posicao confirmada em 2026-09-18: depois da UI, **dentro do V1** - o PRD define o
  > produto como "player de audio integrado a um timer Pomodoro", entao o V1 sai completo.

### Fase 7 - Bloqueio de apps de video curto   **[NOVA - PRD 17]**
- **DoR (bloqueante):** Apple Developer Program **ativo** + entitlement
  `com.apple.developer.family-controls` **aprovada pela Apple**. Ver `PROVISIONING.md`.
- **Entrega:** `FamilyControls` (autorizacao + `FamilyActivityPicker` para o usuario escolher os
  apps), `ManagedSettings` (shield), `DeviceActivity` (janelas de bloqueio atreladas ao bloco de
  foco do Pomodoro), extensoes de shield.
- **Limite tecnico que NAO se contorna:** o Screen Time opera **no nivel do app**, nunca dentro
  dele. **Nao existe** API para bloquear so os Reels / Shorts deixando o resto do app funcionando
  - nem o AppBlock faz isso. O bloqueio e do app inteiro. Alternativas avaliadas e descartadas
  estao no `BACKLOG.md`.
- **Atencao de provisionamento:** **cada extensao** (Shield Action, Shield Configuration, Device
  Activity Monitor) exige **pedido de entitlement separado por bundle id**, senao falha ao
  assinar em distribuicao.
- **Aceite (device):** iniciar um bloco de foco bloqueia os apps escolhidos; terminar o bloco
  libera; matar o app nao fura o bloqueio.

### Fase 5 - Compliance e politica de privacidade
- **DoR:** hospedagem para a politica (JA existe - Cloudflare Pages, conta jfilhocf).
- **Entrega:** textos revisados contra 10.2 (sem alegacao de saude) nos DOIS idiomas;
  `ASSETS_LICENSES.md` completo (se houver ambientes); **politica de privacidade publicada**
  (pagina estatica no Cloudflare Pages); tela de creditos; icone final; launch screen.
- **Aceite:** politica no ar em URL publica; copy sem termo proibido em pt-BR e en-US.
- > **Com a Fase 7 no escopo:** apps que bloqueiam outros apps recebem **escrutinio extra** na
  > review. A justificativa de uso do Family Controls precisa estar clara na ficha e a coleta
  > zero continua valendo (o Screen Time e local, nao manda nada para lugar nenhum).

### Fase 6 - Build, device e submissao
- **DoR (provisionamento):** ~~Mac com Xcode + XcodeGen~~ **JA SATISFEITO**. Resta: **Apple
  Developer Program**, App Store Connect API key, um iPhone iOS 17+ (o Joao tem o modelo atual).
- **Entrega:** checklist de aceite em device (audio 30 min, fone, VoiceOver, kill-app timer,
  controles de tela de bloqueio, bloqueio de apps); build assinado; TestFlight; ficha +
  screenshots + nutrition label (coleta zero); submissao (atencao a 1.4.1).
- **Aceite:** build aceito pelo App Store Connect sem erro de privacy manifest.
- **Antes desta fase:** tornar o repo **privado** (correcao 2 da secao 3) antes de adicionar a
  API key como secret.

### Trilha de ambiente (paralela, quando o Joao definir a fonte de audio)
- **DoR:** decisao de licenca (comprar / CC0 / gravar) + arquivos `.m4a` + registro em
  `ASSETS_LICENSES.md`. **Entrega:** 4 ambientes (chuva, fogueira, cachoeira, passaros)
  cortados em zero-crossing com crossfade (5.5), ligados no slot ja pronto da Fase 1.

---

## 5. Guardrails e Definition of Done

Valem em toda fase: os 12 guardrails do PRD 12 e a checklist do PRD 13 (compila sem
warning de concorrencia, aceite verificado, testes de `TimerService`/estatisticas,
nenhum guardrail violado, `STATUS.md` atualizado). Oportunidades fora de escopo vao
para `BACKLOG.md`, nao para o codigo.

> O escopo da Fase 7 **nao fura** os guardrails: `FamilyControls`/`ManagedSettings`/
> `DeviceActivity` sao frameworks do proprio sistema (guardrail 2 ok), funcionam **offline e
> localmente** (guardrail 1 ok) e nao coletam nada (guardrail 3 ok).

---

## 6. Fluxo de trabalho (no Mac)

```bash
cd ~/Developer/less

# 1. so se mexeu no project.yml:
xcodegen generate

# 2. compila + testa ANTES de commitar. O simulador e resolvido em tempo de execucao -
#    nunca fixar nome de aparelho, que muda a cada versao do Xcode.
UDID=$(xcrun simctl list devices available -j | python3 -c "import sys,json; d=json.load(sys.stdin); devs=[x for r in d['devices'].values() for x in r if x.get('isAvailable') and 'iPhone' in x['name']]; print(devs[-1]['udid'])")
xcodebuild test -project less.xcodeproj -scheme less \
  -destination "platform=iOS Simulator,id=$UDID" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. commit + push; o CI confere o mesmo no runner macOS
git push origin main && gh run watch
```

Ao fechar a sessao: atualizar o [`STATUS.md`](STATUS.md).
