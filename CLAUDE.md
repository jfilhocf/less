# CLAUDE.md - playbook do "less" (app de foco iOS)

App iOS nativo de foco: player de audio (binaural + ruido procedural + ambientes) integrado
a um timer Pomodoro, interface deliberadamente reduzida. Projeto **pessoal do Joao**, nao e
entregavel de cliente da agencia. Vive em `claude-workspace/less/` como repo git proprio.

Spec: [`PRD.md`](PRD.md). Execucao: [`ROADMAP.md`](ROADMAP.md). Pre-requisitos:
[`PROVISIONING.md`](PROVISIONING.md). Estado vivo: [`STATUS.md`](STATUS.md).
Continuar no Mac: [`MAC-HANDOFF.md`](MAC-HANDOFF.md).

## Onde este projeto compila
- **Windows (esta maquina):** autoria de TODO o codigo/texto. NAO compila iOS aqui.
- **CI (GitHub Actions, runner macOS):** o compilador. Push -> `xcodegen` -> build simulador
  -> testes Swift Testing, sem conta Apple. Ver `.github/workflows/ci.yml`.
- **Mac do Joao (depois):** device, assinatura, submissao. Ver `MAC-HANDOFF.md`.

## Stack (fechada - ADRs no PRD 3)
- Swift 6 (strict concurrency) · SwiftUI + Observation (`@Observable`) · SwiftData ·
  AVFoundation/AVAudioEngine · UserNotifications · MediaPlayer · Swift Testing (nao XCTest).
- **Zero dependencia de terceiro no app.** XcodeGen e ferramenta de build (nao runtime), ok.
- Projeto definido em `project.yml` (XcodeGen). O `.xcodeproj` e o `Info.plist` sao GERADOS
  e ficam no `.gitignore` - editar a fonte, nunca o gerado.

## Comandos
```bash
xcodegen generate     # (no Mac/CI) gera less.xcodeproj a partir do project.yml
xcodebuild test -project less.xcodeproj -scheme less \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO      # compila + testa no simulador, sem assinar
```
No Windows so se edita e commita; a verificacao vem do CI (ou do Mac).

## Guardrails (PRD 12 - resumo; sao restricoes rigidas)
1. Sem backend/API/rede. Offline por definicao.
2. Sem dependencia de terceiro (parar e justificar se achar indispensavel).
3. Sem analytics/crash-SDK/telemetria.
4. Pomodoro so por **timestamp absoluto**, nunca contagem incremental.
5. Binaural e ruido **so sintese procedural**, nunca arquivo.
6. **Sem alegacao de saude** em copy nenhuma (ler PRD 10.2 antes de escrever texto visivel).
7. Nenhum audio no repo sem registro em `ASSETS_LICENSES.md`.
8. Sem paywall/compra/assinatura (`isPremium` existe mas e sempre `false` no V1).
9. Sem gamificacao/badges/streak agressiva; UNICA notificacao = transicao de ciclo do Pomodoro.
10. Nao aumentar escopo - ideias fora de escopo vao pro `BACKLOG.md`.
11. Nao tocar o motor de audio pela main thread em render.
12. Nao persistir o que da pra derivar (estatisticas sao runtime).

## Convencoes
- Estrutura: `Sources/{App,Features,Services,Models,Resources}` + `Tests/lessTests`.
- Idioma da UI: pt-BR + en-US via `Localizable.xcstrings` (todo texto externalizado).
- Marca: dark-first, fundo `#0B0B0C`, acento teal `#5EC7BF` (`AccentColor`, 1 token).
- Ao fechar sessao: atualizar `STATUS.md` (o que foi feito, pendente, decisoes).
