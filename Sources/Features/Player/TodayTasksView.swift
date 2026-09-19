import SwiftUI

/// Lista das tarefas do dia (PRD 16.1). Teto de 3: quando cheio, o campo de entrada some
/// em vez de aceitar e recusar depois - a restricao e do produto, nao um erro do usuario.
struct TodayTasksView: View {
    @Bindable var store: FocusStore
    @State private var draft = ""
    @FocusState private var writing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            if store.tasks.isEmpty {
                empty
            } else {
                VStack(spacing: 12) {
                    ForEach(store.tasks) { task in
                        TaskRow(
                            task: task,
                            onStart: { store.start(task) },
                            onComplete: { store.complete(task) }
                        )
                    }
                }
            }

            if store.canCreate {
                composer
            } else if !store.tasks.isEmpty {
                Text("today.full")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let message = store.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
    }

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

/// Uma tarefa da lista. Toque no circulo conclui; toque no texto inicia o Pomodoro.
private struct TaskRow: View {
    let task: FocusTask
    let onStart: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("task.complete"))

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
    }
}
