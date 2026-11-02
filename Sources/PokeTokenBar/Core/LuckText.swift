import Foundation

/// The words of the Luck screen (`LuckScreen`), its figures shown as TokenDex shows them.
extension L {
    private var locale: Locale { lang.displayLocale }

    var luckTitle: String {
        t("부화 운", "Your hatch luck", "孵化の運", "Tu suerte al eclosionar", "Ta chance au tirage", "Sua sorte nas eclosões",
          "Dein Schlüpfglück", "Твоя удача при вылуплении")
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
        case .uncommon: t("고급", "Uncommon", "アンコモン", "Poco comunes", "Peu communs", "Incomuns", "Ungewöhnliche", "Необычные")
        case .rare: t("희귀", "Rare", "レア", "Raros", "Rares", "Raros", "Seltene", "Редкие")
        case .legendary: t("전설", "Legendary", "伝説", "Legendarios", "Légendaires", "Lendários", "Legendäre", "Легендарные")
        case .shiny: bonusThemeTitle(.shiny)
        case .new: t("새로움", "Something new", "新しいもの", "Algo nuevo", "Du nouveau", "Algo novo", "Etwas Neues", "Новое")
        case .ditto: t("메타몽", "Ditto", "メタモン", "Ditto", "Métamorph", "Ditto", "Ditto", "Дитто")
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

    /// The summary under the score, in Markdown for its bold words.
    func luckSentence(hatches: Int, score: Int, best: (HatchLuck.Criterion, Double),
                      worst: (HatchLuck.Criterion, Double)) -> String {
        let mood = luckMood(score)
        let strong = luckCriterion(best.0), strongShare = luckPercent(best.1)
        let weak = luckCriterion(worst.0), weakShare = luckPercent(worst.1)
        return t("부화 \(hatches)번 기준, **\(mood)**입니다. 강점: **\(strong)** (\(strongShare)). 약점: **\(weak)** (\(weakShare)).",
                 "Over \(hatches) hatches, you are **\(mood)**. Your strong point: **\(strong)** (\(strongShare)). "
                     + "Your weak point: **\(weak)** (\(weakShare)).",
                 "孵化\(hatches)回で、あなたは**\(mood)**です。得意: **\(strong)**（\(strongShare)）。苦手: **\(weak)**（\(weakShare)）。",
                 "En \(hatches) eclosiones, estás **\(mood)**. Tu punto fuerte: **\(strong)** (\(strongShare)). "
                     + "Tu punto débil: **\(weak)** (\(weakShare)).",
                 "Sur \(hatches) éclosions, tu es **\(mood)**. Ton point fort : **\(strong)** (\(strongShare)). "
                     + "Ton point faible : **\(weak)** (\(weakShare)).",
                 "Em \(hatches) eclosões, você está **\(mood)**. Seu ponto forte: **\(strong)** (\(strongShare)). "
                     + "Seu ponto fraco: **\(weak)** (\(weakShare)).",
                 "Bei \(hatches) Schlüpfen bist du **\(mood)**. Deine Stärke: **\(strong)** (\(strongShare)). "
                     + "Deine Schwäche: **\(weak)** (\(weakShare)).",
                 "За \(hatches) вылуплений ты **\(mood)**. Сильная сторона: **\(strong)** (\(strongShare)). "
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
        t("매 부화마다 나와 똑같은 확률을 가진 트레이너 중 나보다 결과가 나빴을 비율이에요. 50%가 평균이에요.",
          "The share of trainers who, with exactly your odds at every hatch, would have done worse. 50% is average.",
          "毎回の孵化であなたとまったく同じ確率だったトレーナーのうち、あなたより結果が悪かった割合です。50%が平均です。",
          "La parte de entrenadores que, con exactamente tus probabilidades en cada eclosión, lo habría hecho peor. 50% es la media.",
          "La part des dresseurs, avec exactement tes chances à chaque éclosion, qui aurait fait moins bien. 50\u{00A0}%, c'est la moyenne.",
          "A parte dos treinadores que, com exatamente as suas chances em cada eclosão, teria se saído pior. 50% é a média.",
          "Der Anteil der Trainer, die mit genau deinen Chancen bei jedem Schlüpfen schlechter abgeschnitten hätten. 50% ist der Schnitt.",
          "Доля тренеров, которые с точно такими же шансами при каждом вылуплении справились бы хуже. 50% это середина.")
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
        let shiny = luckCriterion(.shiny)
        return t("알 수 없는 알: \(count)개. 업데이트 전에 놓아준 뒤 부화한 포켓몬은 \(shiny)에만 반영돼요.",
                 "Unknown eggs: \(count). A hatch from before this update that follows a release only counts for \(shiny).",
                 "不明なタマゴ: \(count)個。アップデート前に逃がした後の孵化は\(shiny)にだけ数えます。",
                 "Huevos desconocidos: \(count). Una eclosión de antes de esta actualización que sigue a una liberación solo cuenta para \(shiny).",
                 "Œufs inconnus : \(count). Une éclosion d'avant la mise à jour qui suit un relâché ne compte que pour le critère \(shiny).",
                 "Ovos desconhecidos: \(count). Uma eclosão de antes desta atualização que vem depois de uma soltura só conta para \(shiny).",
                 "Unbekannte Eier: \(count). Ein Schlupf von vor diesem Update nach einer Freilassung zählt nur für \(shiny).",
                 "Неизвестных яиц: \(count). Вылупление до этого обновления после отпускания учитывается только для \(shiny).")
    }

    var luckApproximate: String {
        t("대략적인 운", "Approximate luck", "おおよその運", "Suerte aproximada", "Chance approximative", "Sorte aproximada",
          "Ungefähres Glück", "Удача приблизительна")
    }

    var luckPickEggsAction: String {
        t("알 알려 주기", "Pick the eggs", "タマゴを選ぶ", "Elegir los huevos", "Indiquer les œufs", "Escolher os ovos",
          "Eier angeben", "Указать яйца")
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
        t("업데이트 전에는 부화할 때마다 아이템을 기록하지 않았어요. 각 아이템을 언제부터 가졌는지 알려 주세요. 그 날짜 이후에 시작된 알부터 반영돼요. 날짜가 없으면 업데이트 전에는 반영되지 않아요.",
          "Before this update, the app did not note your items at each hatch. Say since when you have each one: it counts for the eggs started after that date. Without a date, it does not count before the update.",
          "アップデート前は、孵化ごとにアイテムを記録していませんでした。それぞれいつから持っているかを入力すると、その日以降に始まったタマゴから数えます。日付がなければ、アップデート前には数えません。",
          "Antes de esta actualización, la app no anotaba tus objetos en cada eclosión. Indica desde cuándo tienes cada uno: cuenta para los huevos empezados después de esa fecha. Sin fecha, no cuenta antes de la actualización.",
          "Avant la mise à jour, l'app ne notait pas tes objets à chaque éclosion. Dis depuis quand tu as chacun : il compte pour les œufs commencés après cette date. Sans date, il ne compte pas avant la mise à jour.",
          "Antes desta atualização, o app não anotava seus itens a cada eclosão. Diga desde quando você tem cada um: ele conta para os ovos iniciados depois dessa data. Sem data, não conta antes da atualização.",
          "Vor diesem Update hat die App deine Gegenstände nicht bei jedem Schlupf notiert. Gib an, seit wann du jeden hast: Er zählt für die Eier, die danach begonnen haben. Ohne Datum zählt er vor dem Update nicht.",
          "До этого обновления приложение не записывало предметы при каждом вылуплении. Укажи, с какого дня у тебя каждый: он учитывается для яиц, начатых после этой даты. Без даты он не учитывается до обновления.")
    }
    var luckObtainedOn: String {
        t("획득일", "Got on", "入手日", "Obtenido el", "Obtenu le", "Obtido em", "Erhalten am", "Получен")
    }
    var luckSetDate: String {
        t("날짜 입력", "Set the date", "日付を入力", "Indicar la fecha", "Indiquer la date", "Indicar a data", "Datum angeben",
          "Указать дату")
    }
    var luckRemoveDate: String {
        t("날짜 지우기", "Remove the date", "日付を消す", "Quitar la fecha", "Retirer la date", "Remover a data", "Datum entfernen",
          "Убрать дату")
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
        t("부화별 운 지수", "Your score hatch after hatch", "孵化ごとの運スコア", "Tu índice eclosión tras eclosión",
          "Ton indice au fil des éclosions", "Seu índice eclosão após eclosão", "Dein Wert Schlupf für Schlupf",
          "Твой индекс по вылуплениям")
    }

    func luckCurvePoint(number: Int, name: String, score: Int) -> String {
        t("\(number)번째 부화 · \(name) · 지수 \(score)", "Hatch No. \(number) · \(name) · score \(score)",
          "\(number)回目の孵化 · \(name) · スコア \(score)", "Eclosión n.º \(number) · \(name) · índice \(score)",
          "Éclosion n° \(number) · \(name) · indice \(score)", "Eclosão nº \(number) · \(name) · índice \(score)",
          "Schlupf Nr. \(number) · \(name) · Wert \(score)", "Вылупление № \(number) · \(name) · индекс \(score)")
    }

    var luckCriteriaCurvesTitle: String {
        t("항목별 추이", "Criterion by criterion, hatch after hatch", "項目別の推移", "Criterio por criterio, eclosión tras eclosión",
          "Critère par critère, au fil des éclosions", "Critério por critério, eclosão após eclosão",
          "Kriterium für Kriterium, Schlupf für Schlupf", "По критериям, по вылуплениям")
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
        default: return ItemKind.allCases.first { HatchEgg(item: $0) == egg }.map(itemName) ?? eggName(nil)
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
