import Foundation
import SwiftData

/// Ajustes globais do app (PRD 7). Singleton: garantir instancia unica na inicializacao.
/// `masterVolume`/`headphoneWarningEnabled`/`sleepTimerMinutes` servem a trilha de audio
/// (adiada); ja modelados para nao migrar schema depois.
@Model
final class AppSettings {
    var id: UUID
    var masterVolume: Double
    var hapticsEnabled: Bool
    var headphoneWarningEnabled: Bool
    var sleepTimerMinutes: Int?
    /// "system" | "light" | "dark" (dark-first, respeitando o sistema).
    var appearance: String
    /// Preset de Pomodoro escolhido por padrao ao criar tarefa (rawValue de `PomodoroPreset`).
    var defaultPresetRaw: String

    init(
        id: UUID = UUID(),
        masterVolume: Double = 1.0,
        hapticsEnabled: Bool = true,
        headphoneWarningEnabled: Bool = true,
        sleepTimerMinutes: Int? = nil,
        appearance: String = "system",
        defaultPreset: PomodoroPreset = .short
    ) {
        self.id = id
        self.masterVolume = masterVolume
        self.hapticsEnabled = hapticsEnabled
        self.headphoneWarningEnabled = headphoneWarningEnabled
        self.sleepTimerMinutes = sleepTimerMinutes
        self.appearance = appearance
        self.defaultPresetRaw = defaultPreset.rawValue
    }

    var defaultPreset: PomodoroPreset {
        PomodoroPreset(rawValue: defaultPresetRaw) ?? .short
    }
}
