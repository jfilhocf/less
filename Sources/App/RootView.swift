import SwiftUI

/// Navegacao de 3 abas (PRD 8.1). O Player e a aba inicial.
/// Sem tab bar aninhada, sem menu hamburguer.
struct RootView: View {
    var body: some View {
        TabView {
            PlayerView()
                .tabItem { Label("player", systemImage: "waveform") }
            LibraryView()
                .tabItem { Label("biblioteca", systemImage: "square.stack") }
            SettingsView()
                .tabItem { Label("ajustes", systemImage: "slider.horizontal.3") }
        }
    }
}

#Preview {
    RootView()
}
