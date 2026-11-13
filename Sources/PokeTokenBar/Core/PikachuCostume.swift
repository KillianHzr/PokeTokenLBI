import Foundation

/// Pikachu's costumes and caps. They are worn over Pikachu's look and are not forms: an egg never rolls them, and the
/// Pokédex's form count leaves them out. Each Pikachu that arrives brings one the player doesn't have yet, and the one
/// equipped on Pikachu's Pokédex page shows wherever Pikachu does.
enum PikachuCostume: String, CaseIterable, Codable, Sendable {
    case rockStar = "rock-star", belle, popStar = "pop-star", phd, libre, cosplay
    case originalCap = "original-cap", hoennCap = "hoenn-cap", sinnohCap = "sinnoh-cap", unovaCap = "unova-cap"
    case kalosCap = "kalos-cap", alolaCap = "alola-cap", partnerCap = "partner-cap", worldCap = "world-cap"
    case partner = "starter"

    static let speciesID = 25

    /// The PokéAPI variety whose sprites show the costume (`10080.gif` for the Rock Star).
    var pokemonID: Int {
        switch self {
        case .rockStar: return 10080
        case .belle: return 10081
        case .popStar: return 10082
        case .phd: return 10083
        case .libre: return 10084
        case .cosplay: return 10085
        case .originalCap: return 10094
        case .hoennCap: return 10095
        case .sinnohCap: return 10096
        case .unovaCap: return 10097
        case .kalosCap: return 10098
        case .alolaCap: return 10099
        case .partnerCap: return 10148
        case .partner: return 10158
        case .worldCap: return 10160
        }
    }

    /// The costume as a look Pikachu's sprites take (`PokemonForm.assetName`).
    var form: PokemonForm { PokemonForm(rawValue) }

    init?(speciesID: Int, form: PokemonForm?) {
        guard speciesID == Self.speciesID, let form, let costume = PikachuCostume(rawValue: form.rawValue) else { return nil }
        self = costume
    }

    /// The costume Pikachu wears everywhere it shows, set by the companion store from the save.
    @MainActor static var equipped: PikachuCostume?

    /// Pikachu in its own look, whatever it wears: the picker's "None".
    static let plain = PokemonForm("plain")

    /// The look a sprite of `speciesID` shows. Pikachu has no form of its own, so any other look asked for (its line's
    /// "normal" or "alola") is its usual one: it shows in its equipped costume, unless a costume or `plain` is asked.
    @MainActor
    static func displayForm(speciesID: Int?, form: PokemonForm?) -> PokemonForm? {
        guard speciesID == Self.speciesID else { return form }
        if form == plain { return nil }
        if PikachuCostume(speciesID: Self.speciesID, form: form) != nil { return form }
        // A Pokémon GO costume is worn for good (`CostumeCatalog`).
        if CostumeCatalog.parse(form) != nil { return form }
        // A battle form is its own look: a Gigantamax Pikachu wears no costume.
        if BattleForms.form(speciesID: Self.speciesID, form: form) != nil { return form }
        return equipped?.form ?? form
    }

    /// A costume not owned yet, chosen by `seed`; nil once every costume is owned.
    static func next(owned: Set<PikachuCostume>, seed: UInt64) -> PikachuCostume? {
        let missing = allCases.filter { !owned.contains($0) }
        guard !missing.isEmpty else { return nil }
        return missing[Int(seed % UInt64(missing.count))]
    }
}

extension L {
    func pikachuCostumeName(_ costume: PikachuCostume) -> String {
        switch costume {
        case .rockStar: return t("하드록", "Rock Star", "ハードロック", "Roquera", "Rockeur", "Roqueira", "Rocker", "Рок-звезда")
        case .belle: return t("마담", "Belle", "マダム", "Aristócrata", "Lady", "Dama", "Damen", "Леди")
        case .popStar: return t("아이돌", "Pop Star", "アイドル", "Superstar", "Star", "Pop Star", "Star", "Поп-звезда")
        case .phd: return t("닥터", "Ph.D.", "ドクター", "Erudita", "Docteur", "Ph.D.", "Professor", "Доктор")
        case .libre: return t("마스크드", "Libre", "マスクド", "Enmascarada", "Catcheur", "Lutadora", "Wrestler", "Рестлер")
        case .cosplay: return t("옷갈아입기", "Cosplay", "おきがえ", "Coqueta", "Cosplayeur", "Cosplay", "Cosplay", "Косплей")
        case .originalCap: return t("오리지널캡", "Original Cap", "オリジナルキャップ", "Gorra Original", "Casquette Originale",
                                    "Boné Original", "Original-Kappe", "Оригинальная кепка")
        case .hoennCap: return t("호연캡", "Hoenn Cap", "ホウエンキャップ", "Gorra Hoenn", "Casquette de Hoenn", "Boné de Hoenn",
                                 "Hoenn-Kappe", "Кепка Хоэнна")
        case .sinnohCap: return t("신오캡", "Sinnoh Cap", "シンオウキャップ", "Gorra Sinnoh", "Casquette de Sinnoh", "Boné de Sinnoh",
                                  "Sinnoh-Kappe", "Кепка Синно")
        case .unovaCap: return t("하나캡", "Unova Cap", "イッシュキャップ", "Gorra Teselia", "Casquette d'Unys", "Boné de Unova",
                                 "Einall-Kappe", "Кепка Юновы")
        case .kalosCap: return t("칼로스캡", "Kalos Cap", "カロスキャップ", "Gorra Kalos", "Casquette de Kalos", "Boné de Kalos",
                                 "Kalos-Kappe", "Кепка Калоса")
        case .alolaCap: return t("알로라캡", "Alola Cap", "アローラキャップ", "Gorra Alola", "Casquette d'Alola", "Boné de Alola",
                                 "Alola-Kappe", "Кепка Алолы")
        case .partnerCap: return t("너로정했다캡", "Partner Cap", "キミにきめたキャップ", "Gorra Compañero", "Casquette Partenaire",
                                   "Boné Parceiro", "Partner-Kappe", "Кепка партнёра")
        case .worldCap: return t("월드캡", "World Cap", "ワールドキャップ", "Gorra Mundial", "Casquette Monde", "Boné Mundial",
                                 "Weltenkappe", "Мировая кепка")
        case .partner: return formPartner
        }
    }
    var pikachuCostumesTitle: String {
        t("피카츄의 옷", "Pikachu's costumes", "ピカチュウのいしょう", "Trajes de Pikachu", "Costumes de Pikachu",
          "Fantasias do Pikachu", "Pikachus Kostüme", "Костюмы Пикачу")
    }
    func pikachuCostumesProgress(_ count: Int, of total: Int) -> String {
        t("\(count)/\(total) 모음", "\(count) of \(total) collected", "\(count)/\(total) 収集", "\(count) de \(total) reunidos",
          "\(count) sur \(total) obtenus", "\(count) de \(total) coletadas", "\(count) von \(total) gesammelt",
          "Собрано: \(count) из \(total)")
    }
    var pikachuCostumesHint: String {
        t("피카츄가 올 때마다 아직 없는 옷을 하나 받아요. 하나를 고르면 피카츄가 어디서나 그 옷을 입어요.",
          "Each Pikachu that arrives brings a costume you don't have yet. Pick one and Pikachu wears it everywhere.",
          "ピカチュウが来るたびに、まだない衣装をひとつもらえます。選んだ衣装をピカチュウがどこでも着ます。",
          "Cada Pikachu que llega trae un traje que aún no tienes. Elige uno y Pikachu lo llevará en todas partes.",
          "Chaque Pikachu qui arrive apporte un costume que tu n'as pas encore. Choisis-en un, Pikachu le porte partout.",
          "Cada Pikachu que chega traz uma fantasia que você ainda não tem. Escolha uma e o Pikachu a usa em todo lugar.",
          "Jedes Pikachu, das ankommt, bringt ein Kostüm, das dir noch fehlt. Wähle eins, und Pikachu trägt es überall.",
          "Каждый новый Пикачу приносит костюм, которого у вас ещё нет. Выберите один, и Пикачу будет носить его везде.")
    }
    var pikachuNoCostume: String { t("없음", "None", "なし", "Ninguno", "Aucun", "Nenhuma", "Keins", "Без костюма") }
    var notifPikachuCostumeTitle: String {
        t("새 옷!", "A new costume!", "あたらしい いしょう！", "¡Un traje nuevo!", "Un nouveau costume !", "Uma fantasia nova!",
          "Ein neues Kostüm!", "Новый костюм!")
    }
    func notifPikachuCostumeBody(_ name: String) -> String {
        t("피카츄가 \(name) 옷을 가져왔어요. 도감에서 입혀 보세요.", "Pikachu brought the \(name) costume. Dress it up in the Pokédex.",
          "ピカチュウが「\(name)」の衣装を持ってきました。図鑑で着せてみましょう。",
          "Pikachu trajo el traje \(name). Pónselo en la Pokédex.", "Pikachu a apporté le costume \(name). Habille-le dans le Pokédex.",
          "O Pikachu trouxe a fantasia \(name). Vista-o na Pokédex.", "Pikachu hat das Kostüm \"\(name)\" mitgebracht. Zieh es ihm im Pokédex an.",
          "Пикачу принёс костюм \"\(name)\". Наденьте его в покедексе.")
    }
}
