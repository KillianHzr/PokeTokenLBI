import Foundation

/// The villains' words (issue #180), in the app's eight languages. A team's name is said with no article to agree with:
/// "Cible : Œuf rare", never "ton Œuf rare".
extension L {
    func villainTeamName(_ team: VillainTeam) -> String {
        switch team {
        case .rocket: t("로켓단", "Team Rocket", "ロケット団", "Team Rocket", "Team Rocket", "Equipe Rocket", "Team Rocket", "Команда R")
        case .aqua: t("아쿠아단", "Team Aqua", "アクア団", "Equipo Aqua", "Team Aqua", "Equipe Aqua", "Team Aqua", "Команда Аква")
        case .magma: t("마그마단", "Team Magma", "マグマ団", "Equipo Magma", "Team Magma", "Equipe Magma", "Team Magma", "Команда Магма")
        case .galactic: t("갤럭시단", "Team Galactic", "ギンガ団", "Equipo Galaxia", "Team Galaxie", "Equipe Galáctica",
                          "Team Galaktik", "Команда Галактика")
        case .plasma: t("플라스마단", "Team Plasma", "プラズマ団", "Equipo Plasma", "Team Plasma", "Equipe Plasma", "Team Plasma",
                        "Команда Плазма")
        case .flare: t("플레어단", "Team Flare", "フレア団", "Team Flare", "Team Flare", "Equipe Flare", "Team Flare", "Команда Флэр")
        case .skull: t("스컬단", "Team Skull", "スカル団", "Team Skull", "Team Skull", "Equipe Skull", "Team Skull", "Команда Скалл")
        }
    }

    func villainLeaderName(_ team: VillainTeam) -> String {
        switch team {
        case .rocket: t("비주기", "Giovanni", "サカキ", "Giovanni", "Giovanni", "Giovanni", "Giovanni", "Джованни")
        case .aqua: t("아강", "Archie", "アオギリ", "Aquiles", "Arthur", "Archie", "Adrian", "Арчи")
        case .magma: t("마적", "Maxie", "マツブサ", "Magno", "Max", "Maxie", "Marc", "Макси")
        case .galactic: t("태홍", "Cyrus", "アカギ", "Helio", "Hélio", "Cyrus", "Zyrus", "Сайрус")
        case .plasma: t("게치스", "Ghetsis", "ゲーチス", "Ghechis", "Ghetis", "Ghetsis", "G-Cis", "Гетсис")
        case .flare: t("플라드리", "Lysandre", "フラダリ", "Lysson", "Lysandre", "Lysandre", "Flordelis", "Лисандр")
        case .skull: t("구즈마", "Guzma", "グズマ", "Guzmán", "Guzma", "Guzma", "Bromley", "Гузма")
        }
    }

    func villainAmbushTitle(_ team: VillainTeam) -> String {
        let n = villainTeamName(team)
        return t("\(n)의 습격!", "\(n) ambush!", "\(n)の襲撃！", "¡Emboscada: \(n)!", "Embuscade : \(n) !", "Emboscada: \(n)!",
                 "Hinterhalt: \(n)!", "Засада: \(n)!")
    }

    func villainAmbushLine(_ team: VillainTeam, item: String) -> String {
        t("가방의 아이템을 노리고 있어요: \(item).", "They are after an item in your Bag: \(item).",
          "バッグのどうぐを狙っています：\(item)。", "Van a por un objeto de tu bolsa: \(item).",
          "Ils visent un objet de ton sac : \(item).", "Estão atrás de um item da sua bolsa: \(item).",
          "Sie haben es auf ein Item in deinem Beutel abgesehen: \(item).", "Они охотятся за предметом из вашей сумки: \(item).")
    }

    var villainTarget: String { t("노리는 것", "Target", "ねらい", "Objetivo", "Cible", "Alvo", "Ziel", "Цель") }
    var villainTheirPokemon: String {
        t("그들의 포켓몬", "Their Pokémon", "相手のポケモン", "Sus Pokémon", "Leurs Pokémon", "Os Pokémon deles", "Ihre Pokémon",
          "Их покемоны")
    }
    var villainDefend: String { t("맞서기", "Defend", "迎え撃つ", "Defenderse", "Se défendre", "Defender", "Verteidigen", "Защищаться") }
    var villainDefendWith: String {
        t("내 팀으로 싸워요. 지면 아이템을 아지트로 가져가요.", "Your team fights; lose and they take the item to their hideout.",
          "マイチームが戦います。負けると、どうぐをアジトに持ち去られます。",
          "Lucha tu equipo; si pierdes, se llevan el objeto a su guarida.",
          "Ton équipe se bat ; si elle perd, ils emportent l'objet dans leur repaire.",
          "Sua equipe luta; se perder, levam o item para o esconderijo.",
          "Dein Team kämpft; verliert es, bringen sie das Item in ihr Versteck.",
          "Сражается ваша команда; проиграете, и предмет унесут в логово.")
    }

    func villainBeaten(_ team: VillainTeam) -> String {
        let n = villainTeamName(team)
        return t("\(KoreanParticle.subject.attach(to: n)) 날아가 버렸다!", "\(n) is blasting off again!", "\(n)は 飛んでいった！", "¡\(n) sale volando otra vez!",
                 "\(n) s'envole vers d'autres cieux !", "\(n) decolando outra vez!", "\(n) fliegt davon!", "\(n) улетает прочь!")
    }

    func villainGotAway(_ team: VillainTeam, item: String) -> String {
        let n = villainTeamName(team)
        return t("\(KoreanParticle.subject.attach(to: n)) 빼앗아 갔어요: \(item). 던전 탭의 아지트에서 되찾으세요.",
                 "\(n) got away with: \(item). Take it back at their hideout, in Dungeons.",
                 "\(n)に奪われました：\(item)。ダンジョンのアジトで取り返しましょう。",
                 "\(n) se lo ha llevado: \(item). Recupéralo en su guarida, en Mazmorras.",
                 "\(n) s'est enfuie avec : \(item). Reprends-le dans son repaire, onglet Donjons.",
                 "\(n) fugiu com: \(item). Recupere no esconderijo, em Masmorras.",
                 "\(n) ist damit entkommen: \(item). Hol es dir in ihrem Versteck zurück, unter Dungeons.",
                 "\(n) скрылась с добычей: \(item). Верните её в логове, во вкладке подземелий.")
    }

    var villainSeeFight: String {
        t("전투 다시 보기", "Watch the fight", "バトルを見る", "Ver el combate", "Revoir le combat", "Ver a batalha", "Kampf ansehen",
          "Смотреть бой")
    }
    var villainToHideout: String {
        t("아지트로", "To the hideout", "アジトへ", "A la guarida", "Aller au repaire", "Ir ao esconderijo", "Zum Versteck", "В логово")
    }

    func villainHideoutName(_ team: VillainTeam) -> String {
        let n = villainTeamName(team)
        return t("\(n) 아지트", "\(n) Hideout", "\(n)のアジト", "Guarida del \(n)", "Repaire de la \(n)", "Esconderijo da \(n)",
                 "Versteck von \(n)", "Логово: \(n)")
    }

    var villainKeeps: String { t("빼앗긴 것", "They keep", "奪われたもの", "Se quedan con", "Ils gardent", "Eles guardam",
                                 "Sie behalten", "У них") }

    func villainWaitsAtTheEnd(_ team: VillainTeam, tier: DungeonTier) -> String {
        if team.bossIsLeader(tier) {
            let n = villainLeaderName(team)
            return t("끝에서 \(KoreanParticle.subject.attach(to: n)) 포켓몬 3마리와 기다려요.", "\(n) waits at the end with three Pokémon.",
                     "最後に\(n)がポケモン3匹と待っています。", "\(n) espera al final con tres Pokémon.",
                     "\(n) t'attend au bout avec trois Pokémon.", "\(n) espera no fim com três Pokémon.",
                     "\(n) wartet am Ende mit drei Pokémon.", "В конце ждёт \(n) с тремя покемонами.")
        }
        return t("끝에서 조무래기 대장이 포켓몬 3마리와 기다려요.", "A grunt boss waits at the end with three Pokémon.",
                 "最後に下っ端のリーダーがポケモン3匹と待っています。", "Un jefe de reclutas espera al final con tres Pokémon.",
                 "Un chef des sbires t'attend au bout avec trois Pokémon.", "Um chefe dos recrutas espera no fim com três Pokémon.",
                 "Ein Rüpel-Anführer wartet am Ende mit drei Pokémon.", "В конце ждёт главарь с тремя покемонами.")
    }

    var villainTakenBack: String {
        t("되찾은 것", "Taken back", "取り返したもの", "Recuperado", "Récupéré", "Recuperado", "Zurückgeholt", "Возвращено")
    }
}
