# BACKLOG - fora do escopo do V1

Guardrail 12.10: ideia de melhoria fora de escopo NAO entra no codigo - anota aqui e segue.
Nada nesta lista deve ser implementado no V1 sem autorizacao explicita.

## Fora do V1 (PRD 2.2) - registrado, nao implementar
- Conta/login, backend, sync entre dispositivos.
- Compras no app / paywall (o campo `isPremium` existe e fica `false` no V1 - PRD 2.3).
- SDK de analytics; widgets, Live Activity; watchOS/iPad/macOS.
- HealthKit, Apple Music, Spotify; qualquer coisa social/ranking/compartilhamento.

> **App Intents / Atalhos sairam desta lista em 2026-09-18.** Entraram no V1 (Fase 4b) porque
> sao o **unico** caminho legitimo para o usuario ativar Modo Foco e filtro de cor preto-e-branco
> - nao ha API publica para um app fazer isso sozinho. Ver PRD 17.2.

## Decisoes adiadas (nao bloqueiam o V1)
- **Tier gratuito permanente** (PRD 14.6): definir a fronteira do que fica gratis para sempre,
  para nao criar paywall retroativo quando a monetizacao entrar. Decidir antes de ligar `isPremium`.
- **Packs de ambiente baixaveis:** se um dia o conjunto de audios passar de ~200 MB, usar
  **Background Assets** (nao On-Demand Resources, que esta deprecado). No V1: set curado in-bundle.

## Avaliado e DESCARTADO com razao tecnica (2026-09-18)

Registrado para a ideia nao voltar do zero daqui a alguns meses. Contexto: PRD 17.

- **Bloquear so os Reels / Shorts, deixando o resto do app funcionando** - **IMPOSSIVEL** com
  API oficial. O Screen Time (`FamilyControls`/`ManagedSettings`/`DeviceActivity`) opera **no
  nivel do app**; a Apple nao expoe controle sobre o que acontece dentro de um app de terceiro.
  O proprio **AppBlock**, tomado como referencia, nao faz isso - bloqueia o app inteiro.
  *Reavaliar so se a Apple publicar API de conteudo intra-app.*
- **Web app "limpo" no Safari** (abordagem do ScrollGuard: versao web do Instagram/YouTube sem
  a aba de video curto) - tecnicamente possivel, mas **tira o usuario do app nativo**, que e
  onde ele de fato esta. Troca um problema de foco por um de usabilidade.
- **Classificador de gravacao de tela on-device** para detectar e bloquear video curto dentro
  do app nativo - **DESACONSELHADO**. Colide de frente com a promessa de **coleta zero** que
  sustenta o `PrivacyInfo.xcprivacy` e a nutrition label. Nao vale o risco na review nem a
  quebra de confianca, mesmo processando tudo localmente.
- **Ativar Modo Foco / filtro de cor direto pelo app** - nao ha API publica.
  `SetFocusFilterIntent` serve para **reagir** a um Foco, nao para ativa-lo. Caminho adotado:
  App Intents + Atalhos (PRD 17.2, Fase 4b).
- **Exceções de contatos no Modo Foco** (ligacoes que furam o bloqueio) - configuracao manual
  nos Ajustes do iOS, fora do alcance de qualquer app de terceiro.

## Ideias soltas (avaliar no futuro)
- (vazio - adicionar aqui o que surgir durante a execucao)
