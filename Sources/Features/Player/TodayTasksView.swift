import SwiftUI

/// Lista das tarefas do dia (PRD 16.1).
///
/// Teto de 3: quando cheio, o campo de entrada some - a restricao e do produto, nao um erro
/// do usuario. Mas **apagar tem que continuar acessivel mesmo com o dia cheio**, senao o app
/// trava: com as 3 concluidas nao havia nem como adicionar, nem como remover.
struct TodayTasksView: View {
    @Bindable var store: FocusStore
    @State private var draft = ""
    @FocusState private var writing: Bool

    /// Todas as tarefas do dia concluidas - o dia acabou, e a tela precisa dizer o que fazer.
    private var dayIsDone: Bool {
        !store.tasks.isEmpty && store.tasks.allSatisfy(\.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if store.tasks.isEmpty {
                empty
                Spacer(minLength: 0)
            } else {
                taskList
            }

            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: Lista

    /// `List` (e nao `VStack`) por um motivo concreto: **`swipeActions` so existe em `List`**.
    /// A versao anterior punha o apagar so num `contextMenu`, e o toque longo era engolido
    /// pelos botoes da propria linha - o menu nunca abria e o apagar era inalcancavel.
    private var taskList: some View {
        List {
            ForEach(store.tasks) { task in
                TaskRow(
                    task: task,
                    onStart: { store.start(task) },
                    onToggle: { store.toggleCompletion(task) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.delete(task)
                    } label: {
                        Label("task.delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        store.toggleCompletion(task)
                    } label: {
                        Label(
                            task.isCompleted ? "task.uncomplete" : "task.complete",
                            systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    .tint(task.isCompleted ? .gray : .accentColor)
                }
                // Redundancia deliberada: quem nao descobre o swipe acha pelo toque longo.
                .contextMenu {
                    Button(action: { store.toggleCompletion(task) }) {
                        Label(
                            task.isCompleted ? "task.uncomplete" : "task.complete",
                            systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    Button(role: .destructive, action: { store.delete(task) }) {
                        Label("task.delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(store.tasks.count <= 3)
    }

    // MARK: Cabecalho e rodape

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("today.title")
                .font(.largeTitle.weight(.thin))
            if store.rolledOverCount > 0 {
                Text("today.rolled \(store.rolledOverCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var empty: some View {
        Text("today.empty")
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.canCreate {
                composer
            } else if dayIsDone {
                // Dia cumprido: elogia e diz como recomecar, em vez de so bloquear.
                Text("today.done")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !store.tasks.isEmpty {
                Text("today.full")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Dica do gesto: aparece so quando o dia esta cheio, que e quando apagar vira
            // a unica saida. Antes disso seria ruido.
            if !store.canCreate && !store.tasks.isEmpty {
                Label("today.swipe.hint", systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let message = store.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.bottom, 12)
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("today.add.placeholder", text: $draft)
                .textFieldStyle(.plain)
                .focused($writing)
                .submitLabel(.done)
                .onSubmit(add)

            Button(action: add) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel(Text("today.add"))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
        }
    }

    private func add() {
        store.addTask(title: draft)
        draft = ""
        writing = false
    }
}

/// Uma tarefa da lista. Toque no circulo alterna feito/pendente; toque no texto inicia o
/// Pomodoro. Apagar fica no swipe da linha, na `List` acima.
private struct TaskRow: View {
    let task: FocusTask
    let onStart: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(task.isCompleted ? "task.uncomplete" : "task.complete"))

            Button(action: onStart) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                    Text(verbatim: task.preset.label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(task.isCompleted)
        }
        .animation(.default, value: task.isCompleted)
    }
}
