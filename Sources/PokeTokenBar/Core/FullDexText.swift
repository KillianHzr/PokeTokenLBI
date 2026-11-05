import Foundation

/// The words of the whole Pokédex (`FullDexView`): its views and what a species not caught says.
extension L {
    func dexScope(_ scope: PopoverNavigation.DexScope) -> String {
        switch scope {
        case .all: return t("전체", "All", "すべて", "Todos", "Tous", "Todos", "Alle", "Все")
        case .caught: return t("보유", "Caught", "入手済み", "Obtenidos", "Obtenus", "Obtidos", "Gefangen", "Пойманы")
        case .missing: return t("미보유", "Missing", "未入手", "Faltan", "Manquants", "Faltando", "Fehlend", "Не хватает")
        }
    }

    func dexMissingHint(_ id: Int) -> String {
        t("#\(id) 아직 도감에 없어요", "#\(id) not in your Pokédex yet", "#\(id) まだ図鑑にいません", "#\(id) aún no está en tu Pokédex",
          "#\(id) pas encore dans ton Pokédex", "#\(id) ainda não está na sua Pokédex", "#\(id) noch nicht in deinem Pokédex",
          "#\(id) ещё нет в покедексе")
    }

    /// How a species not caught yet comes, and what it counts for (7.5), on hovering its silhouette. `name`: the name of
    /// a species owned, or its number; a name not caught stays hidden.
    func dexHowToGet(_ id: Int, source: CompanionStore.SpeciesSource, name: (Int) -> String,
                     goals: [CompanionStore.ActiveGoal], nextDig: (count: Int, needed: Int)?) -> String {
        var lines: [String] = []
        switch source {
        case .evolves(let parent, _):
            let from = name(parent)
            lines.append(t("#\(id) · \(from)에서 진화", "#\(id) · evolves from \(from)", "#\(id) · \(from)から進化",
                           "#\(id) · evoluciona de \(from)", "#\(id) · évolue de \(from)", "#\(id) · evolui de \(from)",
                           "#\(id) · entwickelt sich aus \(from)", "#\(id) · эволюционирует из \(from)"))
            lines.append(t("이 계열을 이 단계까지 키워요.", "Raise its line up to it.", "この系統をここまで育てましょう。",
                           "Cría su línea hasta él.", "Fais grandir sa lignée jusqu'à lui.", "Crie a linha dele até ele.",
                           "Zieh seine Linie bis zu ihm auf.", "Вырастите его линию до него."))
        case .fossil:
            let egg = itemName(.fossilEgg), dig = itemName(.excavation)
            lines.append(t("#\(id) · 화석 계열", "#\(id) · fossil line", "#\(id) · 化石の系統", "#\(id) · línea fósil",
                           "#\(id) · lignée fossile", "#\(id) · linha fóssil", "#\(id) · Fossil-Linie", "#\(id) · линия окаменелостей"))
            let progress = nextDig.map { " (\($0.count)/\($0.needed))" } ?? ""
            lines.append(t("\(dig)에서 얻는 \(egg)에서 태어나요\(progress).", "Hatches from a \(egg), won at the \(dig)\(progress).",
                           "\(dig)で手に入る\(egg)から生まれます\(progress)。", "Sale de un \(egg), ganado en la \(dig)\(progress).",
                           "Sort d'un \(egg), gagné aux \(dig)\(progress).", "Nasce de um \(egg), ganho na \(dig)\(progress).",
                           "Schlüpft aus einem \(egg) der \(dig)\(progress).", "Вылупляется из \"\(egg)\" за \"\(dig)\"\(progress)."))
        case .dungeon(let dungeon):
            let place = dungeonName(dungeon)
            lines.append(dexMissingHint(id))
            lines.append(t("\(place)의 보스로만 나와요. 잡으면 알을 얻어요.", "Only the \(place)'s boss: catch it for its egg.",
                           "\(place)のボスとしてだけあらわれます。つかまえるとタマゴが手に入ります。",
                           "Solo como jefe de \(place): captúralo para tener su huevo.",
                           "Seulement en boss de donjon (\(place)) : capture-le pour avoir son œuf.",
                           "Só como chefe de \(place): capture-o para ganhar o ovo.",
                           "Nur als Boss von \(place): Fang es für sein Ei.",
                           "Только босс локации \"\(place)\": поймай его, чтобы получить яйцо."))
        case .legendary:
            let egg = itemName(.legendaryEgg)
            lines.append(t("#\(id) · 전설", "#\(id) · legendary", "#\(id) · 伝説", "#\(id) · legendario", "#\(id) · légendaire",
                           "#\(id) · lendário", "#\(id) · legendär", "#\(id) · легендарный"))
            lines.append(t("\(egg)(지역 업적)이나, 드물게 일반 알에서 태어나요.", "Hatches from a \(egg) (a region's achievement), or rarely from any egg.",
                           "\(egg)（地方の実績）から、またはまれにふつうのタマゴから生まれます。",
                           "Sale de un \(egg) (logro de una región), o rara vez de un huevo cualquiera.",
                           "Sort d'un \(egg) (succès d'une région), ou rarement d'un œuf ordinaire.",
                           "Nasce de um \(egg) (conquista de uma região), ou raramente de um ovo qualquer.",
                           "Schlüpft aus einem \(egg) (Erfolg einer Region) oder selten aus einem gewöhnlichen Ei.",
                           "Вылупляется из \"\(egg)\" (достижение региона) или изредка из обычного яйца."))
        case .mythical:
            let birthday = itemName(.birthdayEgg), legendary = itemName(.legendaryEgg)
            lines.append(t("#\(id) · 환상", "#\(id) · mythical", "#\(id) · 幻", "#\(id) · singular", "#\(id) · fabuleux",
                           "#\(id) · mítico", "#\(id) · mysteriös", "#\(id) · мифический"))
            lines.append(t("\(KoreanParticle.subject.attach(to: birthday)) 환상 포켓몬부터 줘요. \(legendary)이나 드물게 일반 알에서도 나와요.",
                           "The \(birthday) gives mythicals first; also a \(legendary), or rarely any egg.",
                           "\(birthday)は幻のポケモンを先にくれます。\(legendary)や、まれにふつうのタマゴからも。",
                           "El \(birthday) da primero los singulares; también un \(legendary), o rara vez un huevo cualquiera.",
                           "L'\(birthday) donne d'abord les fabuleux ; aussi l'\(legendary), ou rarement un œuf ordinaire.",
                           "O \(birthday) dá os míticos primeiro; também um \(legendary), ou raramente um ovo qualquer.",
                           "Das \(birthday) bringt zuerst mysteriöse Pokémon; auch ein \(legendary) oder selten ein gewöhnliches Ei.",
                           "\"\(birthday)\" сначала даёт мифических; также \"\(legendary)\" или изредка обычное яйцо."))
        case .egg:
            lines.append(dexMissingHint(id))
            lines.append(t("알에서 태어나요.", "Hatches from an egg.", "タマゴから生まれます。", "Sale de un huevo.",
                           "Sort d'un œuf.", "Nasce de um ovo.", "Schlüpft aus einem Ei.", "Вылупляется из яйца."))
        }
        if !goals.isEmpty {
            let list = goals.prefix(2).map { "\(activeGoalName($0)) \($0.count)/\($0.needed)" }.joined(separator: " · ")
            lines.append("\(countsFor): \(list)")
        }
        return lines.joined(separator: "\n")
    }

    func dexShinySpecies(_ count: Int) -> String {
        let one = count == 1
        return t("이로치 \(count)종", "\(count) shiny species", "色違い\(count)種",
                 one ? "1 especie variocolor" : "\(count) especies variocolor",
                 one ? "1 espèce chromatique" : "\(count) espèces chromatiques",
                 one ? "1 espécie brilhante" : "\(count) espécies brilhantes",
                 one ? "1 schillernde Art" : "\(count) schillernde Arten", "Сияющих видов: \(count)")
    }

    func dexPercent(_ percent: Int) -> String {
        t("\(percent)% 완성", "\(percent)% complete", "\(percent)%完成", "\(percent) % completado", "\(percent) % complété",
          "\(percent)% completo", "\(percent) % vollständig", "Собрано \(percent)%")
    }
}
