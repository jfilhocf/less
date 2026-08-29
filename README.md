# less

App iOS de foco: player de audio (ondas binaurais + ruido gerado + ambientes naturais)
integrado a um timer Pomodoro, em interface deliberadamente reduzida. Local-first, offline,
sem conta, sem coleta de dado, sem paywall no V1.

- **Plataforma:** iPhone, iOS 17+. Swift 6 + SwiftUI + SwiftData + AVAudioEngine.
- **Sem dependencias de terceiros.** Projeto gerado por XcodeGen (`project.yml`).

## Como isto e desenvolvido (Windows -> Mac)
iOS nativo nao compila no Windows, entao o trabalho e dividido:
- **Autoria** (Windows): todo o codigo, testes, assets de texto e manifests.
- **Compilacao** (GitHub Actions, runner macOS): gera o projeto, compila para o simulador
  e roda os testes - sem conta Apple.
- **Build & ship** (Mac): rodar em iPhone, assinar e submeter a App Store.

Detalhes: [`ROADMAP.md`](ROADMAP.md) · [`PROVISIONING.md`](PROVISIONING.md) ·
[`MAC-HANDOFF.md`](MAC-HANDOFF.md) · playbook em [`CLAUDE.md`](CLAUDE.md) · spec em
[`PRD.md`](PRD.md).

## Build (no Mac ou CI)
```bash
xcodegen generate
xcodebuild test -project less.xcodeproj -scheme less \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
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
Fase 0 (fundacao) autorada; verificacao de compilacao pelo CI pendente de push. Ver `STATUS.md`.
