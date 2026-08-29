import SwiftUI

/// Ajustes (PRD 8.4).
///
/// Fase 0: placeholder. Configuracao do Pomodoro, volume master, aparencia,
/// haptics, timer de sono, aviso de fone, sobre o app, politica de privacidade
/// e creditos de audio chegam na Fase 4.
struct SettingsView: View {
    var body: some View {
        ContentUnavailableView(
            "ajustes",
            systemImage: "slider.horizontal.3",
            description: Text(verbatim: "Configuracoes chegam na Fase 4.")
        )
    }
}

#Preview {
    SettingsView()
}
