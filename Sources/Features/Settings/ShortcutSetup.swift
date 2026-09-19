import Foundation
import UIKit

/// O Atalho que liga Modo Foco + preto-e-branco junto com o bloco de foco.
///
/// **Por que nao e o app que faz isso.** Nenhum app de terceiro no iOS liga o Modo Foco ou o
/// filtro de cor por conta propria - nao ha API publica, e isso foi verificado em Opal, Jomo,
/// one sec, Brick, Roots, Clearspace e ate num app cujo unico proposito e grayscale. O
/// caminho legitimo e o app Atalhos.
///
/// **O que o `less` faz de diferente:** ele NAO manda o usuario montar o Atalho. Entrega
/// pronto por link do iCloud (2 toques, uma vez) e depois dispara ele do proprio botao. A
/// versao anterior deste plano mandava o usuario montar na mao - o one sec fez isso por anos
/// e chamou de "its biggest problem by far" antes de abandonar.
enum ShortcutSetup {
    /// Nome exato do Atalho. `run-shortcut` acha por nome, entao renomear quebra o botao -
    /// o texto de ajuda avisa o usuario.
    static let shortcutName = "less: Foco"

    /// Link do iCloud com o Atalho pronto, gerado uma vez pelo autor do app.
    ///
    /// `nil` = ainda nao publicado; a interface entao mostra o passo a passo manual em vez de
    /// um botao quebrado. **Dependencia remota deliberadamente OPCIONAL** (guardrail 1): se a
    /// Apple derrubar o link - ja aconteceu em massa em marco/2021 - o app continua inteiro,
    /// so perde a conveniencia.
    static let iCloudLink: URL? = nil

    /// Abre o Atalhos na tela de importacao do Atalho pronto.
    static var installURL: URL? { iCloudLink }

    /// Dispara o Atalho. O Atalhos pisca na tela e volta - custo aceitavel para um botao
    /// apertado poucas vezes ao dia.
    static var runURL: URL? {
        var components = URLComponents(string: "shortcuts://run-shortcut")
        components?.queryItems = [URLQueryItem(name: "name", value: shortcutName)]
        return components?.url
    }

    /// `true` se o app Atalhos existe no aparelho (some em alguns perfis gerenciados).
    @MainActor
    static var isShortcutsAppAvailable: Bool {
        guard let url = URL(string: "shortcuts://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// As acoes que o Atalho precisa ter, na ordem. Usado pelo texto de ajuda - e o que o
    /// autor monta uma vez para gerar o link.
    ///
    /// A ULTIMA acao e "Abrir App: less" de proposito, e nao um `x-callback-url`: ha relato
    /// aberto no forum da Apple de que x-callback parou de retornar desde o iOS 18,
    /// reproduzido em apps independentes. "Abrir App" nao depende de nada disso.
    static let steps: [String] = [
        "shortcut.step.focus",
        "shortcut.step.grayscale",
        "shortcut.step.start",
        "shortcut.step.open",
    ]
}
