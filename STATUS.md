# STATUS - less (app de foco iOS)

> STATUS de PROJETO (pessoal do Joao, nao-cliente). Fonte da verdade do estado do app.
> Atualizar AQUI ao "fechar a sessao". Rollup do workspace: ../STATUS.md.
> Spec: PRD.md · Execucao: ROADMAP.md · Pre-requisitos: PROVISIONING.md · Mac: MAC-HANDOFF.md.

- **Tipo:** app iOS nativo (Swift 6 / SwiftUI / SwiftData / AVAudioEngine), local-first, offline.
- **Codigo mora em:** `claude-workspace/less/` (repo git proprio, `git init` local em 2026-08-29).
- **Onde compila:** Windows autora; **GitHub Actions (macOS) e o compilador**; Mac do Joao para device/submissao.
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

## Pendencias

- ~~**[BLOQUEIO CI]** repo+push+CI~~ **RESOLVIDO 2026-09-08** (repo publico no ar, CI verde).
- **[antes da Fase 6]** tornar o repo PRIVADO antes de adicionar a App Store Connect API key.
- **[Joao, quando puder]** Apple Developer Program (US$ 99/ano) - iniciar cedo (prazo de dias).
- **[Mac - EM ANDAMENTO 2026-09-08]** provisionamento do Mac do Joao iniciado: **Homebrew JA
  INSTALADO**. Falta: **Xcode 16+** (Joao nao achou na App Store - provavel macOS antigo demais;
  min = macOS Sonoma 14.5+ / Sequoia; ver versao do macOS antes), depois `brew install xcodegen`
  + Claude Code (`curl -fsSL https://claude.ai/install.sh | bash`). Joao retoma amanha (09/09).
- **[decisao adiada]** fonte dos arquivos de ambiente (.m4a) - por ora, so procedural.
- Icone/launch/screenshots finais: placeholder gerado; definitivos na Fase 5.

## Proximo passo
- Decisao a/b RESOLVIDA pela via (a): CI verde primeiro. Base solida pra construir em cima.
- **Fase 1 (motor de audio):** binaural + ruido procedural (sem depender de recurso externo),
  ambiente com slot pronto/stub. Autoravel ja no Windows; agora com CI compilando a cada push
  = feedback loop real. Cada push na main compila+testa no simulador.

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
