import Foundation

/// The words of the Luck screen (`LuckScreen`), its figures shown as TokenDex shows them.
extension L {
    private var locale: Locale { lang.displayLocale }

    var luckTitle: String {
        t("나의 운", "Your luck", "あなたの運", "Tu suerte", "Ta chance", "Sua sorte", "Dein Glück", "Твоя удача")
    }

    func luckFamily(_ family: LuckFamily) -> String {
        switch family {
        case .hatches: luckTab(.hatches)
        case .dungeons: dungeonsTab
        }
    }

    /// The summary's span: all time or the last thirty days.
    func luckPeriod(recent: Bool) -> String {
        recent
            ? t("최근 30일", "Last 30 days", "直近30日", "Últimos 30 días", "30 derniers jours", "Últimos 30 dias", "Letzte 30 Tage",
                "Последние 30 дней")
            : t("처음부터", "Since the start", "最初から", "Desde el principio", "Depuis le début", "Desde o início", "Seit Beginn",
                "С самого начала")
    }

    func luckTab(_ tab: PopoverNavigation.LuckTab) -> String {
        switch tab {
        case .summary: t("요약", "Summary", "概要", "Resumen", "Résumé", "Resumo", "Übersicht", "Сводка")
        case .curves: t("추이", "Curves", "推移", "Curvas", "Courbes", "Curvas", "Verlauf", "Графики")
        case .hatches: t("부화", "Hatches", "孵化", "Eclosiones", "Éclosions", "Eclosões", "Schlüpfe", "Вылупления")
        }
    }

    func luckCriterion(_ criterion: HatchLuck.Criterion) -> String {
        switch criterion {
        case .rarity: t("희귀도", "Rarity", "レア度", "Rareza", "Rareté", "Raridade", "Seltenheit", "Редкость")
        case .shiny: bonusThemeTitle(.shiny)
        case .new: t("새로움", "Something new", "新しいもの", "Algo nuevo", "Du nouveau", "Algo novo", "Etwas Neues", "Новое")
        case .ditto: t("메타몽", "Ditto", "メタモン", "Ditto", "Métamorph", "Ditto", "Ditto", "Дитто")
        case .ivs: t("개체값", "IVs", "個体値", "IV", "IV", "IVs", "IS-Werte", "IV")
        case .hiddenAbility:
            t("숨겨진 특성", "Hidden ability", "隠れ特性", "Habilidad oculta", "Talent caché", "Habilidade oculta",
              "Versteckte Fähigkeit", "Скрытая способность")
        case .capture: t("포획", "Captures", "捕獲", "Capturas", "Captures", "Capturas", "Fänge", "Поимки")
        case .dungeonShiny:
            t("던전 이로치", "Dungeon shinies", "ダンジョンの色違い", "Variocolores de mazmorra", "Chromatiques en donjon",
              "Shinies nas masmorras", "Schillernde in Dungeons", "Шайни в подземельях")
        case .find: t("발견", "Finds", "発見", "Hallazgos", "Trouvailles", "Achados", "Funde", "Находки")
        }
    }

    var luckScoreTitle: String {
        t("운 지수", "Luck score", "運スコア", "Índice de suerte", "Indice de chance", "Índice de sorte", "Glückswert", "Индекс удачи")
    }

    /// TokenDex's mood for the score as shown.
    func luckMood(_ score: Int) -> String {
        if score >= 65 {
            return t("운이 꽤 좋은 편", "pretty lucky", "かなり運がいい", "con bastante suerte", "plutôt gâté", "com bastante sorte",
                     "ein echtes Glückskind", "настоящий везунчик")
        }
        if score >= 55 {
            return t("평균보다 조금 위", "a bit above average", "平均より少し上", "un poco por encima de la media",
                     "un peu au-dessus de la moyenne", "um pouco acima da média", "etwas über dem Schnitt", "чуть выше среднего")
        }
        if score > 45 {
            return t("딱 평균", "right on average", "ちょうど平均", "justo en la media", "pile dans la moyenne", "bem na média",
                     "genau im Schnitt", "ровно посередине")
        }
        if score > 35 {
            return t("평균보다 조금 아래", "a bit below average", "平均より少し下", "un poco por debajo", "un peu en dessous",
                     "um pouco abaixo", "etwas unter dem Schnitt", "чуть ниже среднего")
        }
        return t("운이 꽤 나쁜 편", "rather unlucky", "かなり運が悪い", "con bastante mala suerte", "plutôt malchanceux",
                 "com bastante azar", "eher ein Pechvogel", "скорее невезучий")
    }

    /// The summary under the score, in Markdown for its bold words: over the hatches and expeditions it holds, or over
    /// the last thirty days.
    func luckSentence(hatches: Int, expeditions: Int, recent: Bool, score: Int, best: (HatchLuck.Criterion, Double),
                      worst: (HatchLuck.Criterion, Double)) -> String {
        let mood = luckMood(score)
        let strong = luckCriterion(best.0), strongShare = luckPercent(best.1)
        let weak = luckCriterion(worst.0), weakShare = luckPercent(worst.1)
        let h = hatches.formatted(.number.locale(locale)), x = expeditions.formatted(.number.locale(locale))
        let over: String
        if recent {
            over = t("최근 30일 동안", "Over the last 30 days", "直近30日で", "En los últimos 30 días", "Sur les 30 derniers jours",
                     "Nos últimos 30 dias", "In den letzten 30 Tagen", "За последние 30 дней")
        } else if expeditions > 0 {
            over = t("부화 \(h)번과 탐험 \(x)번 기준", "Over \(h) hatches and \(x) expeditions", "孵化\(h)回と探検\(x)回で",
                     "En \(h) eclosiones y \(x) expediciones", "Sur \(h) éclosions et \(x) expéditions",
                     "Em \(h) eclosões e \(x) expedições", "Bei \(h) Schlüpfen und \(x) Expeditionen",
                     "За \(h) вылуплений и \(x) экспедиций")
        } else {
            over = t("부화 \(h)번 기준", "Over \(h) hatches", "孵化\(h)回で", "En \(h) eclosiones", "Sur \(h) éclosions",
                     "Em \(h) eclosões", "Bei \(h) Schlüpfen", "За \(h) вылуплений")
        }
        return t("\(over), **\(mood)**입니다. 강점: **\(strong)** (\(strongShare)). 약점: **\(weak)** (\(weakShare)).",
                 "\(over), you are **\(mood)**. Your strong point: **\(strong)** (\(strongShare)). "
                     + "Your weak point: **\(weak)** (\(weakShare)).",
                 "\(over)、あなたは**\(mood)**です。得意: **\(strong)**（\(strongShare)）。苦手: **\(weak)**（\(weakShare)）。",
                 "\(over), estás **\(mood)**. Tu punto fuerte: **\(strong)** (\(strongShare)). "
                     + "Tu punto débil: **\(weak)** (\(weakShare)).",
                 "\(over), tu es **\(mood)**. Ton point fort : **\(strong)** (\(strongShare)). "
                     + "Ton point faible : **\(weak)** (\(weakShare)).",
                 "\(over), você está **\(mood)**. Seu ponto forte: **\(strong)** (\(strongShare)). "
                     + "Seu ponto fraco: **\(weak)** (\(weakShare)).",
                 "\(over) bist du **\(mood)**. Deine Stärke: **\(strong)** (\(strongShare)). "
                     + "Deine Schwäche: **\(weak)** (\(weakShare)).",
                 "\(over) ты **\(mood)**. Сильная сторона: **\(strong)** (\(strongShare)). "
                     + "Слабая сторона: **\(weak)** (\(weakShare)).")
    }

    var luckScaleLow: String {
        t("0 · 불운", "0 · unlucky", "0 · 不運", "0 · mala suerte", "0 · malchance", "0 · azar", "0 · Pech", "0 · неудача")
    }
    var luckScaleMiddle: String {
        t("50 · 평균", "50 · average", "50 · 平均", "50 · media", "50 · moyenne", "50 · média", "50 · Schnitt", "50 · средне")
    }
    var luckScaleHigh: String {
        t("100 · 행운", "100 · lucky", "100 · 幸運", "100 · suerte", "100 · chance", "100 · sorte", "100 · Glück", "100 · удача")
    }

    var luckByCriterion: String {
        t("항목별", "Criterion by criterion", "項目別", "Criterio por criterio", "Critère par critère", "Critério por critério",
          "Kriterium für Kriterium", "По критериям")
    }
    var luckByCriterionHint: String {
        t("나와 똑같은 뽑기(같은 알, 같은 아이템, 같은 볼)를 한 트레이너 1만 명 중 나보다 운이 나빴던 비율이에요. 50%가 평균이에요. 드문 결과일수록 더 크게 세고, 확정된 결과는 세지 않아요.",
          "The share of 10,000 trainers who, with exactly your draws (same eggs, same items, same balls), were less lucky. 50% is average. The rarer a result, the more it counts; a guaranteed one doesn't.",
          "あなたとまったく同じ抽選（同じタマゴ、同じアイテム、同じボール）をした1万人のトレーナーのうち、あなたより運が悪かった割合です。50%が平均です。珍しい結果ほど大きく数え、確定した結果は数えません。",
          "La parte de 10.000 entrenadores que, con exactamente tus sorteos (mismos huevos, mismos objetos, mismas Balls), tuvieron menos suerte. 50% es la media. Cuanto más raro el resultado, más cuenta; uno garantizado no cuenta.",
          "La part de 10\u{00A0}000 dresseurs qui, avec exactement tes tirages (mêmes œufs, mêmes objets, mêmes Balls), ont eu moins de chance. 50\u{00A0}%, c'est la moyenne. Plus un résultat est rare, plus il compte ; un tirage garanti ne compte pas.",
          "A parte de 10.000 treinadores que, com exatamente os seus sorteios (mesmos ovos, mesmos itens, mesmas Balls), tiveram menos sorte. 50% é a média. Quanto mais raro o resultado, mais conta; um garantido não conta.",
          "Der Anteil von 10.000 Trainern, die mit genau deinen Ziehungen (gleiche Eier, gleiche Gegenstände, gleiche Bälle) weniger Glück hatten. 50% ist der Schnitt. Je seltener ein Ergebnis, desto mehr zählt es; ein garantiertes zählt nicht.",
          "Доля из 10 000 тренеров, которые с точно такими же выпадениями (те же яйца, предметы и мячи) были менее удачливы. 50% это середина. Чем реже результат, тем больше он весит; гарантированный не считается.")
    }

    /// The draw items weigh on the odds, so on the luck.
    var luckItemsNote: String {
        let charm = itemName(.shinyCharm)
        return t("아이템과 볼도 반영돼요: \(KoreanParticle.subject.attach(to: charm)) 있을 때의 이로치는 원래 나올 확률이 높았으니 덜 세요.",
                 "Your items and balls count: a shiny with the \(charm) counts less, it was likelier.",
                 "アイテムとボールも反映されます：\(charm)があるときの色違いは出やすかったので、少なめに数えます。",
                 "Tus objetos y Balls cuentan: un variocolor con el \(charm) cuenta menos, era más probable.",
                 "Tes objets et tes Balls comptent : un chromatique avec le \(charm) compte moins, il était plus probable.",
                 "Seus itens e Balls contam: um shiny com o \(charm) conta menos, era mais provável.",
                 "Deine Gegenstände und Bälle zählen: Ein Schillerndes mit dem \(charm) zählt weniger, es war wahrscheinlicher.",
                 "Предметы и мячи учитываются: шайни при наличии предмета \(charm) весит меньше, он был вероятнее.")
    }

    /// A rarity tier "or better": its hits and the expected.
    func luckTier(_ rarity: Rarity, hits: Int, expected: Double) -> String {
        "\(rarityLabel(rarity)) · \(luckCounts(hits: hits, expected: expected))"
    }

    /// The IVs' average total, out of 186, against the 93 expected.
    func luckAverageIVs(_ average: Double) -> String {
        let a = average.formatted(.number.precision(.fractionLength(1)).locale(locale))
        return t("평균 \(a)/186 · 기대 93", "average \(a)/186 · 93 expected", "平均 \(a)/186 · 期待値 93",
                 "media \(a)/186 · 93 esperado", "moyenne \(a)/186 · 93 attendu", "média \(a)/186 · 93 esperado",
                 "Schnitt \(a)/186 · 93 erwartet", "в среднем \(a)/186 · ожидалось 93")
    }

    var luckHighlightsTitle: String {
        t("가장 운 좋았던 뽑기", "Your luckiest draws", "最も運がよかった抽選", "Tus sorteos más afortunados",
          "Tes plus beaux tirages", "Seus sorteios de mais sorte", "Deine glücklichsten Ziehungen", "Самые удачные выпадения")
    }

    /// A draw of the luck journal, by its kind.
    func luckDrawName(_ kind: LuckDrawKind) -> String {
        switch kind {
        case .bossThrow:
            t("보스 포획", "Boss caught", "ボスの捕獲", "Jefe capturado", "Boss capturé", "Chefe capturado", "Boss gefangen",
              "Пойман босс")
        case .shinyCatch:
            t("이로치 포획", "Shiny caught", "色違いの捕獲", "Variocolor capturado", "Chromatique capturé", "Shiny capturado",
              "Schillerndes gefangen", "Пойман шайни")
        case .bossShiny:
            t("이로치 보스", "Shiny boss", "色違いのボス", "Jefe variocolor", "Boss chromatique", "Chefe shiny", "Schillernder Boss",
              "Босс шайни")
        case .shinyMeeting:
            t("층에서 만난 이로치", "Shiny met on a floor", "階で出会った色違い", "Variocolor en un piso", "Chromatique croisé",
              "Shiny num andar", "Schillerndes auf einer Ebene", "Шайни на этаже")
        case .secretBoss:
            t("비밀 보스", "Secret boss", "ひみつのボス", "Jefe secreto", "Boss secret", "Chefe secreto", "Geheimer Boss", "Тайный босс")
        case .secretPassage: dungeonSecretPassage
        case .chestEgg:
            t("상자 속 알", "Egg in a chest", "宝箱のタマゴ", "Huevo en un cofre", "Œuf dans un coffre", "Ovo num baú", "Ei in einer Truhe",
              "Яйцо в сундуке")
        case .victoryExtra:
            t("승리 보너스", "Victory bonus", "勝利ボーナス", "Bonus de victoria", "Bonus de victoire", "Bônus de vitória",
              "Siegesbonus", "Бонус за победу")
        case .leaderChest:
            t("두목의 상자", "Leader's chest", "ボスの宝箱", "Cofre del líder", "Coffre du chef", "Baú do líder", "Truhe des Anführers",
              "Сундук лидера")
        case .technicalCapsule: dungeonTechnicalCapsule
        case .wishingPiece: itemName(.wishingPiece)
        case .explorerTreasure: itemName(.explorerKit)
        case .shockDrive: itemName(.shockDrive)
        }
    }

    /// A day of the luck journal on the curve.
    func luckCurveJournal(_ date: Date, score: Int) -> String {
        let day = date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
        return t("\(day) 던전 · 지수 \(score)", "Dungeons on \(day) · score \(score)", "\(day)のダンジョン · スコア \(score)",
                 "Mazmorras del \(day) · índice \(score)", "Donjons du \(day) · indice \(score)",
                 "Masmorras de \(day) · índice \(score)", "Dungeons am \(day) · Wert \(score)",
                 "Подземелья \(day) · индекс \(score)")
    }

    var luckCopyHint: String {
        t("운 이미지를 복사", "Copy your luck as an image", "運を画像でコピー", "Copiar tu suerte como imagen",
          "Copier l'image de ta chance", "Copiar sua sorte como imagem", "Dein Glück als Bild kopieren",
          "Скопировать удачу как картинку")
    }

    /// Hits and expected hits of a criterion: two decimals for an expectation under one.
    func luckCounts(hits: Int, expected: Double) -> String {
        let e = expected.formatted(.number.precision(.fractionLength(0...(expected < 1 ? 2 : 1))).locale(locale))
        return t("\(hits)회 획득 · 기대 \(e)회", "\(hits) caught · \(e) expected", "\(hits)回 · 期待値 \(e)回",
                 "\(hits) \(hits == 1 ? "obtenido" : "obtenidos") · \(e) \(expected == 1 ? "esperado" : "esperados")",
                 "\(hits) obtenu\(hits > 1 ? "s" : "") · \(e) attendu\(expected >= 2 ? "s" : "")",
                 "\(hits) \(hits > 1 ? "obtidos" : "obtido") · \(e) \(expected >= 2 ? "esperados" : "esperado")",
                 "\(hits) erhalten · \(e) erwartet", "получено \(hits) · ожидалось \(e)")
    }

    /// Hatches since a criterion's last hit, on its line.
    func luckSinceLast(_ hatches: Int?) -> String {
        guard let n = hatches else {
            return t("아직 없음", "not yet", "まだなし", "todavía no", "pas encore", "ainda não", "noch nie", "пока нет")
        }
        if n == 0 {
            return t("마지막 부화에서", "on the last hatch", "直前の孵化で", "en la última eclosión", "à la dernière éclosion",
                     "na última eclosão", "beim letzten Schlupf", "на последнем вылуплении")
        }
        let ru = n % 10 == 1 && n % 100 != 11 ? "вылупление"
            : (2...4).contains(n % 10) && !(12...14).contains(n % 100) ? "вылупления" : "вылуплений"
        return t("마지막: \(n)번 전", "last one \(n) hatch\(n == 1 ? "" : "es") ago", "最後は\(n)回前",
                 "el último hace \(n) \(n == 1 ? "eclosión" : "eclosiones")",
                 "dernier il y a \(n) éclosion\(n == 1 ? "" : "s")",
                 "o último há \(n) \(n == 1 ? "eclosão" : "eclosões")",
                 "zuletzt vor \(n) \(n == 1 ? "Schlupf" : "Schlüpfen")", "последний \(n) \(ru) назад")
    }

    func luckUnknownEggs(_ count: Int) -> String {
        let shiny = luckCriterion(.shiny), ivs = luckCriterion(.ivs), ability = luckCriterion(.hiddenAbility)
        return t("알 수 없는 알: \(count)개. 업데이트 전에 놓아준 뒤 부화한 포켓몬은 \(shiny), \(ivs), \(ability)에만 반영돼요.",
                 "Unknown eggs: \(count). A hatch from before this update that follows a release only counts for \(shiny), \(ivs) and \(ability).",
                 "不明なタマゴ: \(count)個。アップデート前に逃がした後の孵化は\(shiny)、\(ivs)、\(ability)にだけ数えます。",
                 "Huevos desconocidos: \(count). Una eclosión de antes de esta actualización que sigue a una liberación solo cuenta para \(shiny), \(ivs) y \(ability).",
                 "Œufs inconnus : \(count). Une éclosion d'avant la mise à jour qui suit un relâché ne compte que pour les critères \(shiny), \(ivs) et \(ability).",
                 "Ovos desconhecidos: \(count). Uma eclosão de antes desta atualização que vem depois de uma soltura só conta para \(shiny), \(ivs) e \(ability).",
                 "Unbekannte Eier: \(count). Ein Schlupf von vor diesem Update nach einer Freilassung zählt nur für \(shiny), \(ivs) und \(ability).",
                 "Неизвестных яиц: \(count). Вылупление до этого обновления после отпускания учитывается только для \(shiny), \(ivs) и \(ability).")
    }

    var luckApproximate: String {
        t("대략적인 운", "Approximate luck", "おおよその運", "Suerte aproximada", "Chance approximative", "Sorte aproximada",
          "Ungefähres Glück", "Удача приблизительна")
    }

    var luckEggsToPick: String {
        t("알려 줄 알", "Eggs to pick", "選ぶタマゴ", "Huevos por indicar", "Œufs à indiquer", "Ovos a indicar",
          "Anzugebende Eier", "Яйца, которые нужно указать")
    }

    var luckPickEggsAction: String {
        t("알 알려 주기", "Pick the eggs", "タマゴを選ぶ", "Elegir los huevos", "Indiquer les œufs", "Escolher os ovos",
          "Eier angeben", "Указать яйца")
    }

    var luckDontRemember: String {
        t("기억나지 않아요", "I don't remember", "覚えていません", "No me acuerdo", "Je ne m'en souviens plus", "Não me lembro",
          "Ich weiß es nicht mehr", "Не помню")
    }

    var luckDontRememberHint: String {
        t("알 수 없는 알마다 가장 그럴듯한 알을 정해 줘요. 나중에 바꿀 수 있어요.",
          "Gives each unknown egg the most likely one. You can still change it.",
          "不明なタマゴそれぞれに、最もありそうなタマゴを割り当てます。あとで変更できます。",
          "Asigna a cada huevo desconocido el más probable. Podrás cambiarlo.",
          "Attribue à chaque œuf inconnu le plus logique. Tu pourras le changer.",
          "Atribui a cada ovo desconhecido o mais provável. Você ainda pode mudar.",
          "Gibt jedem unbekannten Ei das wahrscheinlichste. Du kannst es noch ändern.",
          "Назначает каждому неизвестному яйцу самое вероятное. Его можно изменить.")
    }

    var luckDeduced: String {
        t("추정", "deduced", "推定", "deducido", "déduit", "deduzido", "abgeleitet", "выведено")
    }

    var luckEggOfHatch: String {
        t("이 부화의 알", "Egg of this hatch", "この孵化のタマゴ", "Huevo de esta eclosión", "Œuf de cette éclosion",
          "Ovo desta eclosão", "Ei dieses Schlupfs", "Яйцо этого вылупления")
    }

    var luckDrawItemsTitle: String {
        t("뽑기 아이템", "Draw items", "抽選アイテム", "Objetos de sorteo", "Objets de tirage", "Itens de sorteio",
          "Ziehungsgegenstände", "Предметы для выпадения")
    }
    var luckDrawItemsHint: String {
        let charm = itemName(.shinyCharm)
        return t("업데이트 전에는 부화할 때마다 아이템을 기록하지 않았어요. 각 아이템은 그것을 가져온 업데이트부터, 또는 그보다 늦다면 그것을 얻게 한 졸업부터, 그 뒤에 시작된 알에 반영돼요. \(charm): 상점 가격을 10%까지 낮출 수 있게 된 뒤로 모두가 가지고 있어요.",
                 "Before this update, the app did not note your items at each hatch. Each one counts for the eggs started after the update that brought it, or after the graduation that earned it when later. \(charm): every player has had it since Shop prices could go down to 10%.",
                 "アップデート前は、孵化ごとにアイテムを記録していませんでした。それぞれ、持ち込んだアップデートの後、またはそれより遅ければ手に入れた卒業の後に始まったタマゴから数えます。\(charm)：ショップの価格を10%まで下げられるようになってから、みんなが持っています。",
                 "Antes de esta actualización, la app no anotaba tus objetos en cada eclosión. Cada uno cuenta para los huevos empezados después de la actualización que lo trajo, o después de la graduación que lo consiguió si fue más tarde. \(charm): todos lo tienen desde que los precios de la Tienda pudieron bajar al 10%.",
                 "Avant la mise à jour, l'app ne notait pas tes objets à chaque éclosion. Chacun compte pour les œufs commencés après la mise à jour qui l'a apporté, ou après la diplomation qui te l'a valu si elle est plus tardive. \(charm) : tout le monde l'a depuis que les prix de la Boutique peuvent descendre à 10\u{00A0}%.",
                 "Antes desta atualização, o app não anotava seus itens a cada eclosão. Cada um conta para os ovos iniciados depois da atualização que o trouxe, ou depois da graduação que o rendeu, se foi mais tarde. \(charm): todos têm desde que os preços da Loja puderam baixar para 10%.",
                 "Vor diesem Update hat die App deine Gegenstände nicht bei jedem Schlupf notiert. Jeder zählt für die Eier, die nach dem Update begonnen haben, das ihn brachte, oder nach dem Abschluss, der ihn einbrachte, wenn dieser später war. \(charm): zählt für alle, seit die Shop-Preise auf 10\u{00A0}% sinken konnten.",
                 "До этого обновления приложение не записывало предметы при каждом вылуплении. Каждый учитывается для яиц, начатых после обновления, которое его принесло, или после выпуска, который его принёс, если он был позже. \(charm): есть у всех с тех пор, как цены в магазине можно снизить до 10%.")
    }
    var luckObtainedOn: String {
        t("획득일", "Got on", "入手日", "Obtenido el", "Obtenu le", "Obtido em", "Erhalten am", "Получен")
    }

    var luckTooFew: String {
        t("아직 운을 판단할 만큼 부화하지 않았어요. 두 번은 부화해야 해요.",
          "Not enough hatches yet to judge your luck: it takes two.",
          "運を判断するには孵化がまだ足りません。2回必要です。",
          "Aún no hay suficientes eclosiones para juzgar tu suerte: hacen falta dos.",
          "Pas encore assez d'éclosions pour juger ta chance : il en faut deux.",
          "Ainda não há eclosões suficientes para julgar sua sorte: são precisas duas.",
          "Noch zu wenige Schlüpfe, um dein Glück zu beurteilen: es braucht zwei.",
          "Пока слишком мало вылуплений, чтобы оценить удачу: нужно хотя бы два.")
    }

    var luckCurveTitle: String {
        t("부화와 던전별 운 지수", "Your score hatch after hatch, day of dungeons after day",
          "孵化とダンジョンごとの運スコア", "Tu índice eclosión tras eclosión, día de mazmorras tras día",
          "Ton indice au fil des éclosions et des journées de donjons", "Seu índice eclosão após eclosão, dia de masmorras após dia",
          "Dein Wert Schlupf für Schlupf, Dungeon-Tag für Dungeon-Tag", "Твой индекс по вылуплениям и дням подземелий")
    }

    func luckCurvePoint(number: Int, name: String, score: Int) -> String {
        t("\(number)번째 부화 · \(name) · 지수 \(score)", "Hatch No. \(number) · \(name) · score \(score)",
          "\(number)回目の孵化 · \(name) · スコア \(score)", "Eclosión n.º \(number) · \(name) · índice \(score)",
          "Éclosion n° \(number) · \(name) · indice \(score)", "Eclosão nº \(number) · \(name) · índice \(score)",
          "Schlupf Nr. \(number) · \(name) · Wert \(score)", "Вылупление № \(number) · \(name) · индекс \(score)")
    }

    var luckCriteriaCurvesTitle: String {
        t("항목별 추이", "Criterion by criterion", "項目別の推移", "Criterio por criterio", "Critère par critère",
          "Critério por critério", "Kriterium für Kriterium", "По критериям")
    }

    var luckImprobableTitle: String {
        t("가장 희박했던 뽑기", "Your most unlikely draws", "最もありえなかった抽選", "Tus sorteos más improbables",
          "Tes tirages les plus improbables", "Seus sorteios mais improváveis", "Deine unwahrscheinlichsten Ziehungen",
          "Самые невероятные выпадения")
    }

    func luckOneIn(_ odds: Double) -> String {
        let n = Int((1 / odds).rounded()).formatted(.number.locale(locale))
        return t("\(n)분의 1 확률", "1 chance in \(n)", "\(n)分の1の確率", "1 posibilidad entre \(n)", "1 chance sur \(n)",
                 "1 chance em \(n)", "Chance 1 zu \(n)", "шанс 1 из \(n)")
    }

    func luckHatchNumber(_ number: Int) -> String {
        t("\(number)번째 부화", "hatch No. \(number)", "\(number)回目の孵化", "eclosión n.º \(number)", "éclosion n° \(number)",
          "eclosão nº \(number)", "Schlupf Nr. \(number)", "вылупление № \(number)")
    }

    func luckWait(_ wait: HatchLuck.Wait) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        var components = DateComponents()
        switch wait.unit {
        case .day: formatter.allowedUnits = .day; components.day = wait.count
        case .week: formatter.allowedUnits = .weekOfMonth; components.weekOfMonth = wait.count
        case .month: formatter.allowedUnits = .month; components.month = wait.count
        case .year: formatter.allowedUnits = .year; components.year = wait.count
        }
        let d = formatter.string(from: components) ?? "\(wait.count)"
        return t("내 속도로 약 \(d)", "about \(d) at your pace", "今のペースで約\(d)", "unos \(d) a tu ritmo",
                 "environ \(d) à ton rythme", "cerca de \(d) no seu ritmo", "etwa \(d) in deinem Tempo", "примерно \(d) в твоём темпе")
    }

    var luckHistoryTitle: String {
        t("모든 부화", "All your hatches", "すべての孵化", "Todas tus eclosiones", "Toutes tes éclosions", "Todas as suas eclosões",
          "Alle deine Schlüpfe", "Все вылупления")
    }
    var luckOnScore: String {
        t("지수 변화", "on your score", "スコアへの影響", "en tu índice", "sur ton indice", "no seu índice", "auf deinen Wert", "на индекс")
    }
    var luckNew: String { luckCriterion(.new) }
    var luckNothingNew: String {
        t("새로움 없음", "Nothing new", "新しくない", "Nada nuevo", "Rien de nouveau", "Nada novo", "Nichts Neues", "Ничего нового")
    }

    func luckShowMore(_ count: Int) -> String {
        t("나머지 \(count)개 보기", "Show the \(count) others", "残り\(count)件を表示", "Mostrar las otras \(count)",
          "Afficher les \(count) autres", "Mostrar as outras \(count)", "Die anderen \(count) zeigen", "Показать остальные \(count)")
    }

    func luckPercent(_ share: Double) -> String { percentSign(String(Int((share * 100).rounded()))) }

    /// The odds a hatch had: a range over the eggs it may have come from.
    func luckOdds(_ odds: HatchLuck.OddsRange) -> String {
        let low = oddsNumber(odds.low), high = oddsNumber(odds.high)
        guard low != high else { return percentSign(low) }
        return t("\(low)~\(high)%", "\(low) to \(high)%", "\(low)〜\(high)%", "\(low) a \(high)%", "\(low) à \(high)\u{00A0}%",
                 "\(low) a \(high)%", "\(low) bis \(high)%", "от \(low) до \(high)%")
    }

    /// What a hatch did to the score, to a tenth, signed.
    func luckEffect(_ effect: Double) -> String {
        let shown = (effect * 10).rounded() / 10
        guard shown != 0 else { return 0.0.formatted(.number.precision(.fractionLength(1)).locale(locale)) }
        return shown.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()).locale(locale))
    }

    func hatchEggName(_ egg: HatchEgg?) -> String {
        guard let egg else {
            return t("알 수 없는 알", "Unknown egg", "不明なタマゴ", "Huevo desconocido", "Œuf inconnu", "Ovo desconhecido",
                     "Unbekanntes Ei", "Неизвестное яйцо")
        }
        switch egg {
        case .event(let event, _): return ItemKind.allCases.first { EventEgg(item: $0) == event }.map(itemName) ?? eggName(nil)
        // By the Pokémon it hatches; the Luck screen names it as the Bag does (`DungeonEggTitle`).
        case .dungeon(let baseID, _, _): return eggOf("#\(baseID)")
        case .costume(let code, let speciesID):
            return CostumeCatalog.entries.first { $0.code == code && $0.speciesID == speciesID }
                .map { costumeEggName($0.month) } ?? eggName(nil)
        case .tier, .stone, .legendary, .typeNull, .birthday, .fossil:
            return ItemKind.allCases.first { HatchEgg(item: $0) == egg }.map(itemName) ?? eggName(nil)
        }
    }

    /// Under 0.1 %, whole percents from 1 %, one decimal between.
    private func oddsNumber(_ share: Double) -> String {
        if share < 0.001 { return "< " + 0.1.formatted(.number.locale(locale)) }
        return (share * 100).formatted(.number.precision(.fractionLength(0...(share < 0.01 ? 1 : 0))).locale(locale))
    }

    private func percentSign(_ number: String) -> String {
        t("\(number)%", "\(number)%", "\(number)%", "\(number)%", "\(number)\u{00A0}%", "\(number)%", "\(number)%", "\(number)%")
    }
}
