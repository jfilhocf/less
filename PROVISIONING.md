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
| Apple Developer Program | **Fase 7** (pedir a entitlement) e Fase 6 (assinar/submeter) | **US$ 99/ano** | horas a alguns dias (verificacao) | Joao inscreve | **CAMINHO CRITICO - INICIAR AGORA** (mudou em 2026-09-18, ver abaixo) |
| **Entitlement `com.apple.developer.family-controls`** | **Fase 7** (bloqueio de apps) | free (com a membership) | **INCERTO** - relatos de semanas em 2026 | Joao solicita no portal; exige membership ativa | **A SOLICITAR** assim que a membership existir |
| App Store Connect API key (Team Key) | Fase 6 (upload via CI) | free (com a membership) | minutos | Joao gera; guardar como secret | depende da membership |
| iPhone fisico iOS 17+ | Fase 4a (primeiro teste) e Fase 6 (aceite) | ja tem | - | Joao | **PRONTO** - Joao tem o modelo atual |
| Apple ID gratuita (free provisioning) | **Fase 4a** (instalar no iPhone sem pagar) | free | minutos | Joao loga no Xcode | **PRONTO 2026-09-19** - time `G5D4SX8763`, app rodando no iPhone 15 Pro Max; expira em 7 dias, basta reinstalar |
| Screenshots da App Store | Fase 6 | free (simulador/device) | horas | agente/Joao | depois |

## APIs / MCPs - o que NAO e necessario
- **Nenhum MCP novo.** O toolchain iOS e Xcode CLI num Mac, nao um MCP. Os MCPs da sessao
  (google-ads, meta-ads, n8n, Canva, etc.) sao de marketing e nao entram aqui.
- **Nenhuma API de terceiros no app** (guardrail 12.1/12.2): o app e offline por definicao,
  zero pacote externo. As unicas "APIs" do projeto sao de **infra**, nao do app: GitHub
  (via `gh`) e App Store Connect API (upload).
- **Screen Time nao viola isso** (Fase 7, PRD 17): `FamilyControls`, `ManagedSettings` e
  `DeviceActivity` sao frameworks do **proprio sistema**, funcionam **offline e localmente** e
  nao coletam nada. Nao sao dependencia de terceiro nem rede - guardrails 1, 2 e 3 intactos.
  O que elas exigem nao e codigo, e **permissao**: a entitlement da linha acima.

## Caminho critico de prazo

**Mudou em 2026-09-18.** Antes o unico item lento era o Developer Program, e nada das Fases 0-5
dependia dele - rodava em paralelo, sem incomodar ninguem. Com a entrada da **Fase 7 (bloqueio
de apps)** formou-se uma **corrente de dois elos**, e ela e agora o caminho critico do projeto:

```
Developer Program (US$ 99, horas a dias)  ->  entitlement Family Controls (PRAZO INCERTO)  ->  Fase 7
```

O segundo elo so pode comecar depois do primeiro: **a entitlement e pedida pela conta paga**.
Em 2026 ha relatos de atraso sistemico nessa fila - um pedido sem resposta apos 9 dias, e casos
de aprovacao por email com o portal travado em "Submitted", **bloqueando a submissao**.

**Consequencia pratica:** iniciar a inscricao **agora**, nao "quando a Fase 6 chegar". Enquanto a
fila da Apple corre ao fundo, o trabalho segue nas Fases 2, 3, 4a, 4b e 1 - nenhuma delas depende
da conta paga. A Fase 4a, inclusive, instala no iPhone com **Apple ID gratuita**.

> **Cada extensao precisa do proprio pedido.** Se a Fase 7 shipar extensoes (Shield Action,
> Shield Configuration, Device Activity Monitor), **cada bundle id** exige um pedido de
> entitlement separado - senao falha ao assinar em distribuicao, ja na reta final.
