import SwiftUI

/// Ajustes (PRD 8.4).
///
/// Fase 4b, primeira parte: a configuracao do Atalho que liga Modo Foco e preto-e-branco
/// junto com o bloco. Volume, aparencia, timer de sono e creditos entram com a trilha de
/// audio.
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingManualSteps = false
    /// `UIAccessibility.isGrayscaleEnabled` e especifico de **grayscale**, nao da chave
    /// mestra de filtros de cor - confirmado no binario do UIKit, que chama
    /// `_AXSGrayscaleEnabled` e nao `_AXSDisplayFilterColorEnabled`. Por isso da para
    /// distinguir "ligou um filtro" de "ligou o preto-e-branco".
    @State private var grayscaleOn = UIAccessibility.isGrayscaleEnabled

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
            // A leitura direta usa cache e pode vir velha ao voltar do atalho; a
            // notificacao e a fonte confiavel.
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIAccessibility.grayscaleStatusDidChangeNotification
                )
            ) { _ in
                grayscaleOn = UIAccessibility.isGrayscaleEnabled
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { grayscaleOn = UIAccessibility.isGrayscaleEnabled }
            }
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

            if !grayscaleOn {
                // Em vez de deixar a pessoa achar que o app esta quebrado quando a tela
                // nao fica cinza, dizer o que de fato falta.
                VStack(alignment: .leading, spacing: 8) {
                    Label("grayscale.warning", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("grayscale.openSettings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.footnote)
                }
                .padding(12)
                .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                // Caminho pelos Ajustes. A versao anterior mandava escolher o filtro pela
                // Central de Controle - e la o controle e liga/desliga puro, sem seletor.
                // Seguindo aquele texto, o filtro nunca chegava a ser escolhido.
                ForEach(1...6, id: \.self) { step in
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
