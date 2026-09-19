import SwiftUI

/// Ajustes (PRD 8.4).
///
/// Fase 4b, primeira parte: a configuracao do Atalho que liga Modo Foco e preto-e-branco
/// junto com o bloco. Volume, aparencia, timer de sono e creditos entram com a trilha de
/// audio.
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var showingManualSteps = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    shortcutSection
                    grayscaleSection
                }
                .padding(24)
            }
            .navigationTitle("ajustes")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Atalho

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("shortcut.section.title", systemImage: "bolt.horizontal")
                .font(.headline)

            Text("shortcut.section.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let install = ShortcutSetup.installURL {
                Button {
                    openURL(install)
                } label: {
                    Label("shortcut.install", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Text("shortcut.install.hint")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                // Sem link publicado ainda: mostrar o passo a passo em vez de um botao que
                // nao faz nada. Botao quebrado e pior que ausencia de botao.
                Button {
                    showingManualSteps.toggle()
                } label: {
                    Label(
                        showingManualSteps ? "shortcut.steps.hide" : "shortcut.steps.show",
                        systemImage: showingManualSteps ? "chevron.up" : "chevron.down"
                    )
                }
                .font(.subheadline)

                if showingManualSteps {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(ShortcutSetup.steps.enumerated()), id: \.offset) { index, key in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                Text(LocalizedStringKey(key))
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if let run = ShortcutSetup.runURL, ShortcutSetup.isShortcutsAppAvailable {
                Button {
                    openURL(run)
                } label: {
                    Label("shortcut.run", systemImage: "play.fill")
                }
                .font(.subheadline)
                .padding(.top, 4)
            }
        }
    }

    // MARK: Preto-e-branco

    private var grayscaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("grayscale.section.title", systemImage: "circle.lefthalf.filled")
                .font(.headline)

            // Honestidade explicita: o usuario merece saber por que ESTE passo nao some, em
            // vez de achar que o app e incompleto.
            Text("grayscale.section.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                // Caminho pela Central de Controle: menos toques que Ajustes > Acessibilidade.
                ForEach(1...4, id: \.self) { step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(step).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Text(LocalizedStringKey("grayscale.step.\(step)"))
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    SettingsView()
}
