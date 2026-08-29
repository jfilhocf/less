import Foundation

/// Contrato de notificacoes locais (PRD 6.3) sobre UserNotifications.
///
/// A implementacao (Fase 3) agenda uma notificacao local por transicao de ciclo
/// prevista e as cancela ao pausar, resetar ou reconfigurar. A UNICA notificacao
/// permitida no app e a transicao de ciclo do Pomodoro - nada de engajamento
/// (guardrail 12.9).
protocol NotificationService: Sendable {
}
