# MAC-HANDOFF - continuar o "less" no Mac

Runbook para quando o Joao pegar o Mac e instalar o **Claude Code no terminal**. Foi
escrito para o codigo ter sido 100% autorado no Windows e so precisar do Mac para o que
o Mac faz de fato: compilar de verdade, rodar em iPhone, assinar e submeter.

## 0. Instalar o basico (uma vez)
```bash
# Xcode: instalar pela App Store (Xcode 16+ para Swift 6). Depois:
xcode-select --install
sudo xcodebuild -license accept
# Homebrew (se nao tiver) e o gerador de projeto:
brew install xcodegen
# Claude Code:
npm install -g @anthropic-ai/claude-code    # ou o instalador oficial do momento
```

## 1. Pegar o codigo
- **Se o repo ja estiver no GitHub:** `git clone <url> && cd less`
- **Se ainda estiver so no Windows:** copiar a pasta `less/` para o Mac (o repo git local
  ja tem o historico; nao precisa de GitHub para abrir no Xcode).

## 2. Gerar e abrir o projeto
```bash
xcodegen generate          # cria less.xcodeproj a partir do project.yml
open less.xcodeproj
```
> O `.xcodeproj` e o `Info.plist` sao GERADOS (estao no .gitignore). Sempre rode
> `xcodegen generate` depois de puxar mudancas no `project.yml`.

## 3. Compilar e testar sem conta Apple (simulador)
```bash
xcodebuild test -project less.xcodeproj -scheme less \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```
Isso e o mesmo que o CI faz. Se o CI ja estava verde, aqui tambem deve estar.

## 4. Provisionar a conta Apple (quando for assinar) - ver PROVISIONING.md
- Inscrever no **Apple Developer Program** (US$ 99/ano).
- No Xcode: Signing & Capabilities -> selecionar o Team; ajustar `DEVELOPMENT_TEAM` e,
  se quiser, o bundle id (default `cloud.convextech.less`).
- Gerar uma **App Store Connect API key** (Team Key) para upload por CI/Fastlane.

## 5. Aceite em device (o que o CI NAO consegue verificar)
Checklist em iPhone fisico iOS 17+:
- [ ] Audio toca 30 min em background, tela apagada, sem glitch/clique/dropout.
- [ ] Tirar o fone pausa a reproducao; recolocar retoma conforme esperado (5.6/5.7).
- [ ] Aviso "precisa de fones" aparece quando binaural toca no alto-falante.
- [ ] Controles na tela de bloqueio / Central de Controle / botao do fone (play/pause/toggle).
- [ ] Iniciar Pomodoro 25 min, **matar o app**, esperar 30 min: ao reabrir o app sabe que o
      bloco acabou e a **notificacao disparou no instante certo** (6.3).
- [ ] VoiceOver navega tudo, inclusive sliders de volume; Dynamic Type ate `accessibility3`
      sem sobreposicao; Reduce Motion respeitado.

## 6. Submeter
- Politica de privacidade publicada (Fase 5, Cloudflare Pages) - URL na ficha da App Store.
- Nutrition label: **coleta zero** (verdade). Privacy manifest ja incluso (`PrivacyInfo.xcprivacy`).
- Revisar TODA copy visivel contra o PRD 10.2 (sem alegacao de saude) em **pt-BR e en-US**.
- `xcodebuild archive` -> assinar -> exportar IPA -> TestFlight (Fastlane com a API key) -> submeter.

## Regras que continuam valendo no Mac
- Nao violar os 12 guardrails do PRD 12 (offline, zero dependencia, timer por timestamp,
  sintese procedural, sem alegacao de saude, sem paywall, sem gamificacao...).
- Editar sempre a fonte + `project.yml`; nunca editar o `.xcodeproj` gerado a mao.
- Fechar sessao = atualizar `STATUS.md`.
