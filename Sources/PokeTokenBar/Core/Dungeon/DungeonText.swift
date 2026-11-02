import Foundation

/// The words of the dungeons, in the app's eight languages.
extension L {
    var dungeonItemHint: String {
        t("던전용", "For dungeons", "ダンジョン用", "Para mazmorras", "Pour les donjons", "Para masmorras", "Für Dungeons",
          "Для подземелий")
    }

    /// A dungeon's egg, on Home while it incubates: the Bag names its Pokémon.
    var dungeonEggName: String {
        t("던전의 알", "Dungeon Egg", "ダンジョンのタマゴ", "Huevo de mazmorra", "Œuf de donjon", "Ovo de masmorra",
          "Dungeon-Ei", "Яйцо из подземелья")
    }

    /// Prof. Oak's note while a team explores: the Pokémon raised waits.
    func oakDungeonPause(_ name: String, _ dungeon: String) -> String {
        t("팀이 \(KoreanParticle.object.attach(to: dungeon)) 탐험하는 동안 \(KoreanParticle.subject.attach(to: name)) 자라지 않아요. 이상한 사탕은 그대로 쓸 수 있어요.",
          "While your team explores \(dungeon), \(name) doesn't grow. Rare Candies still work.",
          "チームが\(dungeon)を探検しているあいだ、\(name)は育ちません。ふしぎなアメは使えます。",
          "Mientras tu equipo explora \(dungeon), \(name) no crece. Los Caramelos Raros siguen funcionando.",
          "Tant que ton équipe explore \(dungeon), \(name) ne grandit pas. Les Super Bonbons marchent toujours.",
          "Enquanto sua equipe explora \(dungeon), \(name) não cresce. Os Doces Raros continuam funcionando.",
          "Solange dein Team \(dungeon) erkundet, wächst \(name) nicht. Sonderbonbons wirken weiterhin.",
          "Пока команда исследует \"\(dungeon)\", \(name) не растёт. Редкие конфеты по-прежнему работают.")
    }

    func oakDungeonPauseEgg(_ dungeon: String) -> String {
        t("팀이 \(KoreanParticle.object.attach(to: dungeon)) 탐험하는 동안 알은 부화하지 않아요.",
          "While your team explores \(dungeon), your egg doesn't hatch.",
          "チームが\(dungeon)を探検しているあいだ、タマゴはかえりません。",
          "Mientras tu equipo explora \(dungeon), tu huevo no eclosiona.",
          "Tant que ton équipe explore \(dungeon), ton œuf n'éclot pas.",
          "Enquanto sua equipe explora \(dungeon), seu ovo não choca.",
          "Solange dein Team \(dungeon) erkundet, schlüpft dein Ei nicht.",
          "Пока команда исследует \"\(dungeon)\", яйцо не вылупляется.")
    }

    var dungeonsTab: String {
        t("던전", "Dungeons", "ダンジョン", "Mazmorras", "Donjons", "Masmorras", "Dungeons", "Подземелья")
    }

    /// The tiers' names (Découverte to Origine).
    func dungeonTierName(_ tier: DungeonTier) -> String {
        switch tier {
        case .t1: t("발견", "Discovery", "はっけん", "Descubrimiento", "Découverte", "Descoberta", "Entdeckung", "Открытие")
        case .t2: t("모험", "Adventure", "ぼうけん", "Aventura", "Aventure", "Aventura", "Abenteuer", "Приключение")
        case .t3: t("숙련", "Expert", "エキスパート", "Experto", "Expert", "Especialista", "Experte", "Эксперт")
        case .t4: t("전설", "Legends", "でんせつ", "Leyendas", "Légendes", "Lendas", "Legenden", "Легенды")
        case .t5: t("기원", "Origin", "はじまり", "Origen", "Origine", "Origem", "Ursprung", "Исток")
        }
    }

    func dungeonRule(_ rule: DungeonRule) -> String {
        switch rule {
        case .noLegendary: t("전설 없음", "No legendary", "でんせつなし", "Ningún legendario", "Aucun légendaire",
                             "Nenhum lendário", "Kein Legendäres", "Без легендарных")
        case .atMostOneLegendary: t("전설 1마리까지", "One legendary at most", "でんせつは1ひきまで", "Un legendario como mucho",
                                    "1 légendaire au plus", "No máximo 1 lendário", "Höchstens ein Legendäres",
                                    "Не больше одного легендарного")
        case .onlyLegendaries: t("전설만", "Legendaries only", "でんせつのみ", "Solo legendarios", "Que des légendaires",
                                 "Só lendários", "Nur Legendäre", "Только легендарные")
        case .onlyStarters: t("스타팅만", "Starters only", "さいしょのポケモンのみ", "Solo iniciales", "Que des starters",
                              "Só iniciais", "Nur Starter", "Только стартовые")
        case .sharedType: t("같은 타입 하나", "One shared type", "共通のタイプ", "Un tipo en común", "Un type en commun",
                            "Um tipo em comum", "Ein gemeinsamer Typ", "Общий тип")
        case .oneRegion: t("한 지방", "One region", "ひとつの地方", "Una sola región", "Une seule région", "Uma só região",
                           "Eine Region", "Один регион")
        case .maxRarity(.common): t("일반만", "Commons only", "コモンのみ", "Solo comunes", "Que des communs", "Só comuns",
                                    "Nur Gewöhnliche", "Только обычные")
        case .maxRarity(let rarity): t("최대 \(rarityLabel(rarity))", "\(rarityLabel(rarity)) at most",
                                       "\(rarityLabel(rarity))まで", "Como mucho \(rarityLabel(rarity))",
                                       "Au plus \(rarityLabel(rarity))", "No máximo \(rarityLabel(rarity))",
                                       "Höchstens \(rarityLabel(rarity))", "Не выше: \(rarityLabel(rarity))")
        case .bannedType(let type): t("\(typeName(type)) 타입 금지", "No \(typeName(type)) type", "\(typeName(type))タイプ禁止",
                                      "Tipo \(typeName(type)) prohibido", "Type \(typeName(type)) interdit",
                                      "Tipo \(typeName(type)) proibido", "Kein Typ \(typeName(type))",
                                      "Тип \(typeName(type)) запрещён")
        case .onlyShinies: t("이로치만", "Shinies only", "色違いのみ", "Solo variocolor", "Que des chromatiques", "Só shiny",
                             "Nur Schillernde", "Только шайни")
        }
    }

    func dungeonUnlock(_ unlock: DungeonUnlock) -> String {
        switch unlock {
        case .graduated(let n): t("졸업한 포켓몬 \(n)마리", "\(n) graduated Pokémon", "卒業したポケモン\(n)ひき",
                                  "\(n) Pokémon graduados", "\(n) Pokémon diplômés", "\(n) Pokémon formados",
                                  "\(n) verabschiedete Pokémon", "Выпускников: \(n)")
        case .won(let id): t("\(dungeonName(id)) 클리어", "Finish \(dungeonName(id))", "\(dungeonName(id))をクリア",
                             "Superar \(dungeonName(id))", "Finir \(dungeonName(id))", "Concluir \(dungeonName(id))",
                             "\(dungeonName(id)) abschließen", "Пройти: \(dungeonName(id))")
        case .linesGraduated(let n): t("졸업한 계열 \(n)개", "\(n) lines graduated", "卒業した系統\(n)",
                                       "\(n) líneas graduadas", "\(n) lignées diplômées", "\(n) linhas formadas",
                                       "\(n) verabschiedete Linien", "Линий выпущено: \(n)")
        case .legendariesGraduated(let n): t("졸업한 전설 \(n)마리", "\(n) legendaries graduated", "卒業したでんせつ\(n)ひき",
                                             "\(n) legendarios graduados", "\(n) légendaires diplômés",
                                             "\(n) lendários formados", "\(n) verabschiedete Legendäre",
                                             "Легендарных выпущено: \(n)")
        case .beatBosses: t("천관산의 세 보스 쓰러뜨리기", "Beat Mt. Coronet's three bosses", "テンガンざんの3体のボスを倒す",
                            "Vencer a los tres jefes del Monte Corona", "Battre les trois boss du Mont Couronné",
                            "Vencer os três chefes do Monte Coronet", "Die drei Bosse des Kraterbergs besiegen",
                            "Победить трёх боссов горы Коронет")
        case .treasureMap: t("보물지도 1장", "A Treasure Map", "たからのちず1まい", "Un Mapa del Tesoro", "Une Carte au trésor",
                             "Um Mapa do Tesouro", "Eine Schatzkarte", "Карта сокровищ")
        }
    }

    var dungeonPrepare: String { t("준비", "Prepare", "じゅんび", "Preparar", "Préparer", "Preparar", "Vorbereiten", "Подготовить") }
    var dungeonGoAgain: String { t("다시 출발", "Go again", "もう一度", "Volver", "Repartir", "Ir de novo", "Erneut los", "Снова") }
    var dungeonLocked: String { t("잠김", "Locked", "ロック中", "Bloqueada", "Verrouillé", "Bloqueada", "Gesperrt", "Закрыто") }
    var dungeonNew: String { t("새로움", "New", "NEW", "Nueva", "Nouveau", "Nova", "Neu", "Новое") }
    func dungeonWins(_ n: Int) -> String {
        t("클리어 ×\(n)", "Finished ×\(n)", "クリア ×\(n)", "Superada ×\(n)", "Finie ×\(n)", "Concluída ×\(n)",
          "Geschafft ×\(n)", "Пройдено ×\(n)")
    }
    var dungeonBossUnknown: String {
        t("보스: 아직 못 봄", "Boss: never seen", "ボス：まだ見ていない", "Jefe: nunca visto", "Boss : jamais vu",
          "Chefe: nunca visto", "Boss: nie gesehen", "Босс: не встречен")
    }
    func dungeonEntryKeys(_ n: Int, key: String) -> String {
        t("입장: \(key) \(n)개", "Entry: \(n) × \(key)", "入場：\(key)×\(n)", "Entrada: \(n) × \(key)",
          "Entrée : \(n) × \(key)", "Entrada: \(n) × \(key)", "Eintritt: \(n) × \(key)", "Вход: \(key) ×\(n)")
    }
    func dungeonEntryMap(_ map: String) -> String {
        t("입장: \(map) 1장", "Entry: a \(map)", "入場：\(map)1まい", "Entrada: un \(map)", "Entrée : une \(map)",
          "Entrada: um \(map)", "Eintritt: eine \(map)", "Вход: \(map)")
    }
    func dungeonUnderway(_ dungeon: String, floor: Int, floors: Int) -> String {
        t("탐험 중: \(dungeon) · \(floor)/\(floors)층", "Exploring \(dungeon) · floor \(floor) of \(floors)",
          "探検中：\(dungeon)・\(floor)/\(floors)階", "Explorando \(dungeon) · piso \(floor) de \(floors)",
          "En expédition : \(dungeon) · étage \(floor) sur \(floors)", "Explorando \(dungeon) · andar \(floor) de \(floors)",
          "Erkundung: \(dungeon) · Ebene \(floor) von \(floors)", "Экспедиция: \(dungeon) · этаж \(floor) из \(floors)")
    }
    var dungeonSee: String { t("보기", "See", "見る", "Ver", "Voir", "Ver", "Ansehen", "Открыть") }
    var dungeonOneAtATime: String {
        t("탐험은 한 번에 하나", "One expedition at a time", "探検は一度にひとつ", "Una expedición a la vez",
          "Une expédition à la fois", "Uma expedição por vez", "Eine Erkundung auf einmal", "Одна экспедиция за раз")
    }
    func dungeonTeamSize(_ n: Int) -> String {
        t("포켓몬 \(n)마리", "\(n) Pokémon", "ポケモン\(n)ひき", "\(n) Pokémon", "\(n) Pokémon", "\(n) Pokémon",
          "\(n) Pokémon", "\(n) покемонов")
    }

    // MARK: The team screen

    var dungeonComposeForMe: String {
        t("자동 편성", "Compose for me", "おまかせ編成", "Componer por mí", "Composer pour moi", "Montar para mim",
          "Für mich zusammenstellen", "Собрать за меня")
    }
    var dungeonSetOff: String { t("출발", "Set off", "出発", "Partir", "Partir", "Partir", "Aufbrechen", "В путь") }
    var dungeonReachOdds: String {
        t("보스까지 갈 확률", "Odds of reaching the boss", "ボスまでたどり着く確率", "Probabilidad de llegar al jefe",
          "Chances d'atteindre le boss", "Chance de chegar ao chefe", "Chance, den Boss zu erreichen",
          "Шанс дойти до босса")
    }
    var dungeonRules: String { t("규칙", "Rules", "ルール", "Reglas", "Règles", "Regras", "Regeln", "Правила") }
    var dungeonCandidates: String {
        t("졸업한 포켓몬", "Graduated Pokémon", "卒業したポケモン", "Pokémon graduados", "Pokémon diplômés", "Pokémon formados",
          "Verabschiedete Pokémon", "Выпускники")
    }
    var dungeonNoCandidate: String {
        t("이 규칙에 맞는 포켓몬이 없어요.", "No Pokémon fits these rules.", "このルールに合うポケモンがいません。",
          "Ningún Pokémon cumple estas reglas.", "Aucun Pokémon ne respecte ces règles.", "Nenhum Pokémon segue essas regras.",
          "Kein Pokémon passt zu diesen Regeln.", "Ни один покемон не подходит под правила.")
    }
    func dungeonLoopOf(_ name: String) -> String {
        t("\(name)의 공격 순서", "\(name)'s loop", "\(name)のわざの順番", "Bucle de \(name)", "Boucle de \(name)",
          "Ciclo de \(name)", "Schleife von \(name)", "Цикл: \(name)")
    }
    var dungeonLoopHint: String {
        t("공격 4개를 차례로 반복해요. 바꾸려면 하나를 누르세요.", "It casts its four moves in turn, then again. Click one to change it.",
          "4つのわざを順に使い、くりかえします。押すと変えられます。", "Lanza sus cuatro movimientos en orden y vuelve a empezar. Pulsa uno para cambiarlo.",
          "Il lance ses 4 attaques dans l'ordre, puis recommence. Clique sur une attaque pour la changer.",
          "Ele usa os quatro golpes em ordem e recomeça. Clique em um para trocar.",
          "Es setzt seine vier Attacken der Reihe nach ein, dann von vorn. Klicke eine an, um sie zu ändern.",
          "Он применяет четыре атаки по очереди и снова. Нажмите на атаку, чтобы сменить её.")
    }
    var dungeonLockedMove: String {
        t("잠김: 기술 캡슐로 열어요", "Locked: a Technical Capsule unlocks it", "ロック：わざカプセルで解放",
          "Bloqueado: una Cápsula Técnica lo desbloquea", "Verrouillée : une Capsule Technique la débloque",
          "Bloqueado: uma Cápsula Técnica o desbloqueia", "Gesperrt: eine Technik-Kapsel schaltet sie frei",
          "Закрыто: открывается Технической капсулой")
    }
    var dungeonNoEffectMove: String {
        t("던전에서는 효과 없음", "No effect in dungeons", "ダンジョンでは効果なし", "Sin efecto en mazmorras",
          "Sans effet en donjon", "Sem efeito em masmorras", "Im Dungeon wirkungslos", "В подземельях не действует")
    }
    var dungeonSuggestLoop: String {
        t("추천으로 되돌리기", "Back to the suggestion", "おすすめにもどす", "Volver a la sugerencia", "Revenir à la suggestion",
          "Voltar à sugestão", "Zurück zum Vorschlag", "Вернуть рекомендацию")
    }
    func dungeonCast(_ seconds: Double) -> String { String(format: "%.1f s", seconds) }
    var dungeonRemove: String { t("빼기", "Remove", "はずす", "Quitar", "Retirer", "Remover", "Entfernen", "Убрать") }
    var dungeonLoopTitle: String {
        t("공격 순서", "Move loop", "わざの順番", "Bucle de movimientos", "Boucle d'attaques", "Ciclo de golpes",
          "Attackenschleife", "Цикл атак")
    }

    /// A move's card on hover: what the engine plays of it (R4: descriptions and stats on hover).
    func moveDetails(_ move: BattleMove, unlocked: Set<String>) -> String {
        var parts: [String] = [typeName(move.type)]
        switch move.moveClass {
        case .physical: parts.append(t("물리", "Physical", "ぶつり", "Físico", "Physique", "Físico", "Physisch", "Физическая"))
        case .special: parts.append(t("특수", "Special", "とくしゅ", "Especial", "Spéciale", "Especial", "Speziell", "Специальная"))
        case .status: parts.append(t("변화", "Status", "へんか", "Estado", "Statut", "Status", "Status", "Статусная"))
        }
        if move.power > 0 {
            parts.append(t("위력 \(move.power)", "Power \(move.power)", "いりょく \(move.power)", "Potencia \(move.power)",
                           "Puissance \(move.power)", "Poder \(move.power)", "Stärke \(move.power)", "Сила \(move.power)"))
        }
        if move.accuracy > 0 {
            parts.append(t("명중 \(move.accuracy)%", "Accuracy \(move.accuracy)%", "命中 \(move.accuracy)%",
                           "Precisión \(move.accuracy) %", "Précision \(move.accuracy) %", "Precisão \(move.accuracy)%",
                           "Genauigkeit \(move.accuracy) %", "Точность \(move.accuracy)%"))
        }
        if move.priority > 0 {
            parts.append(t("빠른 시전", "Quick to cast", "すばやく出る", "Rápido", "Lancement rapide", "Rápido",
                           "Schnell", "Быстрая"))
        }
        if let ailment = move.ailment {
            let chance = move.ailmentChance > 0 ? move.ailmentChance : move.effectChance
            parts.append(ailmentName(ailment) + (chance > 0 && chance < 100 ? " \(chance)%" : ""))
        }
        for change in move.statChanges {
            parts.append("\(statName(change.stat)) \(change.change > 0 ? "+" : "")\(change.change)")
        }
        if move.healing > 0 {
            parts.append(t("회복 \(move.healing)%", "Heals \(move.healing)%", "回復 \(move.healing)%", "Cura \(move.healing) %",
                           "Soin \(move.healing) %", "Cura \(move.healing)%", "Heilt \(move.healing) %", "Лечит \(move.healing)%"))
        }
        if move.drain > 0 {
            parts.append(t("흡수 \(move.drain)%", "Drains \(move.drain)%", "吸収 \(move.drain)%", "Absorbe \(move.drain) %",
                           "Draine \(move.drain) %", "Drena \(move.drain)%", "Saugt \(move.drain) %", "Поглощает \(move.drain)%"))
        } else if move.drain < 0 {
            parts.append(t("반동 \(-move.drain)%", "Recoil \(-move.drain)%", "反動 \(-move.drain)%", "Retroceso \(-move.drain) %",
                           "Recul \(-move.drain) %", "Recuo \(-move.drain)%", "Rückstoß \(-move.drain) %", "Отдача \(-move.drain)%"))
        }
        if move.flinchChance > 0 {
            parts.append(t("풀죽음 \(move.flinchChance)%", "Flinch \(move.flinchChance)%", "ひるみ \(move.flinchChance)%",
                           "Retroceso \(move.flinchChance) %", "Peur \(move.flinchChance) %", "Hesitar \(move.flinchChance)%",
                           "Zurückschrecken \(move.flinchChance) %", "Испуг \(move.flinchChance)%"))
        }
        if move.maxHits > 1 {
            parts.append(t("\(move.minHits)-\(move.maxHits)회", "\(move.minHits) to \(move.maxHits) hits",
                           "\(move.minHits)〜\(move.maxHits)回", "\(move.minHits) a \(move.maxHits) golpes",
                           "\(move.minHits) à \(move.maxHits) coups", "\(move.minHits) a \(move.maxHits) golpes",
                           "\(move.minHits) bis \(move.maxHits) Treffer", "\(move.minHits)-\(move.maxHits) ударов"))
        }
        if move.hitsAllOpponents {
            parts.append(t("상대 전원 75%", "Every foe, 75%", "相手全員に75%", "Todos los rivales, 75 %",
                           "Tous les adversaires, 75 %", "Todos os oponentes, 75%", "Alle Gegner, 75 %", "Все противники, 75%"))
        }
        if move.charges || move.recharges {
            parts.append(t("시전 +2초", "Cast +2 s", "発動 +2秒", "Carga +2 s", "Lancement +2 s", "Carga +2 s",
                           "Aufladen +2 s", "Подготовка +2 с"))
        }
        if move.isLocked && !unlocked.contains(move.slug) { parts.append(dungeonLockedMove) }
        if !move.hasEffect { parts.append(dungeonNoEffectMove) }
        return parts.joined(separator: " · ")
    }

    func ailmentName(_ ailment: BattleAilment) -> String {
        switch ailment {
        case .burn: t("화상", "Burn", "やけど", "Quemadura", "Brûlure", "Queimadura", "Verbrennung", "Ожог")
        case .paralysis: t("마비", "Paralysis", "まひ", "Parálisis", "Paralysie", "Paralisia", "Paralyse", "Паралич")
        case .sleep: t("잠듦", "Sleep", "ねむり", "Sueño", "Sommeil", "Sono", "Schlaf", "Сон")
        case .freeze: t("얼음", "Freeze", "こおり", "Congelación", "Gel", "Congelamento", "Einfrieren", "Заморозка")
        case .poison, .badPoison: t("독", "Poison", "どく", "Veneno", "Poison", "Veneno", "Gift", "Отравление")
        case .confusion: t("혼란", "Confusion", "こんらん", "Confusión", "Confusion", "Confusão", "Verwirrung", "Смятение")
        case .trap: t("묶기", "Trap", "しめつけ", "Atrapa", "Piège", "Prende", "Fessel", "Захват")
        case .leechSeed: t("씨뿌리기", "Leech Seed", "やどりぎ", "Drenadoras", "Vampigraine", "Semente Sanguessuga", "Egelsamen", "Пиявка")
        case .yawn: t("하품", "Yawn", "あくび", "Bostezo", "Bâillement", "Bocejo", "Gähner", "Зевок")
        }
    }

    func statName(_ stat: BattleStat) -> String {
        switch stat {
        case .attack: t("공격", "Atk", "こうげき", "Atq", "Atq", "Atq", "Angr", "Атк")
        case .defense: t("방어", "Def", "ぼうぎょ", "Def", "Déf", "Def", "Vert", "Защ")
        case .specialAttack: t("특공", "Sp. Atk", "とくこう", "At. Esp", "Atq Spé", "At. Esp", "SpAng", "Сп. атк")
        case .specialDefense: t("특방", "Sp. Def", "とくぼう", "Def. Esp", "Déf Spé", "Def. Esp", "SpVert", "Сп. защ")
        case .speed: t("스피드", "Speed", "すばやさ", "Velocidad", "Vitesse", "Velocidade", "Init", "Скор")
        case .accuracy: t("명중", "Accuracy", "めいちゅう", "Precisión", "Précision", "Precisão", "Genauigkeit", "Точн")
        case .evasion: t("회피", "Evasion", "かいひ", "Evasión", "Esquive", "Evasão", "Ausweichen", "Укл")
        }
    }

    // MARK: Battles

    func battleKind(_ kind: ExpeditionEventKind) -> String {
        switch kind {
        case .horde: t("무리", "Horde", "むれ", "Horda", "Horde", "Horda", "Horde", "Орда")
        case .trainer: t("트레이너", "Trainer", "トレーナー", "Entrenador", "Dresseur", "Treinador", "Trainer", "Тренер")
        case .boss: t("보스", "Boss", "ボス", "Jefe", "Boss", "Chefe", "Boss", "Босс")
        default: t("야생", "Wild", "やせい", "Salvaje", "Sauvage", "Selvagem", "Wild", "Дикие")
        }
    }
    var battlePause: String { t("일시정지", "Pause", "一時停止", "Pausa", "Pause", "Pausar", "Pause", "Пауза") }
    var battlePlay: String { t("재생", "Play", "再生", "Reproducir", "Lecture", "Reproduzir", "Abspielen", "Играть") }
    var battleSkip: String { t("건너뛰기", "Skip", "スキップ", "Saltar", "Passer", "Pular", "Überspringen", "Пропустить") }
    var battleWon: String { t("승리", "Won", "勝利", "Victoria", "Victoire", "Vitória", "Gewonnen", "Победа") }
    var battleLost: String { t("패배", "Lost", "敗北", "Derrota", "Défaite", "Derrota", "Verloren", "Поражение") }
    var battleKO: String { t("기절", "K.O.", "ひんし", "Debilitado", "K.O.", "Desmaiado", "K.O.", "Без сил") }

    // MARK: The expedition on Home (maquettes 3, 4, 6, 7)

    func dungeonFloorOf(_ floor: Int, _ floors: Int) -> String {
        t("\(floor)/\(floors)층", "Floor \(floor) of \(floors)", "\(floor)/\(floors)階", "Piso \(floor) de \(floors)",
          "Étage \(floor) sur \(floors)", "Andar \(floor) de \(floors)", "Ebene \(floor) von \(floors)",
          "Этаж \(floor) из \(floors)")
    }
    func dungeonFloor(_ floor: Int) -> String {
        t("\(floor)층", "Floor \(floor)", "\(floor)階", "Piso \(floor)", "Étage \(floor)", "Andar \(floor)", "Ebene \(floor)",
          "Этаж \(floor)")
    }
    /// The menu bar's short tag: "É6/12".
    func dungeonFloorTag(_ floor: Int, _ floors: Int) -> String {
        t("\(floor)/\(floors)층", "F\(floor)/\(floors)", "\(floor)/\(floors)階", "P\(floor)/\(floors)", "É\(floor)/\(floors)",
          "A\(floor)/\(floors)", "E\(floor)/\(floors)", "Э\(floor)/\(floors)")
    }
    func dungeonToNextFloor(_ have: String, _ need: String, next: Int) -> String {
        t("\(next)층까지 \(have) / \(need)", "\(have) / \(need) to floor \(next)", "\(next)階まで \(have) / \(need)",
          "\(have) / \(need) hasta el piso \(next)", "\(have) / \(need) avant l'étage \(next)",
          "\(have) / \(need) até o andar \(next)", "\(have) / \(need) bis Ebene \(next)", "\(have) / \(need) до этажа \(next)")
    }
    func dungeonToBoss(_ have: String, _ need: String) -> String {
        t("보스까지 \(have) / \(need)", "\(have) / \(need) to the boss", "ボスまで \(have) / \(need)",
          "\(have) / \(need) hasta el jefe", "\(have) / \(need) avant le boss", "\(have) / \(need) até o chefe",
          "\(have) / \(need) bis zum Boss", "\(have) / \(need) до босса")
    }
    var dungeonBossHidden: String { t("보스: ?", "Boss: ?", "ボス：？", "Jefe: ?", "Boss : ?", "Chefe: ?", "Boss: ?", "Босс: ?") }
    var dungeonRare: String { t("희귀", "Rare", "レア", "Raro", "Rare", "Raro", "Selten", "Редкое") }
    var dungeonReplay: String { t("다시 보기", "Replay", "見直す", "Repetir", "Revoir", "Rever", "Ansehen", "Повтор") }
    var dungeonLive: String { t("실시간", "Live", "ライブ", "En directo", "En direct", "Ao vivo", "Live", "В эфире") }
    var dungeonLogTitle: String { t("탐험 기록", "Journal", "たんけんの記録", "Diario", "Journal", "Diário", "Tagebuch", "Журнал") }
    var dungeonWholeLog: String {
        t("전체 기록", "Whole journal", "すべての記録", "Diario completo", "Tout le journal", "Diário completo", "Ganzes Tagebuch",
          "Весь журнал")
    }
    var dungeonSeeLog: String {
        t("기록 보기", "See the journal", "記録を見る", "Ver el diario", "Voir le journal", "Ver o diário", "Tagebuch ansehen",
          "Открыть журнал")
    }
    var dungeonGrowthPaused: String {
        t("팀이 돌아오면 키우는 포켓몬이 다시 자라요.", "Your Pokémon being raised grows again once the team is back.",
          "チームが戻ると、育てているポケモンがまた育ちます。", "Tu Pokémon en crianza vuelve a crecer cuando regresa el equipo.",
          "Ton Pokémon en cours reprend sa croissance au retour de l'équipe.",
          "Seu Pokémon em criação volta a crescer quando a equipe voltar.",
          "Dein Pokémon in Aufzucht wächst weiter, sobald das Team zurück ist.",
          "Растущий покемон продолжит расти, когда команда вернётся.")
    }
    var dungeonAbandon: String { t("포기", "Give up", "あきらめる", "Abandonar", "Abandonner", "Desistir", "Aufgeben", "Сдаться") }
    var dungeonLeave: String {
        t("던전 나가기", "Leave the dungeon", "ダンジョンを出る", "Salir de la mazmorra", "Quitter le donjon", "Sair da masmorra",
          "Dungeon verlassen", "Покинуть подземелье")
    }
    /// What giving up costs: nothing with an Escape Rope, the loot without one (Q4).
    func dungeonAbandonCost(rope: String, has: Bool) -> String {
        has
            ? t("\(KoreanParticle.direction.attach(to: rope)) 팀이 돌아와요. 모은 물건은 그대로 가져와요.",
                "Your \(rope) brings the team back: the loot is kept.", "\(rope)でチームが戻ります。集めたものは持ち帰れます。",
                "Tu \(rope) trae al equipo de vuelta: el botín se conserva.", "Ta \(rope) ramène l'équipe : le butin est gardé.",
                "Sua \(rope) traz a equipe de volta: o saque fica.", "Dein \(rope) bringt das Team zurück: Die Beute bleibt.",
                "\(rope) вернёт команду: добыча сохранится.")
            : t("\(rope) 없이 나가면 모은 물건을 모두 잃어요.", "With no \(rope) in the Bag, the expedition's loot is lost.",
                "\(rope)がないので、集めたものはすべて失われます。", "Sin \(rope), el botín de la expedición se pierde.",
                "Sans \(rope), le butin de l'expédition est perdu.", "Sem \(rope), o saque da expedição é perdido.",
                "Ohne \(rope) geht die Beute der Expedition verloren.", "Без предмета \"\(rope)\" добыча экспедиции пропадёт.")
    }

    // The journal's lines: the species stand beside them as sprites, named on hover.

    var dungeonLogChest: String { t("상자", "Chest", "たからばこ", "Cofre", "Coffre", "Baú", "Truhe", "Сундук") }
    var dungeonLogEmptyChest: String {
        t("빈 상자", "Empty chest", "からっぽのたからばこ", "Cofre vacío", "Coffre vide", "Baú vazio", "Leere Truhe", "Пустой сундук")
    }
    func dungeonLogTrap(percent: Int) -> String {
        t("함정: 팀이 HP를 \(percent)% 잃었어요", "Trap: the team loses \(percent)% of its HP", "わな：チームのHPが\(percent)%減った",
          "Trampa: el equipo pierde el \(percent) % de sus PS", "Piège : l'équipe perd \(percent) % de ses PV",
          "Armadilha: a equipe perde \(percent)% dos PS", "Falle: Das Team verliert \(percent) % seiner KP",
          "Ловушка: команда теряет \(percent)% ОЗ")
    }
    func dungeonLogTrapItem(_ item: String) -> String {
        t("함정: 모은 물건 중 \(item) 1개를 잃었어요", "Trap: the loot loses 1 × \(item)", "わな：\(item)を1こ失った",
          "Trampa: el botín pierde 1 × \(item)", "Piège : le butin perd 1 × \(item)", "Armadilha: o saque perde 1 × \(item)",
          "Falle: Die Beute verliert 1 × \(item)", "Ловушка: добыча теряет \(item) ×1")
    }
    func dungeonLogSpring(percent: Int) -> String {
        t("샘: 팀이 HP를 \(percent)% 회복했어요", "Spring: the team gets \(percent)% of its HP back",
          "いずみ：チームのHPが\(percent)%回復した", "Manantial: el equipo recupera el \(percent) % de sus PS",
          "Source : l'équipe récupère \(percent) % de ses PV", "Fonte: a equipe recupera \(percent)% dos PS",
          "Quelle: Das Team erhält \(percent) % seiner KP zurück", "Источник: команда восстанавливает \(percent)% ОЗ")
    }
    var dungeonLogCenter: String {
        t("포켓몬센터: 팀 전원이 회복했어요", "Pokémon Center: the whole team is healed", "ポケモンセンター：チーム全員が回復した",
          "Centro Pokémon: todo el equipo se cura", "Centre Pokémon : toute l'équipe est soignée",
          "Centro Pokémon: toda a equipe é curada", "Pokémon-Center: Das ganze Team ist geheilt",
          "Покемон-центр: вся команда вылечена")
    }
    func dungeonLogLost(percent: Int) -> String {
        t("길 잃은 포켓몬: 팀이 데려다주고(HP -\(percent)%) 선물을 받았어요",
          "Lost Pokémon: the team walks it home (-\(percent)% HP) and gets a gift",
          "まいごのポケモン：送りとどけて(HP -\(percent)%)、おれいをもらった",
          "Pokémon perdido: el equipo lo acompaña (-\(percent) % PS) y recibe un regalo",
          "Pokémon égaré : l'équipe le raccompagne (-\(percent) % PV) et reçoit un cadeau",
          "Pokémon perdido: a equipe o acompanha (-\(percent)% PS) e ganha um presente",
          "Verirrtes Pokémon: Das Team bringt es heim (-\(percent) % KP) und erhält ein Geschenk",
          "Потерявшийся покемон: команда провожает его (-\(percent)% ОЗ) и получает подарок")
    }
    func dungeonLogShiny(caught: Bool) -> String {
        caught
            ? t("이로치 조우: 잡았어요! 알을 얻었어요", "Shiny encounter: caught! Its egg joins the loot",
                "色違いに出会った：つかまえた！タマゴを手に入れた", "Encuentro variocolor: ¡capturado! Su huevo va al botín",
                "Rencontre chromatique : capturé ! Son œuf rejoint le butin", "Encontro brilhante: capturado! O ovo vai para o saque",
                "Schillerndes Pokémon: gefangen! Sein Ei kommt zur Beute", "Встреча с шайни: пойман! Его яйцо в добыче")
            : t("이로치 조우: 도망쳤어요", "Shiny encounter: it fled", "色違いに出会った：にげられた", "Encuentro variocolor: huyó",
                "Rencontre chromatique : il s'est enfui", "Encontro brilhante: fugiu", "Schillerndes Pokémon: geflohen",
                "Встреча с шайни: сбежал")
    }
    func dungeonLogBranch(roll: Int, risky: Bool) -> String {
        risky
            ? t("주사위: 6 중 \(roll), 위험한 길", "Dice: \(roll) of 6, risky path", "サイコロ：6のうち\(roll)、きけんな道",
                "Dados: \(roll) de 6, camino arriesgado", "Dés : \(roll) sur 6, chemin risqué", "Dados: \(roll) de 6, caminho arriscado",
                "Würfel: \(roll) von 6, riskanter Weg", "Кубик: \(roll) из 6, опасный путь")
            : t("주사위: 6 중 \(roll), 안전한 길", "Dice: \(roll) of 6, safe path", "サイコロ：6のうち\(roll)、あんぜんな道",
                "Dados: \(roll) de 6, camino seguro", "Dés : \(roll) sur 6, chemin sûr", "Dados: \(roll) de 6, caminho seguro",
                "Würfel: \(roll) von 6, sicherer Weg", "Кубик: \(roll) из 6, безопасный путь")
    }
    func dungeonLogItemUsed(_ item: String) -> String {
        t("\(item) 사용", "\(item) used", "\(item)をつかった", "\(item) usado", "\(item) utilisé", "\(item) usado",
          "\(item) eingesetzt", "Использован предмет \"\(item)\"")
    }
    func dungeonLogHeal(_ price: String) -> String {
        t("긴급 회복: 팀 전원 HP 100% (\(price))", "Emergency heal: the whole team at 100% (\(price))",
          "きんきゅう回復：チーム全員HP100% (\(price))", "Curación de urgencia: todo el equipo al 100 % (\(price))",
          "Soin d'urgence : toute l'équipe à 100 % (\(price))", "Cura de emergência: toda a equipe a 100% (\(price))",
          "Notheilung: Das ganze Team auf 100 % (\(price))", "Срочное лечение: вся команда на 100% (\(price))")
    }
    var dungeonLogBoss: String {
        t("보스 등장", "The boss appears", "ボスがあらわれた", "Aparece el jefe", "Le boss apparaît", "O chefe aparece",
          "Der Boss erscheint", "Появляется босс")
    }
    func dungeonLogThrow(_ attempt: Int, ball: String, caught: Bool) -> String {
        caught
            ? t("\(attempt)번째 던지기 (\(ball)): 잡았다!", "Throw \(attempt) (\(ball)): caught!", "\(attempt)回目 (\(ball))：つかまえた！",
                "Lanzamiento \(attempt) (\(ball)): ¡capturado!", "Lancer \(attempt) (\(ball)) : capturé !",
                "Lance \(attempt) (\(ball)): capturado!", "Wurf \(attempt) (\(ball)): gefangen!", "Бросок \(attempt) (\(ball)): пойман!")
            : t("\(attempt)번째 던지기 (\(ball)): 놓쳤다", "Throw \(attempt) (\(ball)): missed", "\(attempt)回目 (\(ball))：だめだった",
                "Lanzamiento \(attempt) (\(ball)): fallido", "Lancer \(attempt) (\(ball)) : raté", "Lance \(attempt) (\(ball)): errou",
                "Wurf \(attempt) (\(ball)): daneben", "Бросок \(attempt) (\(ball)): мимо")
    }
    var dungeonLogVictory: String {
        t("보스 격파: 모은 물건을 얻었어요", "Boss beaten: the loot is won", "ボスをたおした：集めたものを手に入れた",
          "Jefe vencido: el botín es tuyo", "Boss vaincu : le butin est gagné", "Chefe vencido: o saque é seu",
          "Boss besiegt: Die Beute gehört dir", "Босс повержен: добыча твоя")
    }
    var dungeonLogDefeat: String {
        t("팀 전멸: 모은 물건을 잃었어요", "Team down: the loot is lost", "チームぜんめつ：集めたものを失った",
          "Equipo derrotado: el botín se pierde", "Équipe K.O. : le butin est perdu", "Equipe derrotada: o saque é perdido",
          "Team besiegt: Die Beute ist verloren", "Команда побеждена: добыча потеряна")
    }
    func dungeonLogAbandon(rope: String?) -> String {
        if let rope {
            return t("\(KoreanParticle.direction.attach(to: rope)) 탈출: 모은 물건은 지켰어요", "Out with the \(rope): loot kept",
                     "\(rope)で脱出：集めたものは無事", "Salida con \(rope): botín conservado", "Sortie avec \(rope) : butin gardé",
                     "Saída com \(rope): saque mantido", "Raus mit \(rope): Beute behalten",
                     "Выход с помощью предмета \"\(rope)\": добыча сохранена")
        }
        return t("포기: 모은 물건을 잃었어요", "Gave up: loot lost", "あきらめた：集めたものを失った", "Abandono: botín perdido",
                 "Abandon : butin perdu", "Desistência: saque perdido", "Aufgegeben: Beute verloren", "Сдались: добыча потеряна")
    }

    // The emergency heal (R5, maquette 4).

    var dungeonPaused: String { t("일시정지", "paused", "一時停止中", "en pausa", "en pause", "em pausa", "pausiert", "на паузе") }
    func dungeonTeamInDanger(_ percent: Int) -> String {
        t("팀 위험: HP \(percent)%", "Team in danger: \(percent)% of its HP", "チームがあぶない：HP \(percent)%",
          "Equipo en peligro: \(percent) % de sus PS", "Équipe en danger : \(percent) % de ses PV",
          "Equipe em perigo: \(percent)% dos PS", "Team in Gefahr: \(percent) % seiner KP", "Команда в опасности: \(percent)% ОЗ")
    }
    var dungeonHealExplain: String {
        t("긴급 회복: 팀 전원 HP 100%, 기절한 포켓몬도 일어나요. 탐험마다 한 번뿐이에요. 회복하지 않고 지면 모은 물건을 모두 잃어요.",
          "Emergency heal: the whole team back to 100%, fainted ones revived. Once per expedition. Without it, a defeat loses all the loot.",
          "きんきゅう回復：チーム全員HP100%、ひんしも回復。たんけん1回につき1度だけ。回復せずに負けると、集めたものをすべて失います。",
          "Curación de urgencia: todo el equipo al 100 %, los debilitados se levantan. Una sola vez por expedición. Sin ella, una derrota pierde todo el botín.",
          "Soin d'urgence : toute l'équipe à 100 %, les K.O. relevés. Une seule fois par expédition. Sans lui, une défaite fait perdre tout le butin.",
          "Cura de emergência: toda a equipe a 100%, os desmaiados de pé. Uma vez por expedição. Sem ela, uma derrota perde todo o saque.",
          "Notheilung: Das ganze Team auf 100 %, besiegte Pokémon stehen wieder auf. Einmal pro Expedition. Ohne sie kostet eine Niederlage die ganze Beute.",
          "Срочное лечение: вся команда на 100%, павшие встают. Один раз за экспедицию. Без него поражение стоит всей добычи.")
    }
    func dungeonHealPrice(_ price: String, have: String) -> String {
        t("가격: \(price) · 보유 \(have)", "Price: \(price) · you have \(have)", "ねだん：\(price)・所持 \(have)",
          "Precio: \(price) · tienes \(have)", "Prix : \(price) · tu as \(have)", "Preço: \(price) · você tem \(have)",
          "Preis: \(price) · du hast \(have)", "Цена: \(price) · у тебя \(have)")
    }
    var dungeonHealSkip: String {
        t("그냥 계속", "Go on without", "そのまま進む", "Seguir sin ella", "Continuer sans", "Seguir sem", "Ohne weiter", "Продолжить без")
    }
    func dungeonHealPay(_ price: String) -> String {
        t("회복 · \(price)", "Heal · \(price)", "回復・\(price)", "Curar · \(price)", "Soigner · \(price)", "Curar · \(price)",
          "Heilen · \(price)", "Лечить · \(price)")
    }
    func dungeonReserve(_ tokens: String) -> String {
        t("토큰 \(tokens) 대기 중, 답하면 바로 반영돼요.", "\(tokens) tokens on hold, put in as soon as you answer.",
          "トークン\(tokens)が待機中。答えるとすぐに反映されます。", "\(tokens) tokens en reserva, aplicados en cuanto respondas.",
          "\(tokens) de tokens en réserve, appliqués dès ta réponse.", "\(tokens) tokens em reserva, aplicados assim que você responder.",
          "\(tokens) Tokens in Reserve, angerechnet, sobald du antwortest.", "\(tokens) токенов в резерве, учтутся сразу после ответа.")
    }

    // The capture (Q18, maquette 6).

    func dungeonBossWas(_ floor: Int) -> String {
        t("\(floor)층 · 보스는…", "Floor \(floor) · the boss was…", "\(floor)階・ボスは…", "Piso \(floor) · el jefe era…",
          "Étage \(floor) · le boss était…", "Andar \(floor) · o chefe era…", "Ebene \(floor) · der Boss war…",
          "Этаж \(floor) · боссом был…")
    }
    var dungeonBossBeatenThrow: String {
        t("쓰러뜨렸어요! 모은 물건을 얻었어요. 볼을 던져 알을 얻으세요.", "Beaten! The loot is won. Throw a ball to get its egg.",
          "たおした！集めたものを手に入れた。ボールを投げてタマゴを手に入れよう。",
          "¡Vencido! El botín es tuyo. Lanza una ball para conseguir su huevo.",
          "Vaincu ! Le butin est gagné. Lance une ball pour obtenir son œuf.", "Vencido! O saque é seu. Lance uma bola para ganhar o ovo.",
          "Besiegt! Die Beute gehört dir. Wirf einen Ball, um sein Ei zu bekommen.",
          "Повержен! Добыча твоя. Брось бол, чтобы получить его яйцо.")
    }
    func dungeonThrowsLeft(_ n: Int) -> String {
        t("남은 던지기: \(n)", "Throws left: \(n)", "のこり\(n)回", "Lanzamientos restantes: \(n)", "Lancers restants : \(n)",
          "Lances restantes: \(n)", "Würfe übrig: \(n)", "Осталось бросков: \(n)")
    }
    var dungeonMissed: String { t("놓침", "missed", "だめ", "fallido", "raté", "errou", "daneben", "мимо") }
    func dungeonThrowOdds(_ ball: String, _ percent: Int) -> String {
        t("\(ball) · \(percent)%", "\(ball) · \(percent)%", "\(ball)・\(percent)%", "\(ball) · \(percent) %", "\(ball) · \(percent) %",
          "\(ball) · \(percent)%", "\(ball) · \(percent) %", "\(ball) · \(percent)%")
    }
    var dungeonPokeBall: String {
        t("몬스터볼", "Poké Ball", "モンスターボール", "Poké Ball", "Poké Ball", "Poké Bola", "Pokéball", "Покебол")
    }
    var dungeonLetGo: String { t("보내 주기", "Let it go", "にがす", "Dejarlo ir", "Laisser partir", "Deixar ir", "Ziehen lassen", "Отпустить") }
    var dungeonLetGoCost: String {
        t("더 던지지 않으면 알 없이 탐험이 끝나요.", "No more throws: the expedition ends without its egg.",
          "これ以上投げないと、タマゴなしでたんけんが終わります。", "Sin más lanzamientos: la expedición termina sin su huevo.",
          "Plus de lancer : l'expédition se termine sans son œuf.", "Sem mais lances: a expedição termina sem o ovo.",
          "Keine Würfe mehr: Die Expedition endet ohne sein Ei.", "Больше бросков не будет: экспедиция закончится без яйца.")
    }

    // The return (maquette 7).

    func dungeonResultTitle(won: Bool, roped: Bool) -> String {
        if won {
            return t("탐험 성공", "Expedition won", "たんけん成功", "Expedición superada", "Expédition réussie", "Expedição concluída",
                     "Expedition geschafft", "Экспедиция удалась")
        }
        if roped {
            return t("조기 귀환", "Back early", "早めの帰還", "Regreso anticipado", "Retour anticipé", "Retorno antecipado",
                     "Früh zurück", "Досрочное возвращение")
        }
        return t("탐험 실패", "Expedition failed", "たんけん失敗", "Expedición fallida", "Expédition échouée", "Expedição fracassada",
                 "Expedition gescheitert", "Экспедиция провалена")
    }
    var dungeonFirstVictory: String {
        t("첫 승리", "1st win", "初勝利", "1.ª victoria", "1re victoire", "1ª vitória", "1. Sieg", "1-я победа")
    }
    func dungeonBattles(_ n: Int) -> String {
        t("전투 \(n)회", n == 1 ? "1 battle" : "\(n) battles", "\(n)戦", n == 1 ? "1 combate" : "\(n) combates",
          n <= 1 ? "\(n) combat" : "\(n) combats", n == 1 ? "1 batalha" : "\(n) batalhas", n == 1 ? "1 Kampf" : "\(n) Kämpfe",
          "Боёв: \(n)")
    }
    var dungeonBossCaught: String {
        t("잡았어요: 알은 가방에 있어요", "Caught: its egg is in the Bag", "つかまえた：タマゴはバッグに",
          "Capturado: su huevo está en la Bolsa", "Capturé : son œuf est dans le Sac", "Capturado: o ovo está na Mochila",
          "Gefangen: Sein Ei ist im Beutel", "Пойман: его яйцо в сумке")
    }
    var dungeonBossNotCaught: String {
        t("잡지 못했어요", "Not caught", "つかまえられなかった", "No capturado", "Pas capturé", "Não capturado", "Nicht gefangen", "Не пойман")
    }
    func dungeonUnlocked(_ names: String) -> String {
        t("열림: \(names)", "Unlocked: \(names)", "解放：\(names)", "Desbloqueado: \(names)", "Débloqué : \(names)",
          "Desbloqueado: \(names)", "Freigeschaltet: \(names)", "Открыто: \(names)")
    }
    var dungeonTechnicalCapsule: String {
        t("기술 캡슐", "Technical Capsule", "わざカプセル", "Cápsula Técnica", "Capsule Technique", "Cápsula Técnica", "Technikkapsel",
          "Техническая капсула")
    }
    var dungeonLootLost: String {
        t("모은 물건은 잃었어요. 쓰지 않은 가져간 물건은 가방으로 돌아왔어요.",
          "The loot is lost. What the team took along and didn't use is back in the Bag.",
          "集めたものは失われました。使わなかった持ち物はバッグにもどりました。",
          "El botín se ha perdido. Lo que el equipo llevó y no usó vuelve a la Bolsa.",
          "Le butin est perdu. Ce que l'équipe avait emporté sans l'utiliser est revenu au Sac.",
          "O saque foi perdido. O que a equipe levou e não usou voltou para a Mochila.",
          "Die Beute ist verloren. Was das Team mitnahm und nicht brauchte, ist zurück im Beutel.",
          "Добыча потеряна. Неиспользованные вещи вернулись в сумку.")
    }
    var dungeonGrowthResumes: String {
        t("키우는 포켓몬이 다시 자라요.", "Your Pokémon being raised grows again.", "育てているポケモンがまた育ちます。",
          "Tu Pokémon en crianza vuelve a crecer.", "Ton Pokémon en cours reprend sa croissance.",
          "Seu Pokémon em criação volta a crescer.", "Dein Pokémon in Aufzucht wächst wieder.", "Растущий покемон снова растёт.")
    }

    // The Bag's dungeon items.

    var dungeonOpen: String { t("열기", "Open", "開ける", "Abrir", "Ouvrir", "Abrir", "Öffnen", "Открыть") }
    func dungeonChestFound(_ what: String) -> String {
        t("발견: \(what)", "Found: \(what)", "見つけた：\(what)", "Encontrado: \(what)", "Trouvé : \(what)",
          "Encontrado: \(what)", "Gefunden: \(what)", "Найдено: \(what)")
    }
    var dungeonNoCapsuleTarget: String {
        t("개체값이 31 미만인 졸업 포켓몬이 없어요", "No graduated Pokémon with an IV under 31",
          "個体値が31未満の卒業ポケモンがいません", "Ningún Pokémon graduado con un IV bajo 31",
          "Aucun diplômé avec un IV sous 31", "Nenhum Pokémon formado com IV abaixo de 31",
          "Kein verabschiedetes Pokémon mit einem DV unter 31", "Нет выпускников с IV ниже 31")
    }
    var dungeonCapsulePick: String {
        t("졸업 포켓몬을 고르세요", "Pick a graduated Pokémon", "卒業ポケモンをえらんでね", "Elige un Pokémon graduado",
          "Choisis un diplômé", "Escolha um Pokémon formado", "Wähle ein verabschiedetes Pokémon", "Выбери выпускника")
    }
    var dungeonCapsulePickStat: String {
        t("31로 올릴 개체값을 고르세요", "Pick the IV to raise to 31", "31にする個体値をえらんでね",
          "Elige el IV que subir a 31", "Choisis l'IV à monter à 31", "Escolha o IV a subir para 31",
          "Wähle den DV, der auf 31 steigt", "Выбери IV, который поднять до 31")
    }
    var dungeonCapsuleRaiseAll: String {
        t("모두 31로", "All to 31", "すべて31に", "Todo a 31", "Tout à 31", "Tudo para 31", "Alle auf 31", "Все до 31")
    }
    var dungeonCapsuleDone: String {
        t("개체값을 31로 올렸어요", "IVs raised to 31", "個体値を31にしました", "IV subidos a 31", "IV montés à 31",
          "IVs elevados a 31", "DV auf 31 erhöht", "IV подняты до 31")
    }
    var dungeonEggHatches: String {
        t("계열의 첫 포켓몬이 태어나요. 개체값과 성격은 부화할 때 정해져요.",
          "Hatches the first Pokémon of its line; IVs and nature are drawn at the hatch.",
          "進化の最初のポケモンが生まれます。個体値と性格はかえるときに決まります。",
          "Nace el primer Pokémon de su línea; los IV y la naturaleza se sortean al eclosionar.",
          "Fait éclore le premier Pokémon de sa lignée ; IV et nature sont tirés à l'éclosion.",
          "Choca o primeiro Pokémon da linha; IVs e natureza são sorteados ao chocar.",
          "Schlüpft als erstes Pokémon seiner Linie; DV und Wesen werden beim Schlüpfen gezogen.",
          "Вылупляется первый покемон линии; IV и характер определяются при вылуплении.")
    }
    var dungeonEggShiny: String {
        t("이로치 확정", "Shiny guaranteed", "色違い確定", "Variocolor asegurado", "Chromatique garanti", "Brilhante garantido",
          "Schillernd garantiert", "Гарантированно шайни")
    }

    /// The places' official names (Q26).
    func dungeonName(_ id: DungeonID) -> String {
        switch id {
        case .viridianForest: t("상록숲", "Viridian Forest", "トキワのもり", "Bosque Verde", "Forêt de Jade",
                                "Floresta de Viridian", "Vertania-Wald", "Виридиан-лес")
        case .diglettsCave: t("디그다굴", "Diglett's Cave", "ディグダのあな", "Cueva Diglett", "Grotte Taupiqueur",
                              "Caverna do Diglett", "Digda-Höhle", "Пещера Диглетта")
        case .mtMoon: t("달맞이산", "Mt. Moon", "おつきみやま", "Mt. Moon", "Mont Sélénite", "Monte Lua", "Mondberg",
                        "Гора Луны")
        case .mtEmber: t("불꽃산", "Mt. Ember", "ともしびやま", "Monte Ascuas", "Mont Braise", "Monte Brasa", "Glutberg",
                         "Гора Эмбер")
        case .victoryRoad: t("챔피언로드", "Victory Road", "チャンピオンロード", "Calle Victoria", "Route Victoire",
                             "Estrada Vitória", "Siegesstraße", "Дорога победы")
        case .pokemonTower: t("포켓몬타워", "Pokémon Tower", "ポケモンタワー", "Torre Pokémon", "Tour Pokémon",
                              "Torre Pokémon", "Pokémon-Turm", "Покемон-башня")
        case .dragonsDen: t("용의굴", "Dragon's Den", "りゅうのあな", "Guarida Dragón", "Antre du Dragon",
                            "Covil do Dragão", "Drachenhöhle", "Логово дракона")
        case .powerPlant: t("무인발전소", "Power Plant", "むじんはつでんしょ", "Central Energía", "Centrale",
                            "Usina de Energia", "Kraftwerk", "Электростанция")
        case .seafoamIslands: t("쌍둥이섬", "Seafoam Islands", "ふたごじま", "Islas Espuma", "Îles Écume",
                                "Ilhas Seafoam", "Seeschauminseln", "Острова Сифоум")
        case .ceruleanCave: t("블루시티동굴", "Cerulean Cave", "ハナダのどうくつ", "Cueva Celeste", "Caverne Azurée",
                              "Caverna Celeste", "Azuria-Höhle", "Церулинская пещера")
        case .mtCoronet: t("천관산", "Mt. Coronet", "テンガンざん", "Monte Corona", "Mont Couronné", "Monte Coronet",
                           "Kraterberg", "Гора Коронет")
        case .ruinsOfAlph: t("알프의 유적", "Ruins of Alph", "アルフのいせき", "Ruinas Alfa", "Ruines d'Alpha",
                             "Ruínas de Alfa", "Alph-Ruinen", "Руины Альфа")
        case .hallOfOrigin: t("시작의 방", "Hall of Origin", "はじまりのま", "Sala del Origen", "Salle Originelle",
                              "Salão da Origem", "Saal des Ursprungs", "Зал Истоков")
        }
    }
}
