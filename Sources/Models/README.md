# Models

Vazio na Fase 0 de proposito. Os tipos `@Model` do SwiftData (PRD 7) - `SoundPreset`,
`Mix`, `MixLayer`, `PomodoroConfig`, `FocusSession`, `AppSettings` - e os enums de
dominio (`SoundKind`, `NoiseColor`, `PomodoroPhase`) sao criados na **Fase 2**.

Regra: estatisticas sao derivadas em runtime de `FocusSession`, nunca persistidas
(guardrail 12.12). `SoundPreset.isPremium` existe desde o inicio e vale sempre `false`
no V1 (PRD 2.3), so para evitar migracao de schema quando a monetizacao entrar.
