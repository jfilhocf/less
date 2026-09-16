# PROVISIONING - Definition of Ready do projeto

Este arquivo antecipa **todo** recurso externo (ferramenta, conta, API, credencial,
item pago, asset) que cada etapa exige, **antes** de a etapa comecar. E o "nome tecnico"
que faltava: **Definition of Ready (DoR)** - a contraparte da Definition of Done. Onde
a DoD diz "quando uma fase esta pronta", a DoR diz "o que precisa existir para a fase
poder comecar". Na pratica de infra o mesmo se chama **provisionamento / pre-flight
checklist**. Objetivo: nenhuma fase trava no meio por falta de um recurso nao previsto.

## Regra
Nenhuma fase entra em execucao sem os itens da sua linha "DoR" satisfeitos. Se um item
tiver prazo (ex.: aprovacao da Apple), ele e **iniciado com antecedencia** para estar
pronto quando a fase chegar.

## Matriz de provisionamento

| Item | Primeira fase que precisa | Custo | Prazo | Quem provisiona | Status |
|---|---|---|---|---|---|
| Mac + Xcode 26.6 + Git + Homebrew | Fase 0 (autoria/build) | ja pago | - | - | **PRONTO** (verificado 2026-09-16) |
| Repo GitHub + Actions | Fase 0 (para CI) | free (publico: macOS ilimitado; privado: ~200 min/mes) | instantaneo | Joao + agente | **PRONTO** - `jfilhocf/less` publico, CI verde |
| Credencial GitHub no Mac | Fase 0 | free | minutos | `gh auth login` (HTTPS via navegador) | **PRONTO** (2026-09-16) - dispensa PAT manual |
| Homebrew (no Mac) | Fase 6 (base p/ xcodegen) | free | minutos | Joao instala | **PRONTO** (instalado 2026-09-08) |
| XcodeGen (no Mac/CI) | Fase 0/1 (primeiro build) | free (OSS) | instantaneo | `brew install xcodegen` | **PRONTO** no CI e no Mac |
| Xcode 16+ + macOS 14.5+ | Fase 0 (autoria/build) e 6 (device) | ja tem Mac | - | Joao instala | **PRONTO** - Xcode 26.6 / Swift 6.3.3, licenca aceita |
| Claude Code no terminal do Mac | Fase 0 (autoria) | free | minutos | Joao instala | **PRONTO** (2026-09-16) |
| Arquivos de audio de ambiente (.m4a) | Trilha de ambiente | varia (CC0 free / licenca paga / gravar) | dias | Joao decide + fornece | **ADIADO** (decisao: procedural primeiro) |
| Icone final 1024 + launch screen | Fase 5 | design proprio/terceiro | dias | Joao/agente | placeholder gerado; final depois |
| Hospedagem da politica de privacidade | Fase 5 | free (Cloudflare Pages, conta jfilhocf) | instantaneo | agente publica | **PRONTO** (infra ja existe) |
| Apple Developer Program | Fase 6 (assinar/TestFlight/submeter) | **US$ 99/ano** | horas a alguns dias (verificacao) | Joao inscreve | **ADIADO** - "assim que possivel"; comecar ~1-2 sem antes |
| App Store Connect API key (Team Key) | Fase 6 (upload via CI) | free (com a membership) | minutos | Joao gera; guardar como secret | depende da membership |
| iPhone fisico iOS 17+ | Fase 6 (aceite em device) | ja tem/emprestar | - | Joao | a confirmar |
| Screenshots da App Store | Fase 6 | free (simulador/device) | horas | agente/Joao | depois |

## APIs / MCPs - o que NAO e necessario
- **Nenhum MCP novo.** O toolchain iOS e Xcode CLI num Mac, nao um MCP. Os MCPs da sessao
  (google-ads, meta-ads, n8n, Canva, etc.) sao de marketing e nao entram aqui.
- **Nenhuma API de terceiros no app** (guardrail 12.1/12.2): o app e offline por definicao,
  zero pacote externo. As unicas "APIs" do projeto sao de **infra**, nao do app: GitHub REST
  (criar repo, ja ha script `convex-webdev/create_repo.py`) e App Store Connect API (upload).

## Caminho critico de prazo
O unico item com prazo relevante e a **Apple Developer Program** (aprovacao pode levar
dias). Nada das Fases 0-5 depende dela, entao ela roda **em paralelo**: o Joao inicia a
inscricao quando puder e, quando a Fase 6 chegar, a conta ja esta ativa. Esse
desacoplamento e o que mantem "menor quantidade de aprovacoes" - as fases de codigo
correm sozinhas enquanto os itens pagos/lentos sao provisionados ao fundo.
