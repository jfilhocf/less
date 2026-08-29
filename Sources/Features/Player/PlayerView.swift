import SwiftUI

/// Tela principal (PRD 8.2).
///
/// Fase 0: placeholder. A hierarquia definitiva - tempo restante em tipografia
/// grande, indicador de estado, pontos de ciclo, botao unico iniciar/pausar e
/// camadas ativas colapsaveis - chega na Fase 4.
struct PlayerView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Text(verbatim: "less")
                .font(.system(size: 56, weight: .thin, design: .rounded))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

#Preview {
    PlayerView()
}
