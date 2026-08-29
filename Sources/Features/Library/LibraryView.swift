import SwiftUI

/// Biblioteca (PRD 8.3).
///
/// Fase 0: placeholder. Lista agrupada por tipo (Binaural, Ruidos, Ambientes,
/// Meus mixes) com toque para adicionar a mixagem ativa chega na Fase 4.
struct LibraryView: View {
    var body: some View {
        ContentUnavailableView(
            "biblioteca",
            systemImage: "square.stack",
            description: Text(verbatim: "Catalogo e mixes chegam na Fase 4.")
        )
    }
}

#Preview {
    LibraryView()
}
