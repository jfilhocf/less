# less

App iOS de foco: player de audio (ondas binaurais + ruido gerado + ambientes naturais)
integrado a um timer Pomodoro, em interface deliberadamente reduzida. Local-first, offline,
sem conta, sem coleta de dado, sem paywall no V1.

- **Plataforma:** iPhone, iOS 17+. Swift 6 + SwiftUI + SwiftData + AVAudioEngine.
- **Sem dependencias de terceiros.** Projeto gerado por XcodeGen (`project.yml`).

## Como isto e desenvolvido
Desenvolvimento **no Mac**: autoria, compilacao, testes e device no mesmo lugar.
O **CI** (GitHub Actions, runner macOS) e a rede de seguranca - a cada push em `main`
regenera o projeto do zero e roda os testes, sem conta Apple.

> Ate 2026-09-16 o projeto era autorado no Windows e compilado so pelo CI, porque iOS
> nativo nao compila no Windows e nao havia Mac provisionado. Esse arranjo acabou.

Detalhes: [`ROADMAP.md`](ROADMAP.md) · [`PROVISIONING.md`](PROVISIONING.md) ·
[`MAC-HANDOFF.md`](MAC-HANDOFF.md) · playbook em [`CLAUDE.md`](CLAUDE.md) · spec em
[`PRD.md`](PRD.md).

## Build
```bash
xcodegen generate     # less.xcodeproj e gerado (esta no .gitignore); nunca edite ele a mao

# o simulador e resolvido em tempo de execucao - nao fixe nome de aparelho, que muda a cada Xcode
UDID=$(xcrun simctl list devices available -j | python3 -c "import sys,json; d=json.load(sys.stdin); devs=[x for r in d['devices'].values() for x in r if x.get('isAvailable') and 'iPhone' in x['name']]; print(devs[-1]['udid'])")
xcodebuild test -project less.xcodeproj -scheme less \
  -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO
```

## Estrutura
```
project.yml                 manifesto XcodeGen (fonte de verdade do projeto Xcode)
.github/workflows/ci.yml    compila + testa no runner macOS
Sources/App/                entry point + navegacao
Sources/Features/           Player, Library, Settings
Sources/Services/           protocolos: Audio, Timer, Persistence, Notification
Sources/Models/             @Model do SwiftData (Fase 2)
Sources/Resources/          Info.plist(gerado), PrivacyInfo.xcprivacy, Assets, .xcstrings
Tests/lessTests/            Swift Testing
```

## Status
Fase 0 (fundacao) verificada no CI. Nucleo de produtividade (Pomodoro por preset + tarefas do
dia) autorado e coberto por 15 testes. Ver `STATUS.md`.
