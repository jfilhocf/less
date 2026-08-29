# STATUS - less (app de foco iOS)

> STATUS de PROJETO (pessoal do Joao, nao-cliente). Fonte da verdade do estado do app.
> Atualizar AQUI ao "fechar a sessao". Rollup do workspace: ../STATUS.md.
> Spec: PRD.md · Execucao: ROADMAP.md · Pre-requisitos: PROVISIONING.md · Mac: MAC-HANDOFF.md.

- **Tipo:** app iOS nativo (Swift 6 / SwiftUI / SwiftData / AVAudioEngine), local-first, offline.
- **Codigo mora em:** `claude-workspace/less/` (repo git proprio, `git init` local em 2026-08-29).
- **Onde compila:** Windows autora; **GitHub Actions (macOS) e o compilador**; Mac do Joao para device/submissao.
- **Bundle id:** `cloud.convextech.less` · **Idiomas:** pt-BR + en-US · **Marca:** dark-first, acento teal `#5EC7BF`.

## Estado atual (2026-08-29)

- **Fase 0 (Fundacao) AUTORADA** - pendente verificacao no CI (precisa de push; ver Pendencias).
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

## Pendencias

- **[BLOQUEIO CI]** Colar GitHub PAT (escopo `repo`) em `../convex-ads/SEGREDOS.local.md`
  (`GITHUB_TOKEN=<pat>`) -> `python ../convex-webdev/create_repo.py less --desc "..." --remote .`
  -> `git push -u origin main`. So entao o CI compila (primeira verificacao real do codigo).
- **[Joao, quando puder]** Apple Developer Program (US$ 99/ano) - iniciar cedo (prazo de dias).
- **[Joao, quando pegar o Mac]** instalar Claude Code no terminal do Mac e seguir MAC-HANDOFF.md.
- **[decisao adiada]** fonte dos arquivos de ambiente (.m4a) - por ora, so procedural.
- Icone/launch/screenshots finais: placeholder gerado; definitivos na Fase 5.

## Proximo passo
- Fase 1 (motor de audio): binaural + ruido procedural (sem depender de recurso externo),
  ambiente com slot pronto/stub. Autoravel ja no Windows; verificavel no CI.

## Historico
- 2026-08-29 - Projeto criado. PRD lido e reestruturado em 2 tracks (autoria Windows / build Mac)
  com Definition of Ready por fase. Fase 0 autorada (shell + build config + CI + docs). Repo local.
