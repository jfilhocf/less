import SwiftUI
import SwiftData

/// Tela principal (PRD 8.2).
///
/// Alterna entre a lista do dia e a tela de foco. Sem navegacao empilhada de proposito -
/// ou voce esta escolhendo o que fazer, ou esta fazendo.
///
/// O store **nao nasce aqui**: vem do `FocusRuntime`, porque um App Intent sobe o app sem
/// View montada e precisa alcancar o mesmo store que esta tela mostra.
struct PlayerView: View {
    @Environment(\.scenePhase) private var scenePhase

    private var store: FocusStore { FocusRuntime.store }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if store.isFocusing {
                FocusSessionView(store: store)
                    .transition(.opacity)
            } else {
                TodayTasksView(store: store)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: store.isFocusing)
        .task {
            store.refresh()
            #if DEBUG
            // Popula o dia para inspecionar a interface no simulador. So em DEBUG:
            // nao existe no build de release.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-seedDemo") || args.contains("-seedRunning") {
                store.seedDemo(startFirst: args.contains("-seedRunning"))
            }
            #endif
            // A permissao de notificacao e pedida ao iniciar o primeiro bloco, nao aqui.
        }
        .onChange(of: scenePhase) { _, phase in
            // Voltar do background reconstroi o estado a partir da ancora em disco:
            // e aqui que N transicoes perdidas sao reconciliadas de uma vez (PRD 6.3).
            if phase == .active { store.refresh() }
        }
    }
}

#Preview {
    let container = try! ModelContainer.lessInMemory()
    FocusRuntime.install(
        container: container,
        store: FocusStore(
            persistence: SwiftDataPersistenceService(container: container),
            notifications: LiveNotificationService()
        )
    )
    return PlayerView().modelContainer(container)
}
