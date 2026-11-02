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
