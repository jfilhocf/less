import SwiftUI
import SwiftData

/// Tela principal (PRD 8.2).
///
/// Fase 4a: alterna entre a lista do dia e a tela de foco. Sem navegacao empilhada de
/// proposito - ou voce esta escolhendo o que fazer, ou esta fazendo.
struct PlayerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: FocusStore?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if let store {
                if store.isFocusing {
                    FocusSessionView(store: store)
                        .transition(.opacity)
                } else {
                    TodayTasksView(store: store)
                        .transition(.opacity)
                }
            } else {
                ProgressView()
            }
        }
        .animation(.default, value: store?.isFocusing)
        .task {
            if store == nil {
                let created = FocusStore(
                    persistence: SwiftDataPersistenceService(container: context.container),
                    notifications: LiveNotificationService()
                )
                created.refresh()
                #if DEBUG
                // Popula o dia para inspecionar a interface no simulador. So em DEBUG:
                // nao existe no build de release.
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-seedDemo") || args.contains("-seedRunning") {
                    created.seedDemo(startFirst: args.contains("-seedRunning"))
                }
                #endif
                store = created
                // A permissao de notificacao e pedida ao iniciar o primeiro bloco, nao aqui.
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Voltar do background reconstroi o estado a partir da ancora em disco:
            // e aqui que N transicoes perdidas sao reconciliadas de uma vez (PRD 6.3).
            if phase == .active { store?.refresh() }
        }
    }
}

#Preview {
    PlayerView()
        .modelContainer(try! .lessInMemory())
}
