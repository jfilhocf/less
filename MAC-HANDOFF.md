# MAC-HANDOFF - continuar o "less" no Mac

Runbook da migracao do desenvolvimento para o Mac. **Os passos 0-3 estao CONCLUIDOS
(2026-09-16)**: o Mac deixou de ser so a maquina de assinar e passou a ser onde o projeto e
autorado, compilado e testado. O que resta aqui e o que so o Mac faz: assinar, rodar em
iPhone fisico e submeter.

## 0. Instalar o basico - CONCLUIDO
Estado verificado na maquina em 2026-09-16:

| Item | Estado |
|---|---|
| Xcode **26.6** (Swift 6.3.3), licenca aceita | OK |
| Homebrew | OK |
| XcodeGen (`/opt/homebrew/bin/xcodegen`) | OK |
| Claude Code no terminal | OK |
| GitHub CLI (`gh`) | OK |
| git (`user.name`/`user.email` configurados) | OK |

## 1. Pegar o codigo - CONCLUIDO
Clonado em `~/Developer/less` via `gh`/HTTPS:
```bash
git clone https://github.com/jfilhocf/less.git ~/Developer/less
```
> `~/Developer` e a convencao da Apple. Nao usar `~/Documents`: o iCloud Drive sincroniza
> build artifacts e corrompe DerivedData.

## 2. Gerar e abrir o projeto - CONCLUIDO
```bash
xcodegen generate          # cria less.xcodeproj a partir do project.yml
open less.xcodeproj
```
> O `.xcodeproj` e o `Info.plist` sao GERADOS (estao no .gitignore). Sempre rode
> `xcodegen generate` depois de mexer no `project.yml`.

## 3. Compilar e testar sem conta Apple (simulador) - CONCLUIDO
**Verde em 2026-09-16: 15 testes em 3 suites, compilacao limpa no Xcode 26.6.**
```bash
UDID=$(xcrun simctl list devices available -j | python3 -c "import sys,json; d=json.load(sys.stdin); devs=[x for r in d['devices'].values() for x in r if x.get('isAvailable') and 'iPhone' in x['name']]; print(devs[-1]['udid'])")
xcodebuild test -project less.xcodeproj -scheme less \
  -destination "platform=iOS Simulator,id=$UDID" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```
> **Nao fixe o nome do simulador.** A versao anterior deste runbook usava
> `name=iPhone 16 Pro`, que nao existe mais no Xcode 26 (os simuladores agora sao iPhone 17
> / Air, runtime iOS 26.5) - o comando quebrava. Resolver o UDID em tempo de execucao, como
> o `ci.yml` ja fazia, sobrevive a qualquer atualizacao do Xcode.

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
