import XCTest
@testable import PokeTokenBar

/// An item's description says what it does (issue #176, the owner, 2026-11-10: "afficher ce que ça fait de manière
/// efficace et propre"): an item is never taken back, so "while you own it" said nothing.
@MainActor
final class ItemDescriptionWordingTests: XCTestCase {
    func testNoDescriptionSaysWhileYouOwnIt() {
        // German said it mid-sentence ("Lässt im Beutel ... wachsen"); a candy staying "im Beutel." is no such phrase.
        let phrasings = ["보유하면", "While owned", "持っていると", "Mientras lo tengas", "Mientras la tengas", "Mientras los tengas",
                         "Mientras las tengas", "Tant que tu", "Enquanto estiver", "Im Beutel", " im Beutel ",
                         "Пока он у вас", "Пока она у вас", "Пока оно у вас", "Пока они у вас"]
        for language in AppLanguage.allCases {
            let l = L(language)
            for kind in ItemKind.allCases {
                let text = l.itemDescription(kind)
                for phrase in phrasings where text.contains(phrase) {
                    XCTFail("\(language) \(kind.rawValue): \(text)")
                }
            }
        }
    }
}
