# BACKLOG - fora do escopo do V1

Guardrail 12.10: ideia de melhoria fora de escopo NAO entra no codigo - anota aqui e segue.
Nada nesta lista deve ser implementado no V1 sem autorizacao explicita.

## Fora do V1 (PRD 2.2) - registrado, nao implementar
- Conta/login, backend, sync entre dispositivos.
- Compras no app / paywall (o campo `isPremium` existe e fica `false` no V1 - PRD 2.3).
- SDK de analytics; widgets, Live Activity, App Intents, atalhos; watchOS/iPad/macOS.
- HealthKit, Apple Music, Spotify; qualquer coisa social/ranking/compartilhamento.

## Decisoes adiadas (nao bloqueiam o V1)
- **Tier gratuito permanente** (PRD 14.6): definir a fronteira do que fica gratis para sempre,
  para nao criar paywall retroativo quando a monetizacao entrar. Decidir antes de ligar `isPremium`.
- **Packs de ambiente baixaveis:** se um dia o conjunto de audios passar de ~200 MB, usar
  **Background Assets** (nao On-Demand Resources, que esta deprecado). No V1: set curado in-bundle.

## Ideias soltas (avaliar no futuro)
- (vazio - adicionar aqui o que surgir durante a execucao)
