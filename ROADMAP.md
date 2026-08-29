# ROADMAP - execucao do "less"

Reestruturacao do PRD para **executar com o minimo de aprovacoes** e com os
pre-requisitos **antecipados** (Definition of Ready por fase). Spec do produto:
[`PRD.md`](PRD.md). Matriz de pre-requisitos: [`PROVISIONING.md`](PROVISIONING.md).

---

## 1. A restricao que molda tudo

iOS nativo (Swift 6, Xcode, SwiftData, AVAudioEngine) **nao compila no Windows** -
e a maquina de desenvolvimento e Windows. Logo o gargalo do projeto nao e decisao
de design, e **ambiente**. A resposta e separar o trabalho em dois tracks:

| Track | Onde | Quando | Precisa de aprovacao? |
|---|---|---|---|
| **A - Autoria** | Windows (esta maquina) | agora, continuo | Nao. Autonomo. |
| **B - Build & Ship** | Mac do Joao, via Claude Code no terminal do Mac | quando o Mac estiver disponivel | So o que exige conta/hardware |

O Track A escreve ~100% do codigo, testes, assets de texto, manifests e docs.
O Track B (Mac) faz o que **so** o Mac faz: rodar em iPhone, assinar, submeter.

### O compilador enquanto nao ha Mac
Como nao da pra compilar no Windows, o **GitHub Actions (runner macOS)** e o
compilador: a cada push ele gera o projeto (`xcodegen`), compila para o simulador
e roda os testes Swift Testing - **sem conta Apple** (build de simulador nao assina).
Isso leva praticamente todo o codebase a "compila limpo + testes verdes" sem Mac.
Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

---

## 2. Decisoes travadas (batch unico - fim das "decisoes pendentes do Joao")

O PRD 14 listava 6 decisoes que travariam a execucao no meio. Foram resolvidas de
uma vez (respostas do Joao + defaults sensatos), para o Track A rodar sem parar:

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

| Item | Decisao |
|---|---|
| Build | Mac do Joao (existe), indisponivel agora -> **CI como compilador ja; Mac depois** |
| Apple Developer Program | **Adiado** - Joao inscreve "assim que possivel"; nada das Fases 0-4 precisa |
| Continuidade no Mac | **Claude Code instalado no terminal do Mac** clona o repo e segue por `MAC-HANDOFF.md` |

---

## 3. Correcoes ao PRD (aplicadas)

1. **On-Demand Resources esta DEPRECADO (iOS 27+).** O PRD 5.5 manda migrar ambientes
   para ODR se passar de 150 MB. Em vez disso: **enviar um set curado de ambientes no
   proprio bundle**, mantendo o app abaixo de 200 MB (limite de download por celular);
   se um dia precisar de packs baixaveis, usar **Background Assets**, nao ODR.
2. **Repo publico durante o build.** Runner macOS em repo privado tem multiplicador 10x
   (~200 min reais/mes no plano free); em repo **publico e ilimitado**. Como nao ha
   segredo no codigo ate existir a App Store Connect API key, manter o repo **publico**
   durante a fase de build e so torna-lo privado antes de adicionar a chave. (Se o Joao
   preferir privado, cabe nos 200 min/mes com CI so em PR/release.)
3. **String Catalog bilingue desde a Fase 0** (decisao 5), para nao refatorar copy depois.

---

## 4. Fases (com Definition of Ready e criterio de aceite)

Cada fase declara seus **pre-requisitos (DoR)** - o que precisa existir ANTES de
comecar. Fases 0-4 tem DoR vazio de ambiente: rodam so com Windows + CI.

### Fase 0 - Fundacao  [FEITA nesta sessao, pendente verificacao no CI]
- **DoR:** nenhum recurso externo. (Repo GitHub opcional, so para acionar o CI.)
- **Entrega:** projeto XcodeGen compilando, shell de 3 abas, protocolos dos servicos,
  Info.plist com `UIBackgroundModes=audio`, `PrivacyInfo.xcprivacy`, asset catalog,
  String Catalog pt-BR/en-US, `.gitattributes` LF, CI macOS.
- **Aceite:** CI verde - `xcodebuild` compila para simulador sem warning de
  concorrencia e os testes de sanidade passam. (So verifica quando houver push -> ver 6.)

### Fase 1 - Motor de audio
- **DoR:** nenhum recurso externo para binaural+ruido. (Ambientes: adiados ate ter os `.m4a`.)
- **Entrega:** `AudioEngineService` (grafo 5.1), binaural (portadora/batimento nos limites
  5.2), ruido branco/rosa/marrom (5.4), mixagem ate 4 camadas, fades 300 ms, `AVAudioSession`
  + interrupcao/rota (5.6). Ambiente por arquivo fica com a estrutura pronta e stub.
- **Aceite (CI):** o grafo constroi e a matematica de sintese passa em testes unitarios.
  **Aceite (device, Track B):** 30 min em background sem glitch; responde ao botao do fone.

### Fase 2 - Persistencia e catalogo
- **DoR:** nenhum. **Entrega:** todos os `@Model` (7), seed do catalogo via JSON no bundle,
  CRUD de `Mix`, singletons de `AppSettings`/`PomodoroConfig`.
- **Aceite (CI):** container SwiftData in-memory; criar mix, "reabrir", persiste.

### Fase 3 - Timer Pomodoro
- **DoR:** nenhum. **Entrega:** `TimerService` ancorado em timestamp (ADR-05), maquina de
  estados (6.1), `NotificationService` (transicoes), reconciliacao no retorno do background
  inclusive transicoes perdidas, `FocusSession`.
- **Aceite (CI):** testes unitarios de reconciliacao (matar/voltar, N transicoes perdidas)
  com relogio injetado. **Aceite (device):** iniciar 25 min, matar o app, esperar 30 min,
  reabrir -> app sabe que o bloco acabou e a notificacao disparou no instante certo.

### Fase 4 - Interface (bilingue, acessivel)
- **DoR:** nenhum (icone/screenshots reais podem entrar aqui ou na Fase 5).
- **Entrega:** Player, Biblioteca, Ajustes (8); controles na tela de bloqueio
  (`MPNowPlayingInfoCenter`/`MPRemoteCommandCenter`); aviso de fone; timer de sono;
  estatisticas derivadas; copy pt-BR + en-US.
- **Aceite (device):** VoiceOver completo; Dynamic Type ate `accessibility3` sem
  sobreposicao; Reduce Motion respeitado.

### Fase 5 - Compliance e politica de privacidade
- **DoR:** hospedagem para a politica (JA existe - Cloudflare Pages, conta jfilhocf).
- **Entrega:** textos revisados contra 10.2 (sem alegacao de saude) nos DOIS idiomas;
  `ASSETS_LICENSES.md` completo (se houver ambientes); **politica de privacidade publicada**
  (pagina estatica no Cloudflare Pages); tela de creditos; icone final; launch screen.
- **Aceite:** politica no ar em URL publica; copy sem termo proibido em pt-BR e en-US.

### Fase 6 - Build, device e submissao  (Track B - Mac do Joao)
- **DoR (provisionamento):** Mac com Xcode + XcodeGen; **Apple Developer Program ($99/ano)**;
  App Store Connect API key; um iPhone iOS 17+. Ver `PROVISIONING.md` e `MAC-HANDOFF.md`.
- **Entrega:** checklist de aceite em device (audio 30 min, fone, VoiceOver, kill-app timer,
  controles de tela de bloqueio); build assinado; TestFlight; ficha + screenshots + nutrition
  label (coleta zero); submissao (atencao a 1.4.1).
- **Aceite:** build aceito pelo App Store Connect sem erro de privacy manifest.

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

---

## 6. Como acionar o CI (unico passo manual pendente agora)

O repositorio esta pronto localmente. Para o CI comecar a compilar de verdade:

1. Colar um GitHub PAT (escopo `repo`) em `../convex-ads/SEGREDOS.local.md` na linha
   `GITHUB_TOKEN=<pat>` (o cofre ainda nao tem token).
2. Criar o repo e apontar o remote (privado por padrao; use `--public` para minutos ilimitados):
   ```
   python ../convex-webdev/create_repo.py less --desc "less - app de foco iOS" --remote .
   ```
3. `git push -u origin main`. O Actions roda e reporta compila/testes.

Enquanto o token nao existe, o Track A segue (codigo + testes commitados localmente);
a **primeira verificacao de compilacao** acontece no primeiro push (CI) ou no primeiro
`xcodegen generate` + build no Mac.
