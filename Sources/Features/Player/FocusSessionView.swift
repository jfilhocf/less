import SwiftUI

/// Tela de foco (PRD 8.2): tempo restante em tipografia grande, fase, pontos de ciclo e
/// **um** botao principal. Nada mais - e a tela que o usuario olha enquanto trabalha.
struct FocusSessionView: View {
    @Bindable var store: FocusStore

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let task = store.activeTask {
                Text(task.title)
                    .font(.headline.weight(.regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(Self.clock(store.remaining))
                .font(.system(size: 76, weight: .thin, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel(Text("focus.remaining"))
                .accessibilityValue(Text(Self.spoken(store.remaining)))

            VStack(spacing: 12) {
                Text(Self.phaseKey(store.phase))
                    .font(.subheadline)
                    .foregroundStyle(store.phase == .focus ? Color.accentColor : .secondary)
                cycleDots
            }

            Spacer()
            controls
        }
        .padding(24)
        .animation(.default, value: store.phase)
    }

    /// Pontos de ciclo: quantos blocos de foco fecharam ate a pausa longa.
    private var cycleDots: some View {
        let total = store.activeTask?.preset.cyclesUntilLongBreak ?? 4
        let done = store.completedFocusBlocks % total
        return HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < done ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("focus.cycles"))
        .accessibilityValue(Text("\(done)/\(total)"))
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                store.isRunning ? store.pause() : store.resume()
            } label: {
                Text(store.isRunning ? "focus.pause" : "focus.resume")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)

            Button {
                store.stop()
            } label: {
                Text("focus.stop")
                    .font(.headline)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Formatacao

    /// "mm:ss", arredondando para cima para nao mostrar 00:00 com tempo restante.
    static func clock(_ remaining: TimeInterval) -> String {
        let total = Int(ceil(max(0, remaining)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Versao falada para o VoiceOver - "12 minutos e 30 segundos" le melhor que "12:30".
    static func spoken(_ remaining: TimeInterval) -> String {
        let total = Int(ceil(max(0, remaining)))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: TimeInterval(total)) ?? "\(total)"
    }

    static func phaseKey(_ phase: PomodoroPhase) -> LocalizedStringKey {
        switch phase {
        case .focus:      return "phase.focus"
        case .shortBreak: return "phase.shortBreak"
        case .longBreak:  return "phase.longBreak"
        }
    }
}
